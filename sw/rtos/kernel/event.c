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
