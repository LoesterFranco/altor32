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
#include "serial.h"
#include "boot_serial.h"
#include "xmodem.h"
#include "mem_map.h"
#include "spi_flash.h"

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define FLASH_SECTOR_SIZE		SPIFLASH_BLOCKSIZE

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static unsigned long xfer_offset = 0;
static unsigned long xfer_base;
static int xfer_flash;

//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
static int xmodem_write(unsigned char* buffer, int size);

static unsigned char _tmpbuf[128];

//-----------------------------------------------------------------
// boot_serial:
//-----------------------------------------------------------------
void boot_serial(unsigned long target, int flash)
{
    int res;

    // Load target memory address
    xfer_base = target;
    xfer_flash = flash;

    // Init X-Modem transfer
    xmodem_init(serial_putchar, serial_getchar);

    do
    {
        // Reset
        xfer_offset = xfer_base;

        res = xmodem_receive( xmodem_write );
    }
    while (res < 0);
}
//-----------------------------------------------------------------
// xmodem_write:
//-----------------------------------------------------------------
static int xmodem_write(unsigned char* buffer, int size)
{
    // Write to flash
    int i;
    int flush = 0;

    // Flush final block
    if (size == 0)
        flush = 1;

    // We are relying on the Flash sector size to be a multiple
    // of Xmodem transfer sizes (128 or 1024)...
    if (xfer_flash)
    {
        // Write block to SPI flash
        spiflash_writeblock(xfer_offset, buffer, size);

        // Increment end point to include new data
        xfer_offset += size;
    }
    else
    {
        // Write to memory 
        unsigned char *ptr = (unsigned char *)(xfer_offset);

        for (i=0;i<size;i++)
            *ptr++ = buffer[i];

        // Increment end point to include new data
        xfer_offset += size;
    }

    return 0;
}
