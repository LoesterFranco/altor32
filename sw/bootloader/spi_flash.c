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
#include "assert.h"
#include "mem_map.h"
#include "spi_flash.h"

//-------------------------------------------------------------
// Defines:
//-------------------------------------------------------------

// Chip select control
#define SPIFLASH_CS_HIGH		SPI_PROM_CTRL = SPI_PROM_CS
#define SPIFLASH_CS_LOW			SPI_PROM_CTRL = 0

// ID addresses
#define SPIFLASH_MAN_ADDR		0x00
#define SPIFLASH_DEV_ADDR		0x01

// Instructions
#define SPIFLASH_OP_WRSR		0x01
#define SPIFLASH_OP_PROGRAM		0x02
#define SPIFLASH_OP_READ		0x03
#define SPIFLASH_OP_RDSR		0x05
    #define SPIFLASH_STAT_BUSY		(1 << 0)
    #define SPIFLASH_STAT_WEL		(1 << 1)
    #define SPIFLASH_STAT_BP0		(1 << 2)
    #define SPIFLASH_STAT_BP1		(1 << 3)
    #define SPIFLASH_STAT_BP2		(1 << 4)
    #define SPIFLASH_STAT_BP3		(1 << 5)
    #define SPIFLASH_STAT_AAI		(1 << 6)
    #define SPIFLASH_STAT_BPL		(1 << 7)
#define SPIFLASH_OP_WREN		0x06
#define SPIFLASH_OP_ERASESECTOR	0x20
#define SPIFLASH_OP_ERASECHIP	0x60
#define SPIFLASH_OP_RDID		0x9F
#define SPIFLASH_OP_AAIP		0xAD

typedef enum
{
    SPI_FLASH_GENERIC,
    SPI_FLASH_SST25VF040B,
    SPI_FLASH_AT25DF041A
} tSpiDevice;

//-------------------------------------------------------------
// Locals:
//-------------------------------------------------------------
static tSpiDevice _device = SPI_FLASH_GENERIC;

//-------------------------------------------------------------
// spiflash_writebyte:
//-------------------------------------------------------------
static void spiflash_writebyte(unsigned char data)
{
    SPI_PROM_DATA = data;
    while (SPI_PROM_STAT & SPI_PROM_BUSY);
}
//-------------------------------------------------------------
// spiflash_readbyte:
//-------------------------------------------------------------
static unsigned char spiflash_readbyte(void)
{
    SPI_PROM_DATA = 0xFF;
    while (SPI_PROM_STAT & SPI_PROM_BUSY);
    return SPI_PROM_DATA;
}
//-------------------------------------------------------------
// spiflash_command:
//-------------------------------------------------------------
static void spiflash_command(unsigned char command, unsigned long address)
{
    spiflash_writebyte(command);
    spiflash_writebyte(address >> 16);
    spiflash_writebyte(address >> 8);
    spiflash_writebyte(address >> 0);
}
//-------------------------------------------------------------
// spiflash_readid:
//-------------------------------------------------------------
static unsigned char spiflash_readid(unsigned long address)
{
    unsigned long i;
    unsigned char id;

    SPIFLASH_CS_LOW;

    spiflash_writebyte(SPIFLASH_OP_RDID);
    for (i=0;i<=address;i++)
    {
        id = spiflash_readbyte();
    }

    SPIFLASH_CS_HIGH;

    return id;
}
//-------------------------------------------------------------
// spiflash_readstatus:
//-------------------------------------------------------------
static unsigned char spiflash_readstatus(void)
{
    unsigned char stat;

    SPIFLASH_CS_LOW;

    spiflash_writebyte(SPIFLASH_OP_RDSR);
    stat = spiflash_readbyte();

    SPIFLASH_CS_HIGH;

    return stat;
}
//-------------------------------------------------------------
// spiflash_writeenable:
//-------------------------------------------------------------
static void spiflash_writeenable(void)
{
    SPIFLASH_CS_LOW;
    spiflash_writebyte(SPIFLASH_OP_WREN);
    SPIFLASH_CS_HIGH;
}
//-------------------------------------------------------------
// spiflash_writestatus:
//-------------------------------------------------------------
static void spiflash_writestatus(unsigned char value)
{
    // Execute write enable command
    spiflash_writeenable();

    SPIFLASH_CS_LOW;
    spiflash_writebyte(SPIFLASH_OP_WRSR);
    spiflash_writebyte(value);
    SPIFLASH_CS_HIGH;
}
//-------------------------------------------------------------
// spiflash_programbyte:
//-------------------------------------------------------------
static void spiflash_programbyte(unsigned long address, unsigned char data)
{
    // Execute write enable command
    spiflash_writeenable();

    // Program a word at a specific address
    SPIFLASH_CS_LOW;
    spiflash_command(SPIFLASH_OP_PROGRAM, address);
    spiflash_writebyte(data);
    SPIFLASH_CS_HIGH;

    // Wait until operation completed
    while (spiflash_readstatus() & SPIFLASH_STAT_BUSY)
        ;
}
//-------------------------------------------------------------
// spiflash_programpage:
//-------------------------------------------------------------
static void spiflash_programpage(unsigned long address, unsigned char *data, unsigned int size)
{
    int i;

    // Execute write enable command
    spiflash_writeenable();

    // Program a word at a specific address
    SPIFLASH_CS_LOW;

    spiflash_command(SPIFLASH_OP_PROGRAM, address);

    for (i=0;i<size;i++)
        spiflash_writebyte(data[i]);

    SPIFLASH_CS_HIGH;

    // Wait until operation completed
    while (spiflash_readstatus() & SPIFLASH_STAT_BUSY)
        ;
}

//-------------------------------------------------------------
//						External API
//-------------------------------------------------------------

//-------------------------------------------------------------
// spiflash_init:
//-------------------------------------------------------------
int spiflash_init(void)
{
    int res;
    unsigned char id;

    // Do dummy reads first
    spiflash_readstatus();
    spiflash_readid(SPIFLASH_DEV_ADDR);

    // Check device ID
    switch ((id = spiflash_readid(SPIFLASH_MAN_ADDR)))
    {
        // Atmel
        case 0x1F:            
            id = spiflash_readid(SPIFLASH_DEV_ADDR);
            res = ( id == 0x44 );
            assert( res && "Unknown device ID" );
            _device = SPI_FLASH_AT25DF041A;
            break;
        // SST
        case 0xBF:
            id = spiflash_readid(SPIFLASH_DEV_ADDR);
            res = ( id == 0x25 );
            assert( res && "Unknown device ID" );
            _device = SPI_FLASH_SST25VF040B;
            break;
        default:
            res = 0;
            assert(res && "Unknown manufacturer ID");
            break;
    }

    // Enable device writes
    spiflash_writestatus(0);
    return res;
}
//-------------------------------------------------------------
// spiflash_readblock:
//-------------------------------------------------------------
int spiflash_readblock(unsigned long address, unsigned char *buf, int length)
{
    int i;

    SPIFLASH_CS_LOW;

    spiflash_command(SPIFLASH_OP_READ, address);

    for (i=0;i<length;i++)
        buf[i] = spiflash_readbyte();

    SPIFLASH_CS_HIGH;

    return 0;
}
//-------------------------------------------------------------
// spiflash_writeblock:
//-------------------------------------------------------------
int spiflash_writeblock(unsigned long address, unsigned char *buf, int length)
{
    int i, j;

    // Sector boundary? Erase sector
    if ((address & (SPIFLASH_SECTORSIZE - 1)) == 0)
        spiflash_eraseblock(address);    

    for (i=0;i<length;i+=SPIFLASH_PAGESIZE)
    {
        int size = length - i;

        if (size > SPIFLASH_PAGESIZE)
            size = SPIFLASH_PAGESIZE;

        // Byte program device
        if (_device == SPI_FLASH_SST25VF040B)
        {
            for (j=0;j<size;j++)
                spiflash_programbyte(address + j, buf[j]);
        }
        // Block program device
        else
            spiflash_programpage(address, buf, size);

        address += SPIFLASH_PAGESIZE;
        buf += SPIFLASH_PAGESIZE;
    }

    return 0;
}
//-------------------------------------------------------------
// spiflash_eraseblock:
//-------------------------------------------------------------
int spiflash_eraseblock(unsigned long address)
{
    // Enable write mode
    spiflash_writeenable();

    // Erase sector
    SPIFLASH_CS_LOW;
    spiflash_command(SPIFLASH_OP_ERASESECTOR, address);
    SPIFLASH_CS_HIGH;    

    // Wait until operation completed
    while (spiflash_readstatus() & SPIFLASH_STAT_BUSY)
        ;

    return 0;
}
//-------------------------------------------------------------
// spiflash_erasechip:
//-------------------------------------------------------------
int spiflash_erasechip(void)
{
    // Enable write mode
    spiflash_writeenable();

    // Erase chip
    SPIFLASH_CS_LOW;
    spiflash_writebyte(SPIFLASH_OP_ERASECHIP);
    SPIFLASH_CS_HIGH;

    // Wait until operation completed
    while (spiflash_readstatus() & SPIFLASH_STAT_BUSY)
        ;

    return 0;
}

