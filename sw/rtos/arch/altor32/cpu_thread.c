//-----------------------------------------------------------------
//                           AltOR32 
//              Alternative Lightweight OpenRisc 
//                     Ultra-Embedded.com
//                   Copyright 2011 - 2013
//
//               Email: admin@ultra-embedded.com
//
//                       License: LGPL
//
// If you would like a version with a different license for use 
// in commercial projects please contact the above email address 
// for more details.
//-----------------------------------------------------------------
//
// Copyright (C) 2011 - 2013 Ultra-Embedded.com
//
// This source file may be used and distributed without         
// restriction provided that this copyright statement is not    
// removed from the file and that any derivative work contains  
// the original copyright notice and the associated disclaimer. 
//
// This source file is free software; you can redistribute it   
// and/or modify it under the terms of the GNU Lesser General   
// Public License as published by the Free Software Foundation; 
// either version 2.1 of the License, or (at your option) any   
// later version.                                               
//
// This source is distributed in the hope that it will be       
// useful, but WITHOUT ANY WARRANTY; without even the implied   
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
// PURPOSE.  See the GNU Lesser General Public License for more 
// details.                                                     
//
// You should have received a copy of the GNU Lesser General    
// Public License along with this source; if not, write to the 
// Free Software Foundation, Inc., 59 Temple Place, Suite 330, 
// Boston, MA  02111-1307  USA
//-----------------------------------------------------------------
#include "kernel/rtos.h"
#include "kernel/os_assert.h"
#include "cpu_interrupts.h"
#include "mem_map.h"
#include "printf.h"
#include "irq.h"

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------

// Macro used to stop profiling functions being called
#define NO_PROFILE              __attribute__((__no_instrument_function__))

// SR Register
#define SPR_SR                  (17)

// SR_IEE - Interrupt Exception Enable
#define SPR_SR_IEE              0x00000004

#define STACK_REDZONE_SIZE      128

//-----------------------------------------------------------------
// Globals:
//-----------------------------------------------------------------
volatile tTaskBlock *   _currentTCB = NULL;
volatile unsigned       _in_interrupt = 0;

//-----------------------------------------------------------------
// cpu_thread_init_tcb:
//-----------------------------------------------------------------
void cpu_thread_init_tcb( tTaskBlock *tcb, void (*func)(void *), void *funcArg, unsigned long *stack, unsigned int stack_size )
{
    unsigned long *stack_pointer;
    int i;

    OS_ASSERT(stack != NULL);

    // Record end of stack (start of stack array)
    stack_pointer = stack;
    tcb->StackSize = stack_size;
    tcb->StackAlloc = stack_pointer;

    // Set default check byte 
    for (i=0;i<tcb->StackSize;i++)
        tcb->StackAlloc[i] = STACK_CHK_BYTE;

    // Set current stack pointer to start (top) of stack
    stack_pointer += (tcb->StackSize-1);

    // MARKER
    *stack_pointer = ( unsigned long ) 0xFEADC0ED;        
    stack_pointer--;

    // MARKER 2
    *stack_pointer = ( unsigned long ) 0xFEADC0ED;        
    stack_pointer--;

    // Make space for redzone...
    stack_pointer -= STACK_REDZONE_SIZE;

    // Setup registers
    for (i=31;i>=2;i--)
    {
        // R3 = Arg
        if (i == 3)
            *stack_pointer = ( unsigned long ) funcArg;
        else
            *stack_pointer = ( unsigned long ) i;
        stack_pointer--;
    }

    // 4: ESR (start with interrupts enabled)  
    *stack_pointer = ( unsigned long ) SPR_SR_IEE;
    stack_pointer--;    

    // 0: EPC
    *stack_pointer = ( unsigned long ) func;

    // Critical depth = 0 so not in critical section (ints enabled)
    tcb->critical_depth = 0;

    /* Record new stack pointer */
    tcb->StackPointer = stack_pointer;
}
//-----------------------------------------------------------------
// mtspr: Write to SPR
//-----------------------------------------------------------------
static inline void mtspr(unsigned long spr, unsigned long value) 
{    
    asm volatile ("l.mtspr\t\t%0,%1,0": : "r" (spr), "r" (value));
}
//-----------------------------------------------------------------
// mfspr: Read from SPR
//-----------------------------------------------------------------
static inline unsigned long mfspr(unsigned long spr) 
{    
    unsigned long value;
    asm volatile ("l.mfspr\t\t%0,%1,0" : "=r" (value) : "r" (spr));
    return value;
}
//-----------------------------------------------------------------
// cpu_critical_start: Force interrupts to be disabled
//-----------------------------------------------------------------
int NO_PROFILE cpu_critical_start(void)
{    
    // Don't do anything to the interrupt status if already within IRQ
    if (_in_interrupt || _currentTCB == NULL)
        return 0;

    // Disable interrupts
    mtspr(SPR_SR, 0);

    // Increase critical depth
    _currentTCB->critical_depth++;

    return (int)0;
}
//-----------------------------------------------------------------
// cpu_critical_end: Restore interrupt enable state
//-----------------------------------------------------------------
void NO_PROFILE cpu_critical_end(int cr)
{
    // Don't do anything to the interrupt status if already within IRQ
    if (_in_interrupt || _currentTCB == NULL)
        return ;

    OS_ASSERT(_currentTCB->critical_depth > 0);
    OS_ASSERT(_currentTCB->critical_depth < 255);

    // Decrement critical depth
    _currentTCB->critical_depth--;

    // End of critical section?
    if (_currentTCB->critical_depth == 0)
    {
        // Manually re-enable IRQ
        mtspr(SPR_SR, SPR_SR_IEE);
    }        

    return;
}
//-----------------------------------------------------------------
// cpu_context_switch:
//-----------------------------------------------------------------
void cpu_context_switch( void )
{
    OS_ASSERT(!_in_interrupt);

    // Cause context switch
    asm volatile (    "l.nop        \n\t"    );
    asm volatile (    "l.sys 0      \n\t"    );
    asm volatile (    "l.nop        \n\t"    );
}
//-----------------------------------------------------------------
// cpu_context_switch_irq:
//-----------------------------------------------------------------
void cpu_context_switch_irq( void )
{
    // No need to do anything in this system as all interrupts
    // cause the kernel to run...
    OS_ASSERT(_in_interrupt);
}
//-----------------------------------------------------------------
// cpu_load_context:
//-----------------------------------------------------------------
static inline void cpu_load_context(int preempt)
{
    struct register_set *reg_file;

    // Load new thread context
    thread_load_context(preempt);

    // Adjust ESR to have correct interrupt enable bit state
    reg_file = (struct register_set *)_currentTCB->StackPointer;

    if (_currentTCB->critical_depth == 0)
        reg_file->esr |= SPR_SR_IEE;
    else
        reg_file->esr &=~SPR_SR_IEE;
}
//-----------------------------------------------------------------
// cpu_irq:
//-----------------------------------------------------------------
CRITICALFUNC void cpu_irq(void)
{
    int preempt = 0;
    unsigned int stat = IRQ_STATUS & IRQ_MASK;

    // Check that this not occuring recursively!
    OS_ASSERT(!_in_interrupt);
    _in_interrupt = 1;

    // Has timer event fired?
    if (stat & (1 << IRQ_SYSTICK))
    {
        preempt = 1;
        thread_tick();

        // Acknowledge interrupt
        IRQ_STATUS = (1 << IRQ_SYSTICK);
        stat &= ~(1 << IRQ_SYSTICK);
    }

    // More pending interrupts?
    if (stat)
        irq_handler(stat);
    
    // Load new thread context
    cpu_load_context(preempt);

    _in_interrupt = 0;
}
//-----------------------------------------------------------------
// cpu_syscall:
//-----------------------------------------------------------------
void cpu_syscall(void)
{
    // Load new thread context
    cpu_load_context(0);
}
//-----------------------------------------------------------------
// cpu_thread_start:
//-----------------------------------------------------------------
void cpu_thread_start( void )
{
    // Disable all & clear all interrupts
    IRQ_MASK_CLR = 0xFFFFFFFF;
    IRQ_STATUS = 0xFFFFFFFF;

    // Force global IRQ enable to disabled prior to starting 
    // systick & restoring initial context
    mtspr(SPR_SR, 0);

    // Enable Systick IRQ & fault handling
    cpu_int_enable(IRQ_SYSTICK);

    // Generate syscall interrupt to load first context
    cpu_context_switch();
}
//-----------------------------------------------------------------
// cpu_dump_stack:
//-----------------------------------------------------------------
void cpu_dump_stack(void)
{
    struct register_set *reg_file = (struct register_set *)_currentTCB->StackPointer;
    int i;

    printf("Frame:\n");
    printf(" Critical Depth 0x%x\n", _currentTCB->critical_depth);
    printf(" EPC 0x%x\n", reg_file->epc);
    printf(" ESR 0x%x\n", reg_file->esr);
    printf(" R0 = 0x0\n");
    printf(" R1(SP) = 0x%x\n",((unsigned int)_currentTCB->StackPointer) + 132);   
    for (i=0;i<30;i++)
    {
        printf(" R%x = 0x%x\n", i+2, reg_file->reg[i]);
    }
}
//-----------------------------------------------------------------
// cpu_thread_stack_size:
//-----------------------------------------------------------------
int cpu_thread_stack_size(tTaskBlock * pCurrent)
{
    return (int)pCurrent->StackSize;
}
//-----------------------------------------------------------------
// cpu_thread_stack_free:
//-----------------------------------------------------------------
int cpu_thread_stack_free(tTaskBlock * pCurrent)
{
    int i;
    int free = 0;

    for (i=0;i<pCurrent->StackSize;i++)
    {
        if (pCurrent->StackAlloc[i] != STACK_CHK_BYTE)
            break;
        else
            free++;
    }

    return free;
}
//-----------------------------------------------------------------
// cpu_fault 
//-----------------------------------------------------------------
void cpu_fault(void)
{
    printf("FAULT:\n");
    if (_currentTCB)
        cpu_dump_stack();
    while (1);
}
//-----------------------------------------------------------------
// cpu_trap 
//-----------------------------------------------------------------
void cpu_trap(void)
{
    printf("TRAP:\n");
    if (_currentTCB)
        cpu_dump_stack();
    while (1);
}
