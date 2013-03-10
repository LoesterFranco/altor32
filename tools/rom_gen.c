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

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// Types:
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// main:
//-----------------------------------------------------------------
int main(int argc, char *argv[])
{
    int c;
    FILE *f;
    char filename[256];
    char signalname[256];
    int address_increment = 4;
    int help = 0;

    filename[0] = 0;
    strcpy(signalname, "data_o  <=");

    while ((c = getopt(argc, argv, "hf:s:i:")) != EOF)
    {
        switch (c)
        {
            case 'h':
                help = 1;
                break;
            case 'f':
                strcpy(filename, optarg);
                break;
            case 's':
                strcpy(signalname, optarg);
                break;
            case 'i':
                address_increment = strtoul(optarg, NULL, 0);
                break;
        }
    }

    if (filename[0] == '\0' || help)
    {
        fprintf(stderr, "Options:\n");
        fprintf(stderr, " -f inputFile\n");
        fprintf(stderr, " -s signalName\n");
        fprintf(stderr, " -i addressIncrement\n");
        return help ? 0 : 1;
    }

    f = fopen(filename, "rb");
    if (f)
    {
        int i;
        unsigned int size;
        unsigned int words;
        unsigned char buf;
        unsigned int data;

        // Get size
        fseek(f, 0, SEEK_END);
        size = ftell(f);
        rewind(f);

        // Round up to number of words
        words = (size + 3) / 4;

        for (i=0;i<words;i++)
        {
            fread(&buf, 1, 1, f);
            data = buf;
            data <<= 8;
            fread(&buf, 1, 1, f);
            data |= buf;
            data <<= 8;
            fread(&buf, 1, 1, f);
            data |= buf;
            data <<= 8;
            fread(&buf, 1, 1, f);
            data |= buf;

            printf("    %d: %s 32'h%08x;\n", i*address_increment, signalname, data);
        }
    
        fclose(f);
        return 0;
    }
    else
    {
        fprintf(stderr, "Could not open file %s\n", filename);
        return 1;
    }
}

