#ifndef __CPU_THREAD_H__
#define __CPU_THREAD_H__

#ifndef NULL 
    #define NULL    0
#endif

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------
#define STACK_CHK_BYTE      0xBABEFEAD

// Optional: Define gcc section linkage to relocate critical functions to faster memory
#ifndef CRITICALFUNC
    #define CRITICALFUNC
#endif

//-----------------------------------------------------------------
// Structures
//-----------------------------------------------------------------

// Task Control Block
typedef struct sTaskBlock
{
    // Current stack pointer (Must be first item in struct)
    volatile unsigned long  *StackPointer;

    // Stack end pointer
    volatile unsigned long  *StackAlloc;

    // Stack size
    unsigned int            StackSize;

    // Critical section / Interrupt status
    unsigned int            critical_depth;
} tTaskBlock;


// Exception stack frame layout for context save / restore
struct register_set
{
    // EPC (saved PC+4)
    unsigned int epc;

    // ESR (saved SR)
    unsigned int esr;

    // Excludes r0, r1
    unsigned int reg[32-2];
};

//-----------------------------------------------------------------
// Globals
//-----------------------------------------------------------------

// Current Task Control Block
extern volatile tTaskBlock * _currentTCB;

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise thread context
void    cpu_thread_init_tcb( tTaskBlock *tcb, void (*func)(void *), void *funcArg, unsigned long *stack, unsigned int stack_size );

// Start first thread switch
void    cpu_thread_start(void);

// Force context switch
void    cpu_context_switch( void );

// Force context switch (from IRQ)
void    cpu_context_switch_irq( void );

// Critical section entry & exit
int     cpu_critical_start(void);
void    cpu_critical_end(int cr);

// Dump thread stack details upon assertion / exception
void    cpu_dump_stack(void);

// Specified thread TCB's free stack entries count
int     cpu_thread_stack_free(tTaskBlock * pCurrent);

// Specified thread TCB's total stack size
int     cpu_thread_stack_size(tTaskBlock * pCurrent);

void    cpu_syscall(void);

CRITICALFUNC void cpu_irq(void);

// CPU clocks/time measurement functions (optional, used if RTOS_MEASURE_THREAD_TIME defined)
unsigned long cpu_timenow(void);
long          cpu_timediff(unsigned long a, unsigned long b);

#endif    // __CPU_THREAD_H__

