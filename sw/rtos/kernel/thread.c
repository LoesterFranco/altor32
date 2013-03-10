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
#include "rtos.h"
#include "thread.h"
#include "os_assert.h"

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#ifdef PLATFORM_IDLE_TASK_STACK
    #define IDLE_TASK_STACK        PLATFORM_IDLE_TASK_STACK
#else
    #define IDLE_TASK_STACK        256
#endif

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static struct link_list     _thread_runable;
static struct link_list     _thread_blocked;
static struct link_list     _thread_sleeping;
static struct link_list     _thread_dead;
static struct thread*       _currentThread = NULL;
static struct thread        _idle_task;
static struct thread*       _thread_list_all = NULL;
static int                  _initd = 0;
static volatile long        _tick_count = 0;
static volatile long        _thread_picks = 0;
static unsigned long        _idle_task_stack[IDLE_TASK_STACK];

//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
static void                 thread_idle_task(void* arg);
static struct thread*       thread_pick(void);
static void                 thread_func(void *pThd);

static void                 thread_switch(void);
static void                 thread_insert_priority(struct link_list *pList, struct thread *pInsertNode);

//-----------------------------------------------------------------
// thread_kernel_init: Initialise the RTOS kernel
//-----------------------------------------------------------------
int thread_kernel_init(void)
{
    // NOTE: Interrupts should be disabled prior
    // to calling this function!

    // Initialise thread lists
    list_init(&_thread_runable);
    list_init(&_thread_sleeping);
    list_init(&_thread_blocked);
    list_init(&_thread_dead);

    _thread_list_all = NULL;

    // Create an idle task
    thread_init(&_idle_task, "IDLE_TASK", THREAD_IDLE_PRIO, thread_idle_task, (void*)NULL, (void*)_idle_task_stack, IDLE_TASK_STACK);

    _tick_count = 0;
    _initd = 1;
    return 1;
}
//-----------------------------------------------------------------
// thread_kernel_run: Start the RTOS kernel
//-----------------------------------------------------------------
void thread_kernel_run(void)
{
    if (!_initd)
    {
        OS_PANIC("Halt:Not Initialized\n");
        while(1);
    }

    // Start with idle task so we then pick the best thread to
    // run rather than the first in the list
    _currentThread = &_idle_task;

    // Switch context to the highest priority thread
    cpu_thread_start();
}
//-----------------------------------------------------------------
// thread_init_ex: Create thread with specified start state
//-----------------------------------------------------------------
int thread_init_ex(struct thread *pThread, char *name, int pri, void (*f)(void *), void *arg, unsigned long *stack, unsigned int stack_size, tThreadState initial_state)
{
    int cr;
    int l = 0;

    OS_ASSERT(pThread != NULL);

    // Thread name
    if (!name)
        name = "NO_NAME";

    while (l < THREAD_NAME_LEN && name[l])
    {
        pThread->name[l] = name[l];
        l++;
    }

    pThread->name[THREAD_NAME_LEN-1] = 0;

    // Setup priority
    pThread->priority = pri;

    // Thread function
    pThread->thread_func = f;
    pThread->thread_arg = arg;

    pThread->state = initial_state;
    pThread->wait_delta = 0;
    pThread->run_count = 0;

#ifdef RTOS_MEASURE_THREAD_TIME
    pThread->run_time = 0;
    pThread->run_start = 0;
#endif

    // Task control block
    cpu_thread_init_tcb(&pThread->tcb, thread_func, pThread, stack, stack_size);

    // Begin critical section
    cr = critical_start();

    // Runable: Insert this thread at the end of run list
    if (initial_state == THREAD_RUNABLE)
        thread_insert_priority(&_thread_runable, pThread);
    else if (initial_state == THREAD_BLOCKED)
        list_insert_last(&_thread_blocked, &pThread->node);
    else
    {
        OS_ASSERT(initial_state != THREAD_SLEEPING);
    }

    // Add to simple all threads list
    pThread->next_all = _thread_list_all;
    _thread_list_all = pThread;

    // Set the checkword
    pThread->checkword = THREAD_CHECK_WORD;

    critical_end(cr);

    return 1;
}
//-----------------------------------------------------------------
// thread_init: Create thread (immediately run-able)
//-----------------------------------------------------------------
int    thread_init(struct thread *pThread, char *name, int pri, void (*f)(void *), void *arg, unsigned long *stack, unsigned int stack_size)
{
    return thread_init_ex(pThread, name, pri, f, arg, stack, stack_size, THREAD_RUNABLE);
}
//-----------------------------------------------------------------
// thread_kill: Kill thread and remove from all thread lists.
// Once complete, thread data/stack will not be accessed again by
// RTOS.
// You cannot kill a thread from itself, use thread_suicide instead.
// Returns: 1 = ok, 0 = failed
//-----------------------------------------------------------------
int thread_kill(struct thread *pThread)
{
    int ok = 0;
    struct thread *pCurr = NULL;
    struct thread *pLast = NULL;
    int cr = critical_start();

    // Thread cannot kill itself using thread_kill
    if (pThread != _currentThread)
    {
        // Is the thread currently runable?
        if (pThread->state == THREAD_RUNABLE)
        {
            // Remove from the run list
            list_remove(&_thread_runable, &pThread->node);
        }
        // or is it blocked
        else if (pThread->state == THREAD_BLOCKED)
        {
            // Remove from the blocked list
            list_remove(&_thread_blocked, &pThread->node);
        }
        // or is it blocked
        else if (pThread->state == THREAD_SLEEPING)
        {
            // Remove from the blocked list
            list_remove(&_thread_sleeping, &pThread->node);
        }
        // or is already dead
        else if (pThread->state == THREAD_DEAD)
        {
            // Remove from the dead list
            list_remove(&_thread_dead, &pThread->node);
        }
        else
            OS_PANIC("Unknown thread state!");

        // Remove from simple 'all threads' list
        pCurr = _thread_list_all;
        while (pCurr != NULL)
        {
            if (pCurr == pThread)
            {
                if (pLast != NULL)
                    pLast->next_all = pCurr->next_all;
                else
                    _thread_list_all = pCurr->next_all;
                break;
            }
            pLast = pCurr;
        }

        ok = 1;
    }

    critical_end(cr);

    return ok;
}
//-----------------------------------------------------------------
// thread_suicide: Allows a thread to self terminate.
//-----------------------------------------------------------------
void thread_suicide(struct thread *pThread)
{
    int cr = critical_start();

    OS_ASSERT(pThread == _currentThread);
    OS_ASSERT(pThread->state == THREAD_RUNABLE);

    // Remove from the run list
    list_remove(&_thread_runable, &pThread->node);
    
    // Mark thread as dead and add to dead thread list
    pThread->state = THREAD_DEAD;
    list_insert_last(&_thread_dead, &pThread->node);

    // Mark thread as NULL so it is not re-added to the run
    // list by thread_pick()!
    _currentThread = NULL;

    // Switch context to the new highest priority thread
    thread_switch();

    // We should never reach here
    OS_PANIC("Should not be here");
    critical_end(cr);
}
//-----------------------------------------------------------------
// thread_sleep_thread: Put a specific thread on to the sleep queue
//-----------------------------------------------------------------
void thread_sleep_thread(struct thread *pSleepThread, int timeoutMs)
{
    int cr = critical_start();
    long total = 0;
    long prevtotal = 0;
    struct link_node *node;

    OS_ASSERT(pSleepThread);

    // Is the thread currently runable?
    if (pSleepThread->state == THREAD_RUNABLE)
    {
        // Remove from the run list
        list_remove(&_thread_runable, &pSleepThread->node);
    }
    // or is it blocked
    else if (pSleepThread->state == THREAD_BLOCKED)
    {
        // Remove from the blocked list
        list_remove(&_thread_blocked, &pSleepThread->node);
    }
    else
        OS_PANIC("Thread already sleeping!");

    // Mark thread as sleeping
    pSleepThread->state = THREAD_SLEEPING;

    // NOTE: Add 1 to the sleep time to get at least the time slept for.
    timeoutMs = timeoutMs + 1;

    // Get the first sleeping thread
    node = list_first(&_thread_sleeping);

    // Current sleep list is empty?
    if (node == NULL)
    {
        // delta is total timeout
        pSleepThread->wait_delta = timeoutMs;

        // Add to the start of the sleep list
        list_insert_first(&_thread_sleeping, &pSleepThread->node);
    }
    // Timer list has items
    else
    {
        // Iterate through current list and add at correct location
        for ( ; node ; node = list_next(&_thread_sleeping, node))
        {
            // Get the thread item
            struct thread * pThread = list_entry(node, struct thread, node);

            // Increment cumulative total
            total += pThread->wait_delta;

            // New timeout less than total (or end of list reached)
            if (timeoutMs <= total)
            {
                // delta time from previous to this node
                pSleepThread->wait_delta = timeoutMs - prevtotal;

                // Insert into list before this sleeping thread
                list_insert_before(&_thread_sleeping, &pThread->node, &pSleepThread->node);

                // Adjust next nodes delta time
                pThread->wait_delta -= pSleepThread->wait_delta;
                break;
            }

            prevtotal = total;

            // End of list reached, still not added
            if (list_next(&_thread_sleeping, node) == NULL)
            {
                // delta time from previous to this node
                pSleepThread->wait_delta = timeoutMs - prevtotal;

                // Insert into list after last node (end of list)
                list_insert_last(&_thread_sleeping, &pSleepThread->node);
                break;
            }
        }
    }

    critical_end(cr);
}
//-----------------------------------------------------------------
// thread_sleep_cancel: Stop a thread from sleeping
//-----------------------------------------------------------------
void thread_sleep_cancel(struct thread *pThread)
{
    int cr = critical_start();

    OS_ASSERT(pThread);

    // If the item has not already expired (and is in the sleeping list)
    if (pThread->state == THREAD_SLEEPING)
    {
        // Is there another thread after this in the delta list?
        struct link_node *node = list_next(&_thread_sleeping, &pThread->node);
        if (node)
        {
            struct thread *pNextThread = list_entry(node, struct thread, node);

            // Add current item's remaining time to next
            pNextThread->wait_delta += pThread->wait_delta;
        }

        // Remove from the sleeping list
        list_remove(&_thread_sleeping, &pThread->node);

        // Clear the sleep timer
        pThread->wait_delta = 0;

        // Until this thread is put back in the run list or
        // is re-added to the sleep list then mark as blocked.
        pThread->state = THREAD_BLOCKED;
        list_insert_last(&_thread_blocked, &pThread->node);
    }
    // Else thread timeout has expired and is now runable (or blocked)

    critical_end(cr);
}
//-----------------------------------------------------------------
// thread_sleep: Sleep thread for x milliseconds
//-----------------------------------------------------------------
void thread_sleep(int timeoutMs)
{
    int cr = critical_start();

    // Put the current thread to sleep
    if (timeoutMs > 0)
        thread_sleep_thread(_currentThread, timeoutMs);
    else
        thread_load_context(0);
    // TODO: thread_sleep(0) will not work with co-operative scheduler

    // Switch context to the next highest priority thread
    thread_switch();

    critical_end(cr);
}
//-----------------------------------------------------------------
// thread_switch: Switch context to the highest priority thread
//-----------------------------------------------------------------
static void thread_switch(void)
{
    // Get the current run count
    long oldRuncount = _currentThread->run_count;

    // Cause context switch
    cpu_context_switch();

    // In-order to get back to this point, we must have been
    // picked by thread_pick() and the run-count incremented.
    OS_ASSERT(oldRuncount != (_currentThread->run_count));

    // This thread must be in the run list otherwise something has gone wrong!
    OS_ASSERT(_currentThread->state == THREAD_RUNABLE);
}
//-----------------------------------------------------------------
// thread_load_context: Find highest priority run-able thread to run
//-----------------------------------------------------------------
CRITICALFUNC void thread_load_context(int preempt)
{
    struct thread * pThread;

    // If non pre-emptive scheduler, don't change threads for pre-emption.
    // (Don't change context until the current thread is non-runnable)
#ifdef RTOS_COOPERATIVE_SCHEDULING
    if (preempt && _currentThread->state == THREAD_RUNABLE)
        return;
#endif

#ifdef RTOS_MEASURE_THREAD_TIME
    // How long was this thread scheduled for?
    if (_currentThread->run_start != 0)
        _currentThread->run_time += cpu_timediff(cpu_timenow(), _currentThread->run_start);
#endif

    // Now pick the highest thread that can be run and restore it's context.
    pThread = thread_pick();

#ifdef RTOS_MEASURE_THREAD_TIME
    // Take a snapshot of the system clock when thread selected
    pThread->run_start = cpu_timenow();

    // Time=0 has a special meaning!
    if (pThread->run_start == 0)
        pThread->run_start = 1;
#endif

    // Load new thread's context
    _currentThread = pThread;

    // Load the new TCB reference
    _currentTCB = &_currentThread->tcb;

    // Try and detect stack overflow
    OS_ASSERT(_currentTCB->StackAlloc[0] == STACK_CHK_BYTE);
}
//-----------------------------------------------------------------
// thread_current: Get the current thread that is active!
//-----------------------------------------------------------------
struct thread* thread_current()
{
    return _currentThread;
}
//-----------------------------------------------------------------
// thread_pick: Pick the highest priority runable thread
// NOTE: Must be called within critical protection region
//-----------------------------------------------------------------
static CRITICALFUNC struct thread* thread_pick(void)
{
    struct thread *pThread;
    struct link_node *node;

    // If we have a current running task and if the current thread
    // is still run-able, put it in the correct position in the list.
    if (_currentThread && _currentThread->state == THREAD_RUNABLE)
    {
        // Remove it from the run list
        list_remove(&_thread_runable, &_currentThread->node);
        // and re-insert at appropriate position in run list
        // based on thread priority.
        // This will be after all the other threads at the same
        // priority level, hence allowing round robin execution
        // of other threads with the same priority level.
        thread_insert_priority(&_thread_runable, _currentThread);
    }

    // Get the first runable thread
    node = list_first(&_thread_runable);
    OS_ASSERT(node != NULL);

    pThread = list_entry(node, struct thread, node);

    // We should have found a task to run as long as there is at least one
    // task on the run list (there should be as this is why we have the idle
    // task!).
    OS_ASSERT(pThread != NULL);
    OS_ASSERT(pThread->checkword == THREAD_CHECK_WORD);
    OS_ASSERT(pThread->state == THREAD_RUNABLE);

    pThread->run_count++;

    // Total thread context switches / timer ticks have occurred
    _thread_picks++;

    return pThread;
}
//-----------------------------------------------------------------
// thread_tick: Kernel tick handler
// NOTE: Must be called within critical protection region (or INT)
//-----------------------------------------------------------------
CRITICALFUNC void thread_tick(void)
{
    struct thread *pThread = NULL;
    struct link_node *node;

    // Get the first sleeping thread
    node = list_first(&_thread_sleeping);
    pThread = list_entry(node, struct thread, node);

    // Decrement a tick from the first item in the list
    if (pThread && pThread->wait_delta)
        pThread->wait_delta--;

    // Iterate through list of sleeping threads
    while (pThread != NULL)
    {
        OS_ASSERT(pThread->checkword == THREAD_CHECK_WORD);
        OS_ASSERT(pThread->state == THREAD_SLEEPING);

        // Has this item timed out?
        if (pThread->wait_delta == 0)
        {
            // Remove from the sleep list
            list_remove(&_thread_sleeping, &pThread->node);

            // Add to the run list and mark runable
            pThread->state = THREAD_RUNABLE;
            thread_insert_priority(&_thread_runable, pThread);

            // Get next node (new first node)
            node = list_first(&_thread_sleeping);
            pThread = list_entry(node, struct thread, node);
        }
        // Non-zero timeout remaining, end of timed out items
        else
            break;
    }

    // Thats all, thread_load_context() will do the pick
    // of the highest priority runable task...

    _tick_count++;
}
//-----------------------------------------------------------------
// thread_tick_count: Get the tick count for the RTOS
//-----------------------------------------------------------------
long thread_tick_count(void)
{
    return _tick_count;
}
//-----------------------------------------------------------------
// thread_func: Wrapper for thread entry point
//-----------------------------------------------------------------
static void thread_func(void *pThd)
{
    struct thread *pThread = (struct thread *)pThd;

    OS_ASSERT(pThread);
    OS_ASSERT(pThread->checkword == THREAD_CHECK_WORD);

    // Execute thread function
    pThread->thread_func(pThread->thread_arg);

    // Now thread has exited, call thread_suicide!
    thread_suicide(pThread);
    
    // We should never reach here!
    OS_PANIC("Should not be here");
}
//-----------------------------------------------------------------
// thread_block: Block specified thread from executing
// WARNING: Call within critical section!
//-----------------------------------------------------------------
void thread_block(struct thread *pThread)
{
    OS_ASSERT(pThread->checkword == THREAD_CHECK_WORD);
    OS_ASSERT(pThread->state == THREAD_RUNABLE);

    // Mark thread as blocked
    pThread->state = THREAD_BLOCKED;

    // Remove from the run list
    list_remove(&_thread_runable, &pThread->node);

    // Add to the blocked list
    list_insert_last(&_thread_blocked, &pThread->node);

    // Switch context to the new highest priority thread
    thread_switch();
}
//-----------------------------------------------------------------
// _thread_unblock: Unblock specified thread. Internal function.
// Manipulates the ready/blocked/sleeping lists only.
// WARNING: Call within critical section!
//-----------------------------------------------------------------
static void _thread_unblock(struct thread *pThread)
{
    // WARNING: There is no gaurantee that unblock is not called
    // on a thread that is already runable.
    // This is due to a timed semaphore timing out, being made
    // runable again but that thread not being scheduled prior
    // to the post operation which will unblock it...

    // Is thread sleeping (i.e doing a timed pend using thread_sleep)?
    if (pThread->state == THREAD_SLEEPING)
    {
        // Is there another thread after this in the delta sleeping list?
        struct link_node *node = list_next(&_thread_sleeping, &pThread->node);
        if (node)
        {
            struct thread *pNextThread = list_entry(node, struct thread, node);

            // Add current item's remaining time to next
            pNextThread->wait_delta += pThread->wait_delta;
        }

        // Remove from the sleeping list
        list_remove(&_thread_sleeping, &pThread->node);

        // Clear the sleep timer
        pThread->wait_delta = 0;
    }
    // Is the thread in the blocked list
    else if (pThread->state == THREAD_BLOCKED)
    {
        // Remove from the blocked list
        list_remove(&_thread_blocked, &pThread->node);
    }
    // Already in the run list, exit!
    else if (pThread->state == THREAD_RUNABLE)
        return ;

    // Mark thread as run-able
    pThread->state = THREAD_RUNABLE;

    // Add to the run list
    thread_insert_priority(&_thread_runable, pThread);
}
//-----------------------------------------------------------------
// thread_unblock: Unblock specified thread / enable execution
// WARNING: Call within critical section!
//-----------------------------------------------------------------
void thread_unblock(struct thread *pThread)
{
    OS_ASSERT(pThread->checkword == THREAD_CHECK_WORD);

    // Make sure thread is now in the run list
    _thread_unblock(pThread);

    // If un-blocked thread is higher priority than this thread
    // then switch context to the new highest priority thread
    if (pThread->priority > _currentThread->priority)
        thread_switch();
}
//-----------------------------------------------------------------
// thread_unblock_irq: Unblock thread from IRQ
//-----------------------------------------------------------------
void thread_unblock_irq(struct thread *pThread)
{
    // Critical section should not be required, but for sanity
    int cr = critical_start();

    OS_ASSERT(pThread->checkword == THREAD_CHECK_WORD);

    // Make sure thread is now in the run list
    _thread_unblock(pThread);

    // Schedule a context switch to occur after IRQ completes
    cpu_context_switch_irq();

    critical_end(cr);
}
//-----------------------------------------------------------------
// thread_insert_priority: Insert thread into list in priority order
//-----------------------------------------------------------------
static CRITICALFUNC void thread_insert_priority(struct link_list *pList, struct thread *pInsertNode)
{
    struct link_node *node;

    OS_ASSERT(pList != NULL);
    OS_ASSERT(pInsertNode != NULL);

    // No items in the queue, insert at the head
    if (list_is_empty(pList))
        list_insert_first(pList, &pInsertNode->node);
    else
    {
        // Iterate through list and add in order of priority
        // NOTE: Duplicates will be added to end of list of duplicate
        // threads priorities.
        list_for_each(pList, node)
        {
            // Get the thread item
            struct thread* thread = list_entry(node, struct thread, node);

            // Is threads priority lower than this thread?
            if (pInsertNode->priority > thread->priority)
            {
                // Insert before this node
                list_insert_before(pList, node, &pInsertNode->node);
                break;
            }

            // End of the list reached and node not inserted yet
            if (list_next(pList, node) == NULL)
            {
                // Insert after current last node
                list_insert_after(pList, node, &pInsertNode->node);
                break;
            }
        }
    }
}
//-----------------------------------------------------------------
// thread_idle_task: Idle task function
//-----------------------------------------------------------------
static void thread_idle_task(void* arg)
{
    while (1)
        rtos_services.idle();
}
//-----------------------------------------------------------------
// thread_print_thread: Print thread details to OS_PRINTF
//-----------------------------------------------------------------
static void thread_print_thread(int idx, struct thread *pThread, long sleepTime)
{
    char stateChar;

    OS_PRINTF("%d:\t", idx+1);
    OS_PRINTF("|%10.10s|\t", pThread->name);
    OS_PRINTF("%d\t", pThread->priority);

    if (pThread == _currentThread)
        stateChar = '*';
    else
    {
        switch (pThread->state)
        {
            case THREAD_RUNABLE:
                stateChar = 'R';
            break;
            case THREAD_SLEEPING:
                stateChar = 'S';
            break;
            case THREAD_BLOCKED:
                stateChar = 'B';
            break;
            case THREAD_DEAD:
                stateChar = 'X';
            break;
            default:
                stateChar = 'U';
            break;
        }
    }

    OS_PRINTF("%c\t", stateChar);
    OS_PRINTF("%ld\t", sleepTime);
    OS_PRINTF("%ld\t", pThread->run_count);
    OS_PRINTF("%ld\r\n", cpu_thread_stack_free(&pThread->tcb));
}
//-----------------------------------------------------------------
// thread_dump_list: Dump thread list to OS_PRINTF
//-----------------------------------------------------------------
void thread_dump_list(void)
{
    struct thread      *pThread;
    struct link_node  *node;
    long sleepTimeTotal = 0;
    int idx = 0;

    int cr = critical_start();

    OS_PRINTF("Thread Dump:\r\n");
    OS_PRINTF("Num     Name        Pri    State    Sleep    Runs    Free Stack\r\n");

    // Print all runable threads
    pThread = _thread_list_all;
    while (pThread != NULL)
    {
        if (pThread->state == THREAD_RUNABLE)
            thread_print_thread(idx++, pThread, 0);
        pThread = pThread->next_all;
    }

    // Print sleeping threads
    node = list_first(&_thread_sleeping);
    while (node != NULL)
    {
        pThread = list_entry(node, struct thread, node);

        sleepTimeTotal += pThread->wait_delta;
        thread_print_thread(idx++, pThread, sleepTimeTotal);

        node = list_next(&_thread_sleeping, node);
    }

    // Print blocked threads
    pThread = _thread_list_all;
    while (pThread != NULL)
    {
        if (pThread->state == THREAD_BLOCKED)
            thread_print_thread(idx++, pThread, 0);
        pThread = pThread->next_all;
    }

    // Print dead threads
    pThread = _thread_list_all;
    while (pThread != NULL)
    {
        if (pThread->state == THREAD_DEAD)
            thread_print_thread(idx++, pThread, 0);
        pThread = pThread->next_all;
    }

    critical_end(cr);
}
//-----------------------------------------------------------------
// thread_get_cpu_load: Calculate CPU load percentage.
// Higher = heavier system task load.
// Requires RTOS_MEASURE_THREAD_TIME to be defined along with 
// appropriate system clock/time measurement functions.
//-----------------------------------------------------------------
#ifdef RTOS_MEASURE_THREAD_TIME
int thread_get_cpu_load(void)
{
    struct thread      *pThread;
    unsigned long idle_time = 0;
    unsigned long total_time = 0;

    int cr = critical_start();

    // Walk the thread list and calculate sum of total time spent in all threads 
    pThread = _thread_list_all;
    while (pThread != NULL)
    {
        // Idle task
        if (pThread == &_idle_task)
        {
            OS_ASSERT( idle_time == 0 );
            idle_time = pThread->run_time;
            total_time += pThread->run_time;
        }
        // Other tasks
        else
            total_time += pThread->run_time;

        // Clear time once read
        pThread->run_time = 0;

        // Next thread in the list
        pThread = pThread->next_all;
    }

    critical_end(cr);

    if (total_time)
        return 100 - ((idle_time * 100) / total_time);
    else
        return 0;
}
#endif
//-----------------------------------------------------------------
// _thread_assert: Assert handler used by OS_ASSERT/OS_PANIC
//-----------------------------------------------------------------
void _thread_assert(const char *reason, const char *file, int line)
{
    critical_start();

    OS_PRINTF("[%s] Assert failed: %s (%s:%d)\r\n", _currentThread->name, reason, file, line);

    // Dump thread list
    thread_dump_list();

    // Dump call stack
    cpu_dump_stack();

    // Perform system specific reboot (or halt)
    rtos_services.reboot();
}
