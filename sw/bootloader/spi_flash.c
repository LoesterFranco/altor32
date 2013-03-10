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
#include "assert.h"
#include "mem_map.h"
#include "spi_flash.h"

#ifdef USE_SPI_FLASH
//-------------------------------------------------------------
// Defines:
//-------------------------------------------------------------

// Chip select control
#define SPIFLASH_CS_HIGH            SPI_PROM_CTRL = SPI_PROM_CS
#define SPIFLASH_CS_LOW             SPI_PROM_CTRL = 0

// ID addresses
#define SPIFLASH_MAN_ADDR           0x00
#define SPIFLASH_DEV_ADDR           0x01

// Instructions
#define SPIFLASH_OP_WRSR            0x01
#define SPIFLASH_OP_PROGRAM         0x02
#define SPIFLASH_OP_READ            0x03
#define SPIFLASH_OP_RDSR            0x05
    #define SPIFLASH_STAT_BUSY          (1 << 0)
    #define SPIFLASH_STAT_WEL           (1 << 1)
    #define SPIFLASH_STAT_BP0           (1 << 2)
    #define SPIFLASH_STAT_BP1           (1 << 3)
    #define SPIFLASH_STAT_BP2           (1 << 4)
    #define SPIFLASH_STAT_BP3           (1 << 5)
    #define SPIFLASH_STAT_AAI           (1 << 6)
    #define SPIFLASH_STAT_BPL           (1 << 7)
#define SPIFLASH_OP_WREN            0x06
#define SPIFLASH_OP_ERASESECTOR     0x20
#define SPIFLASH_OP_ERASESECTOR_NM  0xD8
#define SPIFLASH_OP_ERASECHIP       0x60
#define SPIFLASH_OP_RDID            0x9F
#define SPIFLASH_OP_AAIP            0xAD

//-------------------------------------------------------------
// Types:
//-------------------------------------------------------------
struct spi_flash_desc
{
    unsigned char    manufacturer_id;
    unsigned char    device_id;
    unsigned int     size_program;
    unsigned int     size_read;
    unsigned int     size_erase;
    unsigned char    command_erase;
    int              skip_write_status;
};

//-------------------------------------------------------------
// Tables:
//-------------------------------------------------------------
const struct spi_flash_desc _spi_devices[] = 
{
    /* Numonyx M25P80 8Mbit */
    [0] =
    {
        .manufacturer_id    = 0x20,
        .device_id          = 0x20,
        .size_program       = 256,
        .size_read          = 256,
        .size_erase         = (64 * 1024),
        .command_erase      = 0xD8,
        .skip_write_status  = 1
    },
    /* Atmel 4Mbit */
    [1] =
    {
        .manufacturer_id    = 0x1F,
        .device_id          = 0x44,
        .size_program       = 256,
        .size_read          = 256,
        .size_erase         = (4 * 1024),
        .command_erase      = 0x20,
        .skip_write_status  = 0
    },
    /* SST SST25VF040B 4Mbit */
    [2] =
    {
        .manufacturer_id    = 0xBF,
        .device_id          = 0x25,
        .size_program       = 1, /* byte program */
        .size_read          = 256,
        .size_erase         = (4 * 1024),
        .command_erase      = 0x20,
        .skip_write_status  = 0
    }
};

//-------------------------------------------------------------
// Locals:
//-------------------------------------------------------------
static struct spi_flash_desc *spi_dev;

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
// spiflash_readpage:
//-------------------------------------------------------------
static void spiflash_readpage(unsigned long address, unsigned char *buf, int length)
{
    int i;

    SPIFLASH_CS_LOW;
    spiflash_command(SPIFLASH_OP_READ, address);

    for (i=0;i<length;i++)
        buf[i] = spiflash_readbyte();

    SPIFLASH_CS_HIGH;
}

//-------------------------------------------------------------
//                        External API
//-------------------------------------------------------------

//-------------------------------------------------------------
// spiflash_init:
//-------------------------------------------------------------
int spiflash_init(void)
{
    int ok = 0;
    unsigned char id = 0;
    unsigned char man;
    int i;

    // Do dummy reads first
    spiflash_readstatus();
    spiflash_readid(SPIFLASH_DEV_ADDR);

    // Get manufacturer & device IDs
    man = spiflash_readid(SPIFLASH_MAN_ADDR);
    id = spiflash_readid(SPIFLASH_DEV_ADDR);

    // Find device details
    spi_dev = 0;
    for (i=0;i<(sizeof(_spi_devices) / sizeof(_spi_devices[0])); i++)
    {
        if (_spi_devices[i].manufacturer_id == man &&
            _spi_devices[i].device_id == id)
        {
            spi_dev = (struct spi_flash_desc*)&_spi_devices[i];
            ok = 1;
            break;
        }
    }

    // Enable device writes (not Numonyx)
    if (ok && !spi_dev->skip_write_status)
        spiflash_writestatus(0);

    return ok;
}
//-------------------------------------------------------------
// spiflash_readblock:
//-------------------------------------------------------------
int spiflash_readblock(unsigned long address, unsigned char *buf, int length)
{
    int i;

    for (i=0;i<length;)
    {
        int size = length - i;

        if (size > spi_dev->size_read)
            size = spi_dev->size_read;

        // Read block from flash
        spiflash_readpage(address, buf, size);

        address += size;
        buf     += size;
        i       += size;
    }

    return 0;
}
//-------------------------------------------------------------
// spiflash_writeblock:
//-------------------------------------------------------------
int spiflash_writeblock(unsigned long address, unsigned char *buf, int length)
{
    int i;

    // Sector boundary? Erase sector
    if ((address & (spi_dev->size_erase - 1)) == 0)
        spiflash_eraseblock(address);    

    for (i=0;i<length;)
    {
        int size = length - i;

        if (size > spi_dev->size_program)
            size = spi_dev->size_program;

        // Write block to flash (can be a single byte)
        spiflash_programpage(address, buf, size);

        address += size;
        buf     += size;
        i       += size;
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
    spiflash_command(spi_dev->command_erase, address);
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
#endif
