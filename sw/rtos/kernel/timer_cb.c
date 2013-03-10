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
#include "timer_cb.h"
#include "mutex.h"
#include "os_assert.h"

#ifdef INCLUDE_TIMERCB

//----------------------------------------------------------------------
// Locals:
//----------------------------------------------------------------------
static struct link_list        timer_list;
static struct mutex            lock;

//----------------------------------------------------------------------
// timercb_init: Initialise timer callback service
//----------------------------------------------------------------------
void timercb_init(void)
{
    // Initialise timer list & lock
    mutex_init(&lock);
    list_init(&timer_list);
}
//----------------------------------------------------------------------
// timercb_start: Add item to timer list (with callback to execute on timeout)
//----------------------------------------------------------------------
void timercb_start(struct timer_node* item, tTime timeout, FP_TIMEOUT_FUNC func, void *arg)
{
    struct link_node *node;
    struct link_node *newNode;
    tTime total = 0;
    tTime prevtotal = 0;
    struct link_list *list = &timer_list;

    OS_ASSERT(item);
    OS_ASSERT(func);

    mutex_acquire(&lock);

    // Timeout action
    item->func = func;
    item->arg = arg;

    // Not expired yet
    item->expired = 0;

    // Set up list item data pointer
    newNode = &item->list_node;

    // Current list is empty?
    if (list_first(list) == NULL)
    {
        // delta is total timeout
        item->delta = timeout;
        list_insert_first(list, newNode);
    }
    // Timer list has items
    else
    {
        // Itterate through current list and add at correct location
        list_for_each(list, node)
        {
            struct timer_node *tNode = list_entry(node, struct timer_node, list_node);
            OS_ASSERT(tNode);

            // Increment cumulative total
            total += tNode->delta;

            // New timeout less than total (or end of list reached)
            if (timeout <= total)
            {
                // delta time from previous to this node
                item->delta = timeout - prevtotal;

                // Insert into list before current node
                list_insert_before(list, node, newNode);

                // Adjust next nodes delta time
                tNode->delta -= item->delta;
                break;
            }

            prevtotal = total;

            // End of list reached, still not added
            if (node->next == NULL)
            {
                // delta time from previous to this node
                item->delta = timeout - prevtotal;

                // Insert into list before current node
                list_insert_after(list, node, newNode);

                break;
            }
        }
    }

    item->magic = TIMER_MAGIC;
    mutex_release(&lock);
}
//----------------------------------------------------------------------
// timercb_cancel: Cancel pending timeout item (if not already expired)
//----------------------------------------------------------------------
void timercb_cancel(struct timer_node* item)
{
    struct link_node *node;
    struct link_node *next;
    struct timer_node *next_item;
    struct link_list *list = &timer_list;

    OS_ASSERT(list);
    OS_ASSERT(item);

    mutex_acquire(&lock);

    // If the item has not already expired
    if (!item->expired)
    {
        // If the timer has not expired the magic number will be valid
        OS_ASSERT(item->magic == TIMER_MAGIC);

        node = &item->list_node;
        next = node->next;

        // Not the last item?
        if (next)
        {
            // Add current item's remaining time to next
            next_item = list_entry(next, struct timer_node, list_node);
            next_item->delta += item->delta;
        }

        // Reset state
        item->expired = 1;
        item->magic = ~TIMER_MAGIC;

        // Remove from timer list
        list_remove(list, node);
    }

    mutex_release(&lock);
}
//----------------------------------------------------------------------
// timercb_service: Process timer callback items (taking into account
// time passed since last service call)
//----------------------------------------------------------------------
void timercb_service(tTime timePassed)
{
    struct link_node *node;
    struct link_list *list = &timer_list;

    OS_ASSERT(list);

    mutex_acquire(&lock);

    // Iterate through current timer list
    for (node = list_first(list); node ; )
    {
        struct timer_node *item = list_entry(node, struct timer_node, list_node);
        OS_ASSERT(item);
        OS_ASSERT(!item->expired);
        OS_ASSERT(item->magic == TIMER_MAGIC);

        // Some time has passed but not enough to make first item timeout
        if (timePassed < item->delta)
        {
            // Decrement first item then exit
            item->delta -= timePassed;
            break;
        }
        else
        {
            FP_TIMEOUT_FUNC func = item->func;
            void *arg = item->arg;

            // Remove delta time from time passed in-case there
            // are more items in the list.
            timePassed -= item->delta;

            // Reset node state
            item->expired = 1;
            item->magic = ~TIMER_MAGIC;

            // Remove expired node from list before calling callback
            // to allow it to be re-added in the callback.
            list_remove(list, node);

            // Release the lock before calling the callback
            mutex_release(&lock);

            // NOTE: We should measure time taken by callback and
            // add this to timePassed to improve list timing...

            // If action to be performed on timeout, do it!
            if (func)
                func(arg);

            // Re-acquire the lock
            mutex_acquire(&lock);

            // Get next node (new first node)
            node = list_first(list);
        }
    }

    mutex_release(&lock);
}
//----------------------------------------------------------------------
// timercb_dump: Dump timer callback list to OS_PRINTF
//----------------------------------------------------------------------
#ifdef TIMERCB_TEST
void timercb_dump(void)
{
    struct link_node *node;
    tTime total = 0;
    struct link_list *list = &timer_list;

    OS_ASSERT(list);

    OS_PRINTF("Timer list:\n");

    mutex_acquire(&lock);

    // Iterate through current list and print
    list_for_each(list, node)
    {
        struct timer_node *item = list_entry(node, struct timer_node, list_node);

        OS_ASSERT(item);
        OS_ASSERT(item->magic == TIMER_MAGIC);

        // Increment cumulative total
        total += item->delta;

        OS_PRINTF("- Timeout at %d (delta %d)\n", total, item->delta);
    }

    mutex_release(&lock);
}
#endif
#endif
