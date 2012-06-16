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
