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
#include "event.h"
#include "thread.h"
#include "os_assert.h"

#ifdef INCLUDE_EVENTS

//-----------------------------------------------------------------
// event_init: Initialise event object
//-----------------------------------------------------------------
void event_init(struct event *ev)
{
    OS_ASSERT(ev != NULL);

    ev->value = 0;
    semaphore_init(&ev->sema, 0);
}
//-----------------------------------------------------------------
// event_get: Wait for an event to be set (returns bitmap)
//-----------------------------------------------------------------
unsigned int event_get(struct event *ev)
{
    unsigned int value = 0;
    int cr;

    OS_ASSERT(ev != NULL);

    cr = critical_start();

    // Wait for semaphore
    semaphore_pend(&ev->sema);

    // Retrieve value & reset
    value = ev->value;
    ev->value = 0;

    critical_end(cr);

    return value;
}
//-----------------------------------------------------------------
// event_set: Post event value (or add additional bits if already set)
//-----------------------------------------------------------------
void event_set(struct event *ev, unsigned int value)
{
    int cr;

    OS_ASSERT(ev != NULL);
    OS_ASSERT(value);

    cr = critical_start();

    // Already pending event
    if (ev->value != 0)
        ev->value |= value;
    // No pending event
    else
    {
        ev->value = value;
        semaphore_post(&ev->sema);
    }

    critical_end(cr);
}

#endif
