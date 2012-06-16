//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//                                     AltOR32 
//                         Alternative Lightweight OpenRisc 
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
// This file is part of AltOR32 OpenRisc Simulator.
//
// AltOR32 OpenRisc Simulator is free software; you can redistribute it and/or 
// modify it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// AltOR32 OpenRisc Simulator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with AltOR32 OpenRisc Simulator; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
#include "timer.h"
#include "serial.h"
#include "boot_serial.h"
#include "boot_flash.h"
#include "spi_flash.h"
#include "mem_map.h"

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define BOOT_TIMEOUT            10000
#define BOOT_FLASH_TARGET       INT_APP_BASE

//-----------------------------------------------------------------
// application_boot:
//-----------------------------------------------------------------
static application_boot(unsigned long addr)
{
    typedef int (*fnptr)(void);
    fnptr app_start;

	app_start = (fnptr)(addr);
	app_start();

	while (1) 
		;
}
//-----------------------------------------------------------------
// main:
//-----------------------------------------------------------------
int main(void)
{
    t_time tStart;
    int no_flash_boot = 0;

    serial_putstr("\nBootROM\n");

    // Initialise SPI Flash
    spiflash_init();

    do
    {
        serial_putstr("<I> Internal\n");
        serial_putstr("<E> External\n");
        serial_putstr("<A> PROM (App)\n");
        serial_putstr("<F> PROM (FPGA)\n");

        tStart = timer_now();
	    while (timer_diff(timer_now(), tStart) < BOOT_TIMEOUT || no_flash_boot == 1)
	    {
		    int ch = serial_getchar();
		    if (ch == 'I')
		    {
			    serial_putstr("Internal (BRAM) X-modem boot...\n");
			    boot_serial(INT_APP_BASE, 0);

                // Jump to application reset vector
                application_boot(INT_APP_BASE + 0x100);
		    }
		    else if (ch == 'E')
		    {
			    serial_putstr("External X-modem boot...\n");
			    boot_serial(EXT_BASE, 0);

                // Jump to application reset vector
                application_boot(EXT_BASE + 0x100);
		    }
		    else if (ch == 'A')
		    {
			    serial_putstr("PROM (App) X-modem flash...\n");
			    boot_serial(SPIFLASH_APP_OFFSET, 1);
                no_flash_boot = 1;
                continue;
		    }
		    else if (ch == 'F')
		    {
			    serial_putstr("PROM (FPGA) X-modem flash...\n");
			    boot_serial(SPIFLASH_FPGA_OFFSET, 1);
                no_flash_boot = 1;
                continue;
		    }
	    }

        serial_putstr("Boot from PROM (App)...\n");

        // Auto boot SPI PROM image if available
        if (bootflash(BOOT_FLASH_TARGET))
        {
	        // Normal boot
            application_boot(BOOT_FLASH_TARGET + 0x100);
        }
        // No image available, wait for X-modem image
        else
        {
            serial_putstr("No app image available in PROM\n");
            no_flash_boot = 1;
        }
    }
    while (1);
}
//-----------------------------------------------------------------
// assert_handler:
//-----------------------------------------------------------------
void assert_handler(const char * type, const char *reason, const char *file, int line)
{
    while (1);
}