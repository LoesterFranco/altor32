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
#include "kernel/rtos.h"
#include "cpu_interrupts.h"
#include "irq.h"

//-----------------------------------------------------------------
// cpu_int_register:
//-----------------------------------------------------------------
void cpu_int_register(int interrupt, void (*func)(int interrupt))
{
    irq_register(interrupt, func);
}
//-----------------------------------------------------------------
// cpu_int_enable:
//-----------------------------------------------------------------
void cpu_int_enable(int interrupt)
{
    irq_enable(interrupt);    
}
//-----------------------------------------------------------------
// cpu_int_disable:
//-----------------------------------------------------------------
void cpu_int_disable(int interrupt)
{
    irq_disable(interrupt);
}
//-----------------------------------------------------------------
// cpu_int_acknowledge:
//-----------------------------------------------------------------
void cpu_int_acknowledge(int interrupt)
{
    irq_acknowledge(interrupt);
}
//-----------------------------------------------------------------
// cpu_wfi_sleep:
//-----------------------------------------------------------------
void cpu_wfi_sleep(void)
{
    // Not supported
}
