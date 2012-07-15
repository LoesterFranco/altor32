#ifndef __SEMAPHORE_H__
#define __SEMAPHORE_H__

#include "list.h"

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct semaphore
{
    int                 count;
    struct link_list    pend_list;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise semaphore with an initial value
void    semaphore_init(struct semaphore *pSem, int initial_count);

// Increment semaphore count
void    semaphore_post(struct semaphore *pSem);

// Increment semaphore (interrupt context safe)
void    semaphore_post_irq(struct semaphore *pSem);

// Decrement semaphore or block if already 0
void    semaphore_pend(struct semaphore *pSem);

// Attempt to decrement semaphore or return 0
int     semaphore_try(struct semaphore *pSem);

// Decrement semaphore (with timeout)
int     semaphore_timed_pend(struct semaphore *pSem, int timeoutMs);

#endif

