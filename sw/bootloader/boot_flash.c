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
#include "assert.h"
#include "spi_flash.h"
#include "boot_flash.h"
#include "boot_header.h"

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define BOOTFLASH_BLOCK_SIZE        SPIFLASH_BLOCKSIZE

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static struct boot_header hdr;

//-------------------------------------------------------------
// bootflash:
//-------------------------------------------------------------
int bootflash(unsigned long target)
{        
    unsigned char *ptr = (unsigned char *)(target);
    unsigned int length;
    unsigned int pos = 0;

    // Load header
    spiflash_readblock(SPIFLASH_APP_OFFSET, (unsigned char*)&hdr, BOOT_HDR_SIZE);

    // Check header magic number
    if (hdr.magic != BOOT_HDR_MAGIC)
        return 0;

    // Load file to memory
    while (pos < hdr.file_length)
    {
        // Calculate count of data to load
        length = hdr.file_length - pos;
        if (length > BOOTFLASH_BLOCK_SIZE)
            length = BOOTFLASH_BLOCK_SIZE;

        // Load block of data into target
        spiflash_readblock(SPIFLASH_APP_OFFSET + pos, ptr, length);

        pos += length;
        ptr += length;
    }

    return 1;
}
