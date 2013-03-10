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
#include "lock.h"
#include "thread.h"
#include "os_assert.h"

#ifdef INCLUDE_RECURSIVE_LOCK

//-----------------------------------------------------------------
// lock_init: Initialise lock object
//-----------------------------------------------------------------
void lock_init(struct lock *pLock)
{
    OS_ASSERT(pLock != NULL);

    // No default owner
    pLock->owner = NULL;

    // No recursive lock count
    pLock->lock_count = 0;

    // Pending thread list
    list_init(&pLock->pend_list);
}
//-----------------------------------------------------------------
// lock_acquire: Wait until lock is available (recursive lock)
//-----------------------------------------------------------------
void lock_acquire(struct lock *pLock)
{
    struct thread* this_thread;
    int cr;

    OS_ASSERT(pLock != NULL);

    cr = critical_start();

    // Get current (this) thread
    this_thread = thread_current();

    // Is the lock not already locked
    if (pLock->owner == NULL)
    {
        // Acquire lock for this thread
        pLock->owner = this_thread;
    }
    // Is the lock already locked by this thread
    else if (pLock->owner == this_thread)
    {
        // Increase recursive lock count
        pLock->lock_count++;
    }
    // The lock is already 'owned', add
    // thread to pending list
    else
    {
        struct link_node *listnode;

        // Get list node
        listnode = &this_thread->blocking_node;

        // Add node to end of pending list
        list_insert_last(&pLock->pend_list, listnode);

        // Block the thread from running
        thread_block(this_thread);
    }

    critical_end(cr);
}
//-----------------------------------------------------------------
// lock_release: Release/decrement lock (recursive lock)
//-----------------------------------------------------------------
void lock_release(struct lock *pLock)
{
    struct thread* this_thread;
    int cr;

    OS_ASSERT(pLock != NULL);

    cr = critical_start();

    // Get current (this) thread
    this_thread = thread_current();

    // We cannot release a lock that we dont own!
    OS_ASSERT(this_thread == pLock->owner);

    // Reduce recursive lock count
    if (pLock->lock_count > 0)
        pLock->lock_count--;
    // If there are threads pending on this lock
    else if (!list_is_empty(&pLock->pend_list))
    {
        // Unblock the first pending thread
        struct link_node *node = list_first(&pLock->pend_list);

        // Get the thread item
        struct thread* thread = list_entry(node, struct thread, blocking_node);

        // Remove node from linked list
        list_remove(&pLock->pend_list, node);

        // Transfer lock ownership
        pLock->owner = thread;

        // Unblock the first waiting thread
        thread_unblock(thread);
    }
    // Else no-one wants it, no owner
    else
        pLock->owner = NULL;

    critical_end(cr);
}
#endif
