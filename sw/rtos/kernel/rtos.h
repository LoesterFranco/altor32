#ifndef __RTOS_H__
#define __RTOS_H__

//-----------------------------------------------------------------
// Build Type
//-----------------------------------------------------------------
#if defined ARM_CORTEX_M3
    #include "arch/cortex_m3/cpu_thread.h"
    #include "arch/cortex_m3/cpu_interrupts.h"
#elif defined ARM_ARM7TDMI
    #include "arch/arm7tdmi/cpu_thread.h"
    #include "arch/arm7tdmi/cpu_interrupts.h"
#elif defined AVR_PLATFORM
    #include "arch/avr/cpu_thread.h"
    #include "arch/avr/cpu_interrupts.h"
#elif defined MPX_PLATFORM
    #include "arch/mpx/cpu_thread.h"
    #include "arch/mpx/cpu_interrupts.h"
#elif defined ALTOR32_PLATFORM
    #include "arch/altor32/cpu_thread.h"
    #include "arch/altor32/cpu_interrupts.h"
#elif defined OR32_PLATFORM
    #include "arch/or32/cpu_thread.h"
    #include "arch/or32/cpu_interrupts.h"
#else
    // ...
#endif

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------
#ifndef NULL
    #define NULL    0
#endif

#ifndef FALSE
    #define FALSE   0
#endif

#ifndef TRUE
    #define TRUE    1
#endif

//-----------------------------------------------------------------
// Platform Includes
//-----------------------------------------------------------------
#include "critical.h"
#include "os_assert.h"
#include "list.h"
#include "thread.h"
#include "mutex.h"
#include "semaphore.h"
#include "event.h"
#include "lock.h"
#include "mailbox.h"
#include "interrupts.h"
#include "mem_alloc.h"
#include "timer_cb.h"

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
struct sRtosServices
{
    int (*printf)( const char* ctrl1, ... );
    void (*idle)( void );
    void (*reboot)( void );
};

extern struct sRtosServices    rtos_services;

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise RTOS (should be first RTOS function called)
void                rtos_init(void);

// Start RTOS with init task
void                rtos_start(void (*init_func)(void *arg), void *arg, int pri, unsigned int stack_size);

// RTOS heap init - only required if dynamic RTOS object allocation used
void                rtos_heap_init(unsigned char *heap, unsigned int size);

// Allocation of RTOS item
struct thread*      rtos_thread_create(char *name, int pri, void (*f)(void *), void *arg, unsigned int stack_size);
struct mutex*       rtos_mutex_create(void);
struct semaphore*   rtos_semaphore_create(int initial_count);
struct mailbox*     rtos_mailbox_create(void);
struct lock*        rtos_lock_create(void);

// Free RTOS items
void                rtos_thread_destroy(struct thread* thread);
void                rtos_mutex_destroy(struct mutex* mtx);
void                rtos_semaphore_destroy(struct semaphore* sema);
void                rtos_mailbox_destroy(struct mailbox* mailbox);
void                rtos_lock_destroy(struct lock* lock);

//-----------------------------------------------------------------
// RTOS Macros
//-----------------------------------------------------------------
#define OS_PRINTF   rtos_services.printf

#endif

