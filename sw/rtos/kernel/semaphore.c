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
#include "semaphore.h"
#include "thread.h"
#include "os_assert.h"

#ifdef INCLUDE_SEMAPHORE
//-----------------------------------------------------------------
// semaphore_init: Initialise semaphore with an initial value
//-----------------------------------------------------------------
void semaphore_init(struct semaphore *pSem, int initial_count)
{
    OS_ASSERT(pSem != NULL);

    // Initial count
    pSem->count = initial_count;

    // Pending thread list
    list_init(&pSem->pend_list);
}
//-----------------------------------------------------------------
// semaphore_pend: Decrement semaphore or block if already 0
//-----------------------------------------------------------------
void semaphore_pend(struct semaphore *pSem)
{
    int cr;

    OS_ASSERT(pSem != NULL);

    cr = critical_start();

    // If one immediatly available
    if (pSem->count > 0)
        pSem->count--;
    // None available, add to queue
    else
    {
        struct link_node *listnode;

        // Get current (this) thread
        struct thread* this_thread = thread_current();

        // Setup list node
        listnode = &this_thread->blocking_node;

        // Add node to end of pending list
        list_insert_last(&pSem->pend_list, listnode);

        // Block the thread from running
        thread_block(this_thread);
    }

    critical_end(cr);
}
//-----------------------------------------------------------------
// semaphore_post: Increment semaphore count
//-----------------------------------------------------------------
void semaphore_post(struct semaphore *pSem)
{
    int cr;

    OS_ASSERT(pSem != NULL);

    cr = critical_start();

    // Increment semaphore count
    pSem->count++;

    // If there are threads pending on this semaphore
    if (!list_is_empty(&pSem->pend_list))
    {
        // Unblock the first pending thread
        struct link_node *node = list_first(&pSem->pend_list);

        // Get the thread item
        struct thread* thread = list_entry(node, struct thread, blocking_node);

        // Remove node from linked list
        list_remove(&pSem->pend_list, node);

        // Count down semaphore which has been taken by the
        // pending thread...
        pSem->count--;

        // Tell anyone who cares what
        // caused the thread to be unblocked...
        thread->unblocking_arg = node;

        // Unblock the waiting thread
        thread_unblock(thread);
    }

    critical_end(cr);
}
//-----------------------------------------------------------------
// semaphore_post_irq: Increment semaphore (interrupt context safe)
//-----------------------------------------------------------------
void semaphore_post_irq(struct semaphore *pSem)
{
    int cr;

    OS_ASSERT(pSem != NULL);

    cr = critical_start();

    // Increment semaphore count
    pSem->count++;

    // If there are threads pending on this semaphore
    if (!list_is_empty(&pSem->pend_list))
    {
        // Unblock the first pending thread
        struct link_node *node = list_first(&pSem->pend_list);

        // Get the thread item
        struct thread* thread = list_entry(node, struct thread, blocking_node);

        // Remove node from linked list
        list_remove(&pSem->pend_list, node);

        // Count down semaphore which has been taken by the
        // pending thread...
        pSem->count--;

        // Tell anyone who cares what
        // caused the thread to be unblocked...
        thread->unblocking_arg = node;

        // Unblock the waiting thread
        thread_unblock_irq(thread);
    }

    critical_end(cr);
}
//-----------------------------------------------------------------
// semaphore_try: Attempt to decrement semaphore or return 0
//-----------------------------------------------------------------
int semaphore_try(struct semaphore *pSem)
{
    int result;
    int cr;

    OS_ASSERT(pSem != NULL);

    cr = critical_start();

    // If one immediatly available
    if (pSem->count > 0)
    {
        pSem->count--;
        result = 1;
    }
    // None available currently
    else
        result = 0;

    critical_end(cr);

    return result;
}
//-----------------------------------------------------------------
// semaphore_timed_pend: Decrement semaphore (with timeout)
//-----------------------------------------------------------------
int semaphore_timed_pend(struct semaphore *pSem, int timeoutMs)
{
    int cr;
    int result = 0;

    OS_ASSERT(pSem != NULL);

    cr = critical_start();

    // If one immediatly available
    if (pSem->count > 0)
    {
        pSem->count--;
        result = 1;
    }
    // None available, add to queue (if timeout specified)
    else if (timeoutMs > 0)
    {
        struct link_node *listnode;

        // Get current (this) thread
        struct thread* this_thread = thread_current();

        // Setup list node
        listnode = &this_thread->blocking_node;

        // Add node to end of pending list
        list_insert_last(&pSem->pend_list, listnode);

        // Clear unblocking arg
        this_thread->unblocking_arg = NULL;

        // Send the thread to sleep for the timeout period
        thread_sleep(timeoutMs);

        // Is the thread awake due to a semaphore_post?
        if (this_thread->unblocking_arg != NULL)
            result = 1;
        // Else we must have timed out
        else
        {
            struct link_list *pList = &pSem->pend_list;
            struct link_node *node;

            // Walk the list
            list_for_each(pList, node)
            {
                struct thread *node_thread = list_entry(node, struct thread, blocking_node);

                // Is this us?
                if (this_thread == node_thread)
                {
                    // Remove node from linked list
                    list_remove(pList, node);

                    // Stop scanning this list!
                    break;
                }
            }

            // We should not have reached the end of the list
            // without finding our entry.
            OS_ASSERT(node != NULL);

            result = 0;
        }
    }

    critical_end(cr);

    return result;
}
#endif
