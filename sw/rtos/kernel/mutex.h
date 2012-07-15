#ifndef __MUTEX_H__
#define __MUTEX_H__

#include "list.h"

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct mutex
{
    void *              owner;
    struct link_list    pend_list;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise mutex
void    mutex_init(struct mutex *pMtx);

// Acquire mutex (non-recursive)
void    mutex_acquire(struct mutex *pMtx);

// Release mutex (non-recursive)
void    mutex_release(struct mutex *pMtx);

#endif

