//-----------------------------------------------------------------
//                           AltOR32 
//              Alternative Lightweight OpenRisc 
//                     Ultra-Embedded.com
//                   Copyright 2011 - 2013
//
//               Email: admin@ultra-embedded.com
//
//                       License: LGPL
//
// If you would like a version with a different license for use 
// in commercial projects please contact the above email address 
// for more details.
//-----------------------------------------------------------------
//
// Copyright (C) 2011 - 2013 Ultra-Embedded.com
//
// This source file may be used and distributed without         
// restriction provided that this copyright statement is not    
// removed from the file and that any derivative work contains  
// the original copyright notice and the associated disclaimer. 
//
// This source file is free software; you can redistribute it   
// and/or modify it under the terms of the GNU Lesser General   
// Public License as published by the Free Software Foundation; 
// either version 2.1 of the License, or (at your option) any   
// later version.                                               
//
// This source is distributed in the hope that it will be       
// useful, but WITHOUT ANY WARRANTY; without even the implied   
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
// PURPOSE.  See the GNU Lesser General Public License for more 
// details.                                                     
//
// You should have received a copy of the GNU Lesser General    
// Public License along with this source; if not, write to the 
// Free Software Foundation, Inc., 59 Temple Place, Suite 330, 
// Boston, MA  02111-1307  USA
//-----------------------------------------------------------------
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
