#ifndef __CPU_INTERRUPTS_H__
#define __CPU_INTERRUPTS_H__

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------
#define CPU_MAX_INTERRUPTS            32

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Register interrupt handler with interrupt/exception
void            cpu_int_register(int interrupt, void (*func)(int interrupt));

// Enable interrupt/exception
void            cpu_int_enable(int interrupt);

// Disable interrupt/exception
void            cpu_int_disable(int interrupt);

// Acknowledge interrupt source
void            cpu_int_acknowledge(int interrupt);

// Put CPU into sleep mode & wait for interrupts
void            cpu_wfi_sleep(void);

#endif    // __CPU_INTERRUPTS_H__

