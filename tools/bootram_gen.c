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
/* 
 * Derived from ram_image.c by Steve Rhoads 11/7/05 
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include <unistd.h>
#include <arpa/inet.h>

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
// we have (up to) 8 blocks composed by 4 RAMB16_S9 instance (one per byte)
// each RAMB have 64 hex rows -> max=8*4*64
#define RAM_BLOCKS (8)
#define RAM_SPLIT (4)
#define RAM_ROWS (64)
#define RAM_ROWS_TOTAL (RAM_BLOCKS*RAM_SPLIT*RAM_ROWS)
#define RAM_DWORDPERROW (8)

//-----------------------------------------------------------------
// load_file:
//-----------------------------------------------------------------
static unsigned char *load_file(char *filename, unsigned int *pLength)
{
    FILE *f = fopen(filename, "rb");
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
            // Read file data in
            int len = fread(buf, 1, size, f);
            assert(len == size);
            fclose(f);

            *pLength = size;
            return buf;
        }
        else
        {
            fclose(f);
            fprintf(stderr, "Could not allocate memory %d\n", size);
            return NULL;
        }
    }
    else
    {
        fprintf(stderr, "Could not open file %s\n", filename);
        return NULL;
    }
}
//-----------------------------------------------------------------
// main:
//-----------------------------------------------------------------
int main(int argc, char *argv[])
{
    int c;
    char filename[1024];
    char outputfile[1024];
    char templatefile[1024];
    FILE *file;
    int i, iposinrow, iblock, irowinsplit, index;
    char *buf, *ptr, *ptr_list[RAM_ROWS_TOTAL], text[80];
    unsigned int size = 0;
    unsigned int *code;
    unsigned int code_size = 0;

    filename[0] = 0;
    outputfile[0] = 0;
    templatefile[0] = 0;

    while ((c = getopt(argc, argv, "n:f:o:t:")) != EOF)
    {
        switch (c)
        {
        case 'f':
            strcpy(filename, optarg);
            break;
        case 'o':
            strcpy(outputfile, optarg);
            break;
        case 't':
            strcpy(templatefile, optarg);
            break;
        }
    }

    if (filename[0] == '\0' || outputfile[0] == '\0' || templatefile[0] == '\0')
    {
        fprintf(stderr, "Options:\n");
        fprintf(stderr, " -f inputFile (binary file)\n");
        fprintf(stderr, " -o outputFile (VHDL)\n");
        fprintf(stderr, " -t templateFile (VHDL template)\n");
        return 1;
    }

    // Load binary file
    code = (unsigned int*)load_file(filename, &code_size);
    if (!code)
        return -1;

    // Load vhdl template file
    buf = load_file(templatefile, &size);
    if (!buf)
    {
        free(code);
        return -1;
    }

    // Find 'INIT_00 => X"' - start at buf, then seek next occurence
    ptr = buf;
    for(i = 0; i < RAM_ROWS_TOTAL; ++i)
    {
        sprintf(text, "INIT_%2.2X => X\"", i % RAM_ROWS);
        ptr = strstr(ptr, text);
        if(ptr == NULL)
        {
            fprintf(stderr, "ERROR: Can't find '%s', block %d, instance %d in '%s'!\n",
                            text, (i/(RAM_SPLIT*RAM_ROWS)),
                            (i%(RAM_SPLIT*RAM_ROWS))/RAM_ROWS, templatefile);

            free(code);
            free(buf);
            return -1;
        }
        ptr_list[i] = ptr + strlen(text);
    }

    // Modify vhdl source code
    // (start filling from end of line)
    iposinrow = RAM_DWORDPERROW*8-2;
    iblock = 0;
    irowinsplit = 0;
    for(i = 0; i < (code_size/4); ++i)
    {
        sprintf(text, "%8.8x", ntohl(code[i]));
        index = iblock*RAM_ROWS*RAM_SPLIT+irowinsplit; 

        ptr_list[index][iposinrow]              = text[0];
        ptr_list[index][iposinrow+1]            = text[1];
        ptr_list[index+RAM_ROWS][iposinrow]     = text[2];
        ptr_list[index+RAM_ROWS][iposinrow+1]   = text[3];
        ptr_list[index+RAM_ROWS*2][iposinrow]   = text[4];
        ptr_list[index+RAM_ROWS*2][iposinrow+1] = text[5];
        ptr_list[index+RAM_ROWS*3][iposinrow]   = text[6];
        ptr_list[index+RAM_ROWS*3][iposinrow+1] = text[7];
        iposinrow -= 2;
        if(iposinrow < 0)
        { 
            iposinrow = RAM_DWORDPERROW*8-2; // reset row
            irowinsplit++;
            if (irowinsplit>RAM_ROWS-1)
            { 
                irowinsplit = 0;
                iblock++;
            }
        } 
    }

    // Write output file
    file = fopen(outputfile, "wb");
    if(file == NULL)
    {
        fprintf(stderr, "Can't write '%s'!\n", outputfile);
        free(code);
        free(buf);
        return -1;
    }
    fwrite(buf, 1, size, file);
    fclose(file);

    free(buf);
    free(code);
    return 0;
}
