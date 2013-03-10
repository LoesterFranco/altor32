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
#include "mem_map.h"

//-----------------------------------------------------------------
// main:
//-----------------------------------------------------------------
int main(void)
{
    unsigned short port_w1a = 0;
    unsigned short port_w1b = 0;
    unsigned short port_w2c = 0;

    unsigned short last_w1a = 0;
    unsigned short last_w1b = 0;
    unsigned short last_w2c = 0;

    // Setup printf to serial port
    printf_register(serial_putchar);

    GPIO_W1A_DIR = GPIO_DIR_ALL_INPUTS;
    GPIO_W1B_DIR = GPIO_DIR_ALL_INPUTS;
    GPIO_W2C_DIR = GPIO_DIR_ALL_INPUTS;

    printf("\n\nHello!\n");

    while (1)
    {
        port_w1a = GPIO_W1A_IN;
        port_w1b = GPIO_W1B_IN;
        port_w2c = GPIO_W2C_IN;

        if (last_w1a != port_w1a)
            printf("Port 1A = 0x%04x\n", port_w1a);

        if (last_w1b != port_w1b)
            printf("Port 1B = 0x%04x\n", port_w1b);

        if (last_w2c != port_w2c)
            printf("Port 2C = 0x%04x\n", port_w2c);

        last_w1a = port_w1a;
        last_w1b = port_w1b;
        last_w2c = port_w2c;
    }
}
