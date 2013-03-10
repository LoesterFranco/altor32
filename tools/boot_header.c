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
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include <unistd.h>
#include <arpa/inet.h>

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define BOOT_HDR_SIZE           sizeof(struct boot_header)
#define BOOT_HDR_MAGIC          0xb00710ad

//-----------------------------------------------------------------
// Types:
//-----------------------------------------------------------------
struct boot_header
{
    unsigned int jmp_code[2];
    unsigned int magic;
    unsigned int file_length;
};

//-----------------------------------------------------------------
// main:
//-----------------------------------------------------------------
int main(int argc, char *argv[])
{
    int c;
    FILE *f;
    char filename[256];
    char outputfile[256];

    filename[0] = 0;

    while ((c = getopt(argc, argv, "f:o:")) != EOF)
    {
        switch (c)
        {
            case 'f':
                strcpy(filename, optarg);
                break;
            case 'o':
                strcpy(outputfile, optarg);
                break;
        }
    }

    if (filename[0] == '\0')
    {
        fprintf(stderr, "Options:\n");
        fprintf(stderr, " -f inputFile\n");
        fprintf(stderr, " -o outputFile\n");
        return 1;
    }

    f = fopen(filename, "rb");
    if (f)
    {
        unsigned int size;
        unsigned char *buf;

        // Get size
        fseek(f, 0, SEEK_END);
        size = ftell(f);
        rewind(f);

        buf = (unsigned char*)malloc(size);
        if (buf)
        {
            struct boot_header *hdr;
            FILE *fout;

            // Read file data in
            int len = fread(buf, 1, size, f);
            assert(len == size);
            fclose(f);

            hdr = (struct boot_header *)buf;

            // Only modify image if boot magic flag found
            if (ntohl(hdr->magic) == BOOT_HDR_MAGIC)
            {
                hdr->file_length = htonl(size);
            }

            // Output file
            fout = fopen(outputfile, "wb");
            if (fout)
            {
                // Write data
                fwrite(buf, 1, size, fout);
                fclose(fout);
            }
            else
            {
                fprintf(stderr, "Could not open file %s for writing\n", outputfile);
                free(buf);
                return 1;
            }            

            free(buf);
            return 0;
        }
        else
        {
            fclose(f);
            fprintf(stderr, "Could not allocate memory %d\n", size);
            return 1;
        }
    }
    else
    {
        fprintf(stderr, "Could not open file %s\n", filename);
        return 1;
    }
}
