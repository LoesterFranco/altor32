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
#include "serial.h"
#include "printf.h"
#include "assert.h"
#include "kernel/rtos.h"

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define RTOS_MEM_SIZE       (4096)
#define APP_STACK_SIZE      (256)

//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
extern void app_func(void *arg);
static void idle_func(void);
static void thread1_func(void *arg);
static void thread2_func(void *arg);

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static unsigned char rtos_heap[RTOS_MEM_SIZE];

//-----------------------------------------------------------------
// main:
//-----------------------------------------------------------------
int main(void)
{
    printf_register(serial_putchar);
    printf("\n\nRunning\n");

    // Initialise RTOS
    rtos_init();

    // Register system specific functions
    rtos_services.printf = printf;
    rtos_services.idle = idle_func;

    // RTOS heap init
    rtos_heap_init(rtos_heap, RTOS_MEM_SIZE);

    // Add threads
    rtos_thread_create("THREAD1", THREAD_MAX_PRIO - 1, thread1_func, NULL, APP_STACK_SIZE);
    rtos_thread_create("THREAD2", THREAD_MAX_PRIO - 2, thread2_func, NULL, APP_STACK_SIZE);

    // Start RTOS
    printf("Starting RTOS...\n");
    thread_kernel_run();

    return 0;
} 
//-----------------------------------------------------------------
// thread1_func:
//-----------------------------------------------------------------
static void thread1_func(void *arg)
{
    int idx = 0;

    while (1)
    {
        printf("thread1\n");
        thread_sleep(10);

        if (idx++ == 5)
        {
            idx = 0;
            thread_dump_list();
        }
    }
}
//-----------------------------------------------------------------
// thread2_func:
//-----------------------------------------------------------------
static void thread2_func(void *arg)
{
    while (1)
    {
        printf("thread2\n");
        thread_sleep(1);
    }
}
//-----------------------------------------------------------------
// idle_func:
//-----------------------------------------------------------------
static void idle_func(void)
{

}
//-----------------------------------------------------------------
// assert_handler:
//-----------------------------------------------------------------
void assert_handler(const char * type, const char *reason, const char *file, int line)
{
    printf("[%s]: %s %s:%d\n", type, reason, file, line);
    while (1);
}
