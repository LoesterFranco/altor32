#ifndef __THREAD_H__
#define __THREAD_H__

#include "list.h"

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------

// Max name length for a thread
#define THREAD_NAME_LEN     10

// Idle task priority (do not change)
#define THREAD_IDLE_PRIO    -1

// Min thread priority number
#define THREAD_MIN_PRIO     0

// Max thread priority number
#define THREAD_MAX_PRIO     10

// Min interrupt priority
#define THREAD_INT_PRIO     (THREAD_MAX_PRIO + 1)

// Thread structure checkword
#define THREAD_CHECK_WORD   0xBABEDEAF

// Thread sleep arg used to yield
#define THREAD_YIELD        0

//-----------------------------------------------------------------
// Enums
//-----------------------------------------------------------------

// Thread state enumeration
typedef enum eThreadState
{
    THREAD_RUNABLE,
    THREAD_SLEEPING,
    THREAD_BLOCKED,
    THREAD_DEAD
} tThreadState;

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct thread
{
    // Thread task control block
    tTaskBlock      tcb;

    // Thread name (used in debug output)
    char            name[THREAD_NAME_LEN];

    // Thread priority
    int             priority;

    // state (Run-able, blocked or sleeping)
    tThreadState    state;

    // Sleep time remaining (ticks) (delta)
    long            wait_delta;

    // Thread run count
    long            run_count;

#ifdef RTOS_MEASURE_THREAD_TIME
    // Measure time each thread is active for?
    unsigned long   run_time;
    unsigned long   run_start;
#endif

    // Thread function
    void            (*thread_func)(void *);
    void            *thread_arg;

    // Run/Sleep/Blocked list node
    struct link_node node;

    // next thread in complete name list
    struct thread   *next_all;

    // Blocking node items
    struct link_node blocking_node;
    void*           unblocking_arg;

    // Thread check word
    unsigned long   checkword;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise the RTOS kernel
int             thread_kernel_init(void);

// Start the RTOS kernel
void            thread_kernel_run(void);

// Create thread (immediately run-able)
int             thread_init(struct thread *pTread, char *name, int pri, void (*f)(void *), void *arg, unsigned long *stack, unsigned int stack_size);

// Create thread with specified start state
int             thread_init_ex(struct thread *pThread, char *name, int pri, void (*f)(void *), void *arg, unsigned long *stack, unsigned int stack_size, tThreadState initial_state);

// Kill thread and remove from all thread lists.
// Once complete, thread data/stack will not be accessed again by RTOS.
// You cannot kill a thread from itself, use thread_suicide instead.
int             thread_kill(struct thread *pThread);

// Allows a thread to self terminate
void            thread_suicide(struct thread *pThread);

// Sleep thread for x milliseconds
void            thread_sleep(int timeMs);

// Extended thread sleep API
void            thread_sleep_thread(struct thread *pSleepThread, int timeoutMs);
void            thread_sleep_cancel(struct thread *pThread);

// Get current thread
struct thread*  thread_current(void);

// Kernel tick handler
void            thread_tick(void);

// Get the tick count for the RTOS
long            thread_tick_count(void);

// Block specified thread
void            thread_block(struct thread *pThread);

// Unblock specified thread
void            thread_unblock(struct thread *pThread);

// Unblock thread from running (called from ISR context)
void            thread_unblock_irq(struct thread *pThread);

// Dump thread list to OS_PRINTF
void            thread_dump_list(void);

// Calculate CPU load percentage
int             thread_get_cpu_load(void);

// Find highest priority run-able thread to run
void            thread_load_context( int preempt );

#endif

