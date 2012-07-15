#ifndef __CRITICAL_H__
#define __CRITICAL_H__

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Force interrupts to be disabled (recursive ok)
int     critical_start(void);

// Restore interrupt enable state (recursive ok)
void    critical_end(int cr);

#endif

