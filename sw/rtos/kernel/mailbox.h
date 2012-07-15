#ifndef __MAILBOX_H__
#define __MAILBOX_H__

#include "list.h"
#include "semaphore.h"

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------
#ifdef DEFAULT_MAILBOX_SIZE
    #define MAILBOX_MAX_ITEMS        DEFAULT_MAILBOX_SIZE
#else
    #define MAILBOX_MAX_ITEMS        32
#endif

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct mailbox
{
    void*               entries[MAILBOX_MAX_ITEMS];
    int                 head;
    int                 tail;
    int                 count;

    struct semaphore    sema;
};

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise mailbox
void    mailbox_init(struct mailbox *pMbox);

// Post message to mailbox (copy pointer 'val')
int     mailbox_post(struct mailbox *pMbox, void *val);

// Wait for mailbox message
void    mailbox_pend(struct mailbox *pMbox, void **val);

// Wait for mailbox message (with timeout)
int     mailbox_pend_timed(struct mailbox *pMbox, void **val, int timeoutMs);

#endif
