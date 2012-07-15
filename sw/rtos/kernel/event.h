#ifndef __EVENT_H__
#define __EVENT_H__

#include "semaphore.h"

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct event
{
    unsigned int        value;
    struct semaphore    sema;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise event object
void         event_init(struct event *ev);

// Wait for an event to be set (returns bitmap)
void         event_set(struct event *ev, unsigned int value);

// Post event value (or add additional bits if already set)
unsigned int event_get(struct event *ev);

#endif
