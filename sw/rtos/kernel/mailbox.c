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
#include "mailbox.h"
#include "thread.h"
#include "os_assert.h"

#ifdef INCLUDE_MAILBOX
//-----------------------------------------------------------------
// mailbox_init: Initialise mailbox
//-----------------------------------------------------------------
void mailbox_init(struct mailbox *pMbox)
{
    int i;

    OS_ASSERT(pMbox != NULL);

    for (i=0;i<MAILBOX_MAX_ITEMS;i++)
        pMbox->entries[i] = NULL;

    pMbox->head = 0;
    pMbox->tail = 0;
    pMbox->count = 0;

    // Initialise mailbox item ready semaphore
    semaphore_init(&pMbox->sema, 0);
}
//-----------------------------------------------------------------
// mailbox_post: Post message to mailbox (copy pointer 'val')
//-----------------------------------------------------------------
int mailbox_post(struct mailbox *pMbox, void *val)
{
    int cr;
    int res = 0;

    OS_ASSERT(pMbox != NULL);

    cr = critical_start();

    // Mailbox has free space?
    if (pMbox->count < MAILBOX_MAX_ITEMS)
    {
        // Add pointer to mailbox
        pMbox->entries[pMbox->tail] = val;

        // Wrap?
        if (++pMbox->tail == MAILBOX_MAX_ITEMS)
            pMbox->tail = 0;

        // Increment mail count
        pMbox->count++;

        // Notify waiting threads that item added
        semaphore_post(&pMbox->sema);

        res = 1;
    }
    // Mailbox full!
    else
        res = 0;

    critical_end(cr);

    return res;
}
//-----------------------------------------------------------------
// mailbox_pend: Wait for mailbox message
//-----------------------------------------------------------------
void mailbox_pend(struct mailbox *pMbox, void **val)
{
    int cr;

    OS_ASSERT(pMbox != NULL);

    cr = critical_start();

    // Pend on a new item being added
    semaphore_pend(&pMbox->sema);

    OS_ASSERT(pMbox->count > 0);

    // Retrieve the mail pointer
    if (val)
        *val = pMbox->entries[pMbox->head];

    // Wrap
    if (++pMbox->head == MAILBOX_MAX_ITEMS)
        pMbox->head = 0;

    // Decrement items in queue
    pMbox->count--;

    critical_end(cr);
}
//-----------------------------------------------------------------
// mailbox_pend_timed: Wait for mailbox message (with timeout)
// Returns: 1 = mail retrieved, 0 = timeout
//-----------------------------------------------------------------
int mailbox_pend_timed(struct mailbox *pMbox, void **val, int timeoutMs)
{
    int cr;
    int result = 0;

    OS_ASSERT(pMbox != NULL);

    cr = critical_start();

    // Wait for specified timeout period
    if (semaphore_timed_pend(&pMbox->sema, timeoutMs))
    {
        OS_ASSERT(pMbox->count > 0);

        // Retrieve the mail pointer
        if (val)
            *val = pMbox->entries[pMbox->head];

        // Wrap
        if (++pMbox->head == MAILBOX_MAX_ITEMS)
            pMbox->head = 0;

        // Decrement items in queue
        pMbox->count--;

        result = 1;
    }

    critical_end(cr);

    return result;
}
#endif
