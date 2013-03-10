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
#include "mem_map.h"
#include "serial.h"

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
#define UART_RX_AVAIL    (1<<0)
#define UART_TX_AVAIL    (1<<1)
#define UART_RX_FULL    (1<<2)
#define UART_TX_BUSY    (1<<3)
#define UART_RX_ERROR    (1<<4)

//-------------------------------------------------------------
// serial_init: 
//-------------------------------------------------------------
void serial_init (void)           
{      

}
//-------------------------------------------------------------
// serial_putchar: Write character to Serial Port (used by printf)
//-------------------------------------------------------------
int serial_putchar(char ch)   
{   
    if (ch == '\n')
        serial_putchar('\r');
    
    {
        register char  t1 asm ("r3") = ch;
        asm volatile ("\tl.nop\t%0" : : "K" (0x0004), "r" (t1));
    }

    UART_UDR = ch;
    while (UART_USR & UART_TX_BUSY);

    return 0;
}
//-------------------------------------------------------------
// serial_getchar: Read character from Serial Port  
//-------------------------------------------------------------
int serial_getchar (void)           
{     
    // Read character in from UART0 Recieve Buffer and return
    if (serial_haschar())
        return UART_UDR;
    else
        return -1;
}
//-------------------------------------------------------------
// serial_haschar:
//-------------------------------------------------------------
int serial_haschar()
{
    return (UART_USR & UART_RX_AVAIL);
}
//-------------------------------------------------------------
// serial_putstr:
//-------------------------------------------------------------
void serial_putstr(char *str)
{
    while (*str)
        serial_putchar(*str++);
}
//-------------------------------------------------------------
// serial_putnum:
//-------------------------------------------------------------
void serial_putnum( int n )
{
    char* cp;
    int negative;
    char outbuf[32];
    const char digits[] = "0123456789ABCDEF";
    unsigned long num;

   /* Check if number is negative                   */
    if (n < 0L) {
        negative = 1;
        num = -(n);
    }
    else{
        num = (n);
        negative = 0;
    }
   
    /* Build number (backwards) in outbuf            */
    cp = outbuf;
    do {
        *cp++ = digits[(int)(num % 10)];
    } while ((num /= 10) > 0);
    if (negative)
        *cp++ = '-';
    *cp-- = 0;
    
    while (cp >= outbuf)
        serial_putchar(*cp--);
}
