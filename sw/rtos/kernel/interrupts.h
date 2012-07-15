#ifndef __INTERRUPTS_H__
#define __INTERRUPTS_H__

#include "rtos.h"
#include "thread.h"

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------
#ifdef DEFAULT_INTERRUPT_THREADS
    #define THREAD_MAX_INTERRUPTS        DEFAULT_INTERRUPT_THREADS
#else
    #define THREAD_MAX_INTERRUPTS        4
#endif

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct interrupt
{
    struct thread   int_thread;
    volatile int    int_enabled;
    volatile int    int_pending;
    void            (*int_function)(void *);
    void*           int_func_arg;
    int             int_number;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Setup interrupt task controller
void    interrupts_init(void);

// Function called on low level interrupt
void    interrupts_handler(int int_number);

// Enable interrupt
void    interrupts_enable(int int_number);

// Disable interrupt
void    interrupts_disable(int int_number);

// Setup interrupt task (linked to intNumber IRQ)
int     interrupts_establish(int intNumber, char *name, int pri, void (*int_task)(void *arg), void *arg, unsigned long *stack, unsigned int stack_size, int enable);

#endif

