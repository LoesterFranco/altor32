#include "mem_map.h"
#include "serial.h"

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
#define UART_RX_AVAIL	(1<<0)
#define UART_TX_AVAIL	(1<<1)
#define UART_RX_FULL	(1<<2)
#define UART_TX_BUSY	(1<<3)
#define UART_RX_ERROR	(1<<4)

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

    // Use special simulator NOP instruction to output console 
    // trace on the simulator.
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
