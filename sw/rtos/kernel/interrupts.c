//-----------------------------------------------------------------------------
//                                     AltOR32 
//                         Alternative Lightweight OpenRISC 
//                                Ultra-Embedded.com
//                               Copyright 2011 - 2012
//
//                         Email: admin@ultra-embedded.com
//
//                                License: GPL
//  Please contact the above address if you would like a version of this 
//  software with a more permissive license for use in closed source commercial 
//  applications.
//-----------------------------------------------------------------------------
//
// This file is part of AltOR32 Alternative Lightweight OpenRISC project.
//
// AltOR32 is free software; you can redistribute it and/or modify it under 
// the terms of the GNU General Public License as published by the Free Software 
// Foundation; either version 2 of the License, or (at your option) any later 
// version.
//
// AltOR32 is distributed in the hope that it will be useful, but WITHOUT ANY 
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more 
// details.
//
// You should have received a copy of the GNU General Public License
// along with AltOR32; if not, write to the Free Software Foundation, Inc., 
// 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//-----------------------------------------------------------------------------
#include "rtos.h"
#include "interrupts.h"
#include "thread.h"
#include "os_assert.h"

#ifdef INCLUDE_INTERRUPTS
//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
static void interrupts_thread(void *pInt);

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static struct interrupt  _ints[THREAD_MAX_INTERRUPTS];
static void*             _int_lookup[CPU_MAX_INTERRUPTS];

//-----------------------------------------------------------------
// interrupts_init: Setup interrupt task controller
//-----------------------------------------------------------------
void interrupts_init(void)
{
    int i;

    for (i=0;i<THREAD_MAX_INTERRUPTS; i++)
    {
        _ints[i].int_enabled = 0;
        _ints[i].int_pending = 0;
        _ints[i].int_function = 0;
        _ints[i].int_func_arg = 0;
        _ints[i].int_number = -1; // Not allocated!
    }

    for (i=0;i<CPU_MAX_INTERRUPTS; i++)
        _int_lookup[i] = 0;
}
//-----------------------------------------------------------------
// _interrupt_alloc: Allocate interrupt object
//-----------------------------------------------------------------
static struct interrupt * _interrupt_alloc(int intNumber)
{
    struct interrupt *pInterrupt = NULL;
    int cr;
    int i;

    OS_ASSERT(intNumber >= 0 && intNumber < CPU_MAX_INTERRUPTS);

    cr = critical_start();

    for (i=0;i<THREAD_MAX_INTERRUPTS; i++)
    {
        // If not allocated
        if (_ints[i].int_number == -1)
        {
            // Allocate
            _ints[i].int_enabled = 0;
            _ints[i].int_function = 0;
            _ints[i].int_func_arg = 0;
            _ints[i].int_number = intNumber;

            pInterrupt = &_ints[i];

            // Make sure the interrupt is not already allocated!
            OS_ASSERT(_int_lookup[intNumber] == NULL);

            _int_lookup[intNumber] = pInterrupt;
            break;
        }
    }

    critical_end(cr);

    return pInterrupt;
}
//-----------------------------------------------------------------
// interrupts_establish: Setup interrupt task (linked to intNumber IRQ)
//-----------------------------------------------------------------
int interrupts_establish(int intNumber, char *name, int pri, void (*int_task)(void *arg), void *arg, unsigned long *stack, unsigned int stack_size, int enable)
{
    // Allocate an interrupt structure
    struct interrupt * pInterrupt = _interrupt_alloc(intNumber);
    int res;

    OS_ASSERT(pInterrupt);
    OS_ASSERT(int_task);
    OS_ASSERT(pri >= THREAD_INT_PRIO);

    pInterrupt->int_function = int_task;
    pInterrupt->int_func_arg = arg;
    pInterrupt->int_number = intNumber;
    pInterrupt->int_enabled = 0;
    pInterrupt->int_pending = 0;

    // Create the interrupt thread in the blocked state
    res = thread_init_ex(&pInterrupt->int_thread, name, pri, interrupts_thread, pInterrupt, stack, stack_size, THREAD_BLOCKED);
    if (res)
    {
        // Register actual IRQ vector function?
        cpu_int_register(intNumber, interrupts_handler);

        // Enable after establishing?
        if (enable)
        {
            pInterrupt->int_enabled = 1;
            cpu_int_enable(intNumber);
        }
    }
    return res;
}
//-----------------------------------------------------------------
// interrupts_enable: Enable interrupt
//-----------------------------------------------------------------
void interrupts_enable(int int_number)
{
    struct interrupt *pInterrupt;
    int cr;

    OS_ASSERT(int_number < CPU_MAX_INTERRUPTS);
    OS_ASSERT(_int_lookup[int_number]);

    cr = critical_start();

    // Lookup interrupt to pointer
    pInterrupt = (struct interrupt *)_int_lookup[int_number];

    // Enabled!
    pInterrupt->int_enabled = 1;

    // Enable the hardware interrupt
    cpu_int_enable(pInterrupt->int_number);

    critical_end(cr);
}
//-----------------------------------------------------------------
// interrupts_disable: Disable interrupt
//-----------------------------------------------------------------
void interrupts_disable(int int_number)
{
    struct interrupt *pInterrupt;
    int cr;

    OS_ASSERT(int_number < CPU_MAX_INTERRUPTS);
    OS_ASSERT(_int_lookup[int_number]);

    // Thread priority must be less than or equal to IRQ task priority!
    OS_ASSERT(thread_current()->priority <= THREAD_INT_PRIO);

    // Disable pre-emption & interrupts_handler from being executed.
    cr = critical_start();

    // Lookup interrupt to pointer
    pInterrupt = (struct interrupt *)_int_lookup[int_number];

    // The interrupt top half (actual ISR calling interrupts_handler) may
    // have already occurred, in-which case, block this thread until the
    // bottom half (interrupts_thread) has executed then disable the IRQ
    // from occuring again.
    // This is done so as to not loose a IRQ!
    // Yield whilst IRQ is still pending (IRQ task priority must be higher
    // or equal to disabling thread prio).
    while (pInterrupt->int_pending)
        thread_sleep(THREAD_YIELD);

    // Disable the hardware interrupt
    cpu_int_disable(pInterrupt->int_number);

    // Disable flag
    pInterrupt->int_enabled = 0;

    critical_end(cr);
}
//-----------------------------------------------------------------
// interrupts_handler: Function called on low level interrupt
//-----------------------------------------------------------------
void interrupts_handler(int int_number)
{
    struct interrupt *pInterrupt;

    OS_ASSERT(int_number < CPU_MAX_INTERRUPTS);
    OS_ASSERT(_int_lookup[int_number]);

    pInterrupt = (struct interrupt *)_int_lookup[int_number];

    // This interrupt should be enabled & not already pending!
    OS_ASSERT(pInterrupt->int_enabled);
    OS_ASSERT(!pInterrupt->int_pending);

    // Mark IRQ handling as pending
    pInterrupt->int_pending = 1;

    // Disable the hardware interrupt
    cpu_int_disable(pInterrupt->int_number);

    // Acknowledge IRQ event which we have just received
    cpu_int_acknowledge(pInterrupt->int_number);

    // Unblock IRQ task and schedule context switch
    thread_unblock_irq(&pInterrupt->int_thread);
}
//-----------------------------------------------------------------
// interrupts_thread:
//-----------------------------------------------------------------
static void interrupts_thread(void *pInt)
{
    int cr;
    struct interrupt *pInterrupt = (struct interrupt *)pInt;

    for ( ; ; )
    {
        // ... Wake up after being unblocked by actual ISR ...
        OS_ASSERT(pInterrupt->int_enabled);
        OS_ASSERT(pInterrupt->int_pending);

        // Call interrupt thread handler function.
        pInterrupt->int_function(pInterrupt->int_func_arg);

        // Disable all interrupts & preemption
        cr = critical_start();

        // Clear pending flag
        pInterrupt->int_pending = 0;

        // Re-enable the hardware interrupt source
        cpu_int_enable(pInterrupt->int_number);

        // Move IRQ thread to blocked list (and context switch)
        thread_block(&pInterrupt->int_thread);

        // Re-enable interrupts / scheduling
        critical_end(cr);
    }
}
#endif
