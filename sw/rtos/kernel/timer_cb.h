#ifndef __TIMER_CB_H__
#define __TIMER_CB_H__

#include "list.h"

//----------------------------------------------------------------------
// Defines / Types
//----------------------------------------------------------------------
#define TIMER_MAGIC     0xbeafcafe

typedef unsigned long   tTime;

typedef void (*FP_TIMEOUT_FUNC)(void* user);

struct timer_node
{
    struct link_node    list_node;

    tTime               delta;
    int                 expired;

    unsigned long       magic;

    FP_TIMEOUT_FUNC     func;
    void*               arg;
};

//----------------------------------------------------------------------
// Prototypes
//----------------------------------------------------------------------

// Initialise timer callback service
void timercb_init(void);

// Add item to timer list (with callback to execute on timeout)
void timercb_start(struct timer_node* item, tTime timeout, FP_TIMEOUT_FUNC func, void *arg);

// Cancel pending timeout item (if not already expired)
void timercb_cancel(struct timer_node* item);

// Process timer callback items
void timercb_service(tTime timePassed);

// Dump timer callback list to OS_PRINTF
#ifdef TIMERCB_TEST
void timercb_dump(void);
#endif

#endif

