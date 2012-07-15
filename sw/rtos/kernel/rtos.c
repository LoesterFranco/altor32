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

//-----------------------------------------------------------------
// Globals:
//-----------------------------------------------------------------
struct sRtosServices    rtos_services;

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static int init_done = 0;

//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
static int  platform_printf(const char* ctrl1, ...);
static void platform_idle(void);
static void platform_reboot(void);

//-----------------------------------------------------------------
// rtos_init: Initialise RTOS (should be first RTOS function called)
//-----------------------------------------------------------------
void rtos_init(void)
{
    // Disable interrupts
    critical_start();

    // Initialise interrupt threads services
#ifdef INCLUDE_INTERRUPTS
    interrupts_init();
#endif

    // Setup the RTOS
    thread_kernel_init();

    // Initialise platform services
    rtos_services.printf = platform_printf;
    rtos_services.idle = platform_idle;
    rtos_services.reboot = platform_reboot;

    init_done = 1;
}
//-----------------------------------------------------------------
// rtos_start: Start RTOS with init task
//-----------------------------------------------------------------
#ifdef INCLUDE_RTOS_MALLOC
void rtos_start(void (*init_func)(void *arg), void *arg, int pri, unsigned int stack_size)
{
    OS_ASSERT(init_done);

    // Create init thread
    rtos_thread_create("INIT", pri, init_func, arg, stack_size);

    // Start kernel
    thread_kernel_run();

    // We should never reach here!
    OS_PANIC("OS EXIT!");
}
#endif
//-----------------------------------------------------------------
// platform_reboot: Default reboot function (none - blocks forever)
//-----------------------------------------------------------------
static void platform_reboot(void)
{
    while (1);
}
//-----------------------------------------------------------------
// platform_idle: Default idle function (no action)
//-----------------------------------------------------------------
static void platform_idle(void)
{
    // Do nothings
}
//-----------------------------------------------------------------
// platform_printf: Default printf function (no action)
//-----------------------------------------------------------------
static int platform_printf(const char* ctrl1, ...)
{
    // Do nothing
    return 0;
}

//-----------------------------------------------------------------
// Dynamic RTOS item allocation
//-----------------------------------------------------------------
#ifdef INCLUDE_RTOS_MALLOC

//-----------------------------------------------------------------
// rtos_heap_init: RTOS heap init - only required if dynamic RTOS
// object allocation used
//-----------------------------------------------------------------
void rtos_heap_init(unsigned char *heap, unsigned int size)
{
    rtos_mem_init(heap, size);
}
//-----------------------------------------------------------------
// rtos_thread_create: Allocate & initialise thread
//-----------------------------------------------------------------
struct thread* rtos_thread_create(char *name, int pri, void (*f)(void *), void *arg, unsigned int stack_size)
{
    struct thread* thread = (struct thread*)rtos_mem_alloc(sizeof(struct thread));
    if (thread)
    {
        unsigned long *stack = rtos_mem_alloc(stack_size * sizeof(unsigned long));
        if (stack)
        {
            thread_init(thread, name, pri, f, arg, stack, stack_size);
            return thread;
        }
        else
            rtos_mem_free(thread);
    }

    return 0;
}
//-----------------------------------------------------------------
// rtos_mutex_create: Allocate & initialise mutex
//-----------------------------------------------------------------
struct mutex* rtos_mutex_create(void)
{
#ifdef INCLUDE_MUTEX
    struct mutex* mtx = (struct mutex*)rtos_mem_alloc(sizeof(struct mutex));
    if (mtx)
        mutex_init(mtx);

    return mtx;
#else
    return 0;
#endif
}
//-----------------------------------------------------------------
// rtos_semaphore_create: Allocate & initialise semaphore
//-----------------------------------------------------------------
struct semaphore* rtos_semaphore_create(int initial)
{
#ifdef INCLUDE_SEMAPHORE
    struct semaphore* sema = (struct semaphore*)rtos_mem_alloc(sizeof(struct semaphore));
    if (sema)
        semaphore_init(sema, initial);

    return sema;
#else
    return 0;
#endif
}
//-----------------------------------------------------------------
// rtos_mailbox_create: Allocate & initialise mailbox
//-----------------------------------------------------------------
struct mailbox* rtos_mailbox_create(void)
{
#ifdef INCLUDE_MAILBOX
    struct mailbox* mail = (struct mailbox*)rtos_mem_alloc(sizeof(struct mailbox));
    if (mail)
        mailbox_init(mail);

    return mail;
#else
    return 0;
#endif
}
//-----------------------------------------------------------------
// rtos_lock_create: Allocate & initialise lock
//-----------------------------------------------------------------
struct lock* rtos_lock_create(void)
{
#ifdef INCLUDE_RECURSIVE_LOCK
    struct lock* lock = (struct lock*)rtos_mem_alloc(sizeof(struct lock));
    if (lock)
        lock_init(lock);

    return lock;
#else
    return 0;
#endif
}
//-----------------------------------------------------------------
// rtos_thread_destroy:
//-----------------------------------------------------------------
void rtos_thread_destroy(struct thread* thread)
{
    // Kill thread
    if (thread && thread_kill(thread))
    {
        // Free stack (thread must have been created using rtos_thread_create()
        // otherwise this might not be from the heap)
        rtos_mem_free((void*)thread->tcb.StackAlloc);

        // Free thread structure itself
        rtos_mem_free(thread);
    }
}
//-----------------------------------------------------------------
// rtos_mutex_destroy:
//-----------------------------------------------------------------
void rtos_mutex_destroy(struct mutex* mtx)
{
    if (mtx)
        rtos_mem_free(mtx);
}
//-----------------------------------------------------------------
// rtos_semaphore_destroy:
//-----------------------------------------------------------------
void rtos_semaphore_destroy(struct semaphore* sema)
{
    if (sema)
        rtos_mem_free(sema);
}
//-----------------------------------------------------------------
// rtos_mailbox_destroy:
//-----------------------------------------------------------------
void rtos_mailbox_destroy(struct mailbox* mailbox)
{
    if (mailbox)
        rtos_mem_free(mailbox);
}
//-----------------------------------------------------------------
// rtos_lock_destroy:
//-----------------------------------------------------------------
void rtos_lock_destroy(struct lock* lock)
{
    if (lock)
        rtos_mem_free(lock);
}
#endif
