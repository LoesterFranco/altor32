#ifndef __LOCK_H__
#define __LOCK_H__

#include "list.h"

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct lock
{
    void *              owner;
    struct link_list    pend_list;
    int                 lock_count;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise lock object
void    lock_init(struct lock *pLock);

// Wait until lock is available (recursive lock)
void    lock_acquire(struct lock *pLock);

// Release/decrement lock (recursive lock)
void    lock_release(struct lock *pLock);

#endif

