#ifndef __IRQ_H__
#define __IRQ_H__

//-----------------------------------------------------------------
// Types
//-----------------------------------------------------------------
typedef void (*fn_irq_func)(int irq_number);

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------
void irq_register(int interrupt, fn_irq_func func);
void irq_handler(unsigned int interrupts);
void irq_enable(int interrupt);
void irq_disable(int interrupt);
void irq_acknowledge(int interrupt);

#endif
