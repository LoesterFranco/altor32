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
#include <string.h>
#include <assert.h>
#include "mem_map.h"
#include "irq.h"

//-----------------------------------------------------------------
// Defines
//-----------------------------------------------------------------
#define IRQ_INTERRUPTS        16

//-----------------------------------------------------------------
// Locals 
//-----------------------------------------------------------------
static fn_irq_func irq_func[IRQ_INTERRUPTS];

//-----------------------------------------------------------------
// irq_register 
//-----------------------------------------------------------------
void irq_register(int interrupt, fn_irq_func func)
{
    assert(interrupt < IRQ_INTERRUPTS);
    assert(irq_func[interrupt] == NULL);
    assert(func != NULL);

    irq_func[interrupt] = func;
}
//-----------------------------------------------------------------
// irq_handler 
//-----------------------------------------------------------------
void irq_handler(unsigned int interrupts)
{
    // Skip interrupt 0 (SYSTICK)
    int irq = 1;

    // Process all pending interrupts
    while (interrupts && irq < IRQ_INTERRUPTS)
    {
        if (interrupts & (1 << irq))
        {
            // Check that this interrupt is enabled!
            assert(IRQ_MASK & (1 << irq));

            // Call interrupt function
            assert(irq_func[irq] != NULL);
            irq_func[irq](irq);

            // Acknowledge (reset) interrupt
            IRQ_STATUS = (1 << irq);

            // Mark interrupt as serviced
            interrupts &= ~(1 << irq);
        }

        irq++;
    }
}
//-----------------------------------------------------------------
// irq_enable 
//-----------------------------------------------------------------
void irq_enable(int interrupt)
{
    IRQ_MASK_SET = (1 << interrupt);
}
//-----------------------------------------------------------------
// irq_disable 
//-----------------------------------------------------------------
void irq_disable(int interrupt)
{
    IRQ_MASK_CLR = (1 << interrupt);
}
//-----------------------------------------------------------------
// irq_acknowledge 
//-----------------------------------------------------------------
void irq_acknowledge(int interrupt)
{
    IRQ_STATUS = (1 << interrupt);
}
