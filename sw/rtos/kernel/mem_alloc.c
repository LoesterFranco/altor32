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
#include "rtos.h"
#include "mem_alloc.h"

//-----------------------------------------------------------------
// Based on code from a malloc/free implementation from:
// http://www.flipcode.com/archives/Simple_Malloc_Free_Functions.shtml
//-----------------------------------------------------------------
#ifdef INCLUDE_RTOS_MALLOC

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define MARKER_CHECKWORD        0xfedebace

// Round up to the next 4 byte boundary
#define ROUNDUP_4BYTES(a)       ((((a) + 3) >> 2) << 2)
#define USED                    1

//-----------------------------------------------------------------
// Types:
//-----------------------------------------------------------------
struct MemBlock
{
    unsigned size;
};

//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
static struct MemBlock* compact_blocks( struct MemBlock *p, unsigned nsize );

//-----------------------------------------------------------------
// Locals:
//-----------------------------------------------------------------
static struct MemBlock* MemFree = 0;
static struct MemBlock* MemHeap = 0;
static int              MemAllocInit = 0;

//-----------------------------------------------------------------
// rtos_mem_init: Initialise RTOS memory allocator.
// 'heap' is the pointer to memory used for heap, 'len' is in bytes.
//-----------------------------------------------------------------
void rtos_mem_init( void *heap, unsigned len )
{
    struct MemBlock *end;

    OS_ASSERT(!MemAllocInit);

    // Round up to next word boundary
    len = ROUNDUP_4BYTES(len);

    // Free pointer is start of heap
    MemFree = MemHeap = (struct MemBlock *) heap;

    MemFree->size = MemHeap->size = len - sizeof(struct MemBlock);

    // Skip to end point
    end = (struct MemBlock*)(((char *)heap) + len - sizeof(struct MemBlock));

    // Mark last node as NULL
    end->size = 0;

    // Memory manager initialised
    MemAllocInit = 1;
}
//-----------------------------------------------------------------
// rtos_mem_alloc: 'malloc' function (thread safe)
//-----------------------------------------------------------------
void* rtos_mem_alloc( unsigned size )
{
    unsigned fsize;
    struct MemBlock *p;
    int l;
#ifdef RTOS_MALLOC_ENDMARKER
    unsigned int *e = 0;
#endif

    OS_ASSERT(MemAllocInit);

    if( size == 0 )
        return 0;

    // Round up to next word boundary including extra space for size data
    size = ROUNDUP_4BYTES(size + sizeof(struct MemBlock));

#ifdef RTOS_MALLOC_ENDMARKER
    // Additional space for end marker check word
    size += 4;
#endif

    l = critical_start();

    // Not enough space?
    if( MemFree == 0 || size > MemFree->size )
    {
        // Try running compact_blocks to group together free memory.
        // NOTE: This never returns anything other than NULL if there
        // is not the free space.
        MemFree = compact_blocks( MemHeap, size );

        // No memory free?
        if( MemFree == 0 )
        {
            critical_end(l);
            return 0;
        }
    }

    p = MemFree;

#ifdef RTOS_MALLOC_ENDMARKER
    // Calculate end marker address (1 word back from size)
    e = (unsigned int*)(((unsigned int)p) + size - 4);

    // Set end marker checkword
    *e = MARKER_CHECKWORD;
#endif

    fsize = MemFree->size;

    // Free block is larger than requested size & block allocation node
    if( fsize >= size + sizeof(struct MemBlock) )
    {
        // Move free pointer onto end of this block
        MemFree = (struct MemBlock *)( (unsigned)p + size );

        // ... now setup free space remaining
        MemFree->size = fsize - size;
    }
    // Free block large enough for data but not for extra for block
    // allocation now. Set the free space to 0.
    else
    {
        MemFree = 0;
        size = fsize;
    }

    // Mark block as used (LSB is not used for size as round-up)
    p->size = size | USED;
#ifdef RTOS_MALLOC_ENDMARKER
    *e = MARKER_CHECKWORD;
#endif

    critical_end(l);

    return (void *)( (unsigned)p + sizeof(struct MemBlock) );
}
//-----------------------------------------------------------------
// rtos_mem_free: 'free' function (thread safe)
//-----------------------------------------------------------------
void rtos_mem_free( void *ptr )
{
    int l = critical_start();

    OS_ASSERT(MemAllocInit);

    if( ptr )
    {
        // Step back from pointer to find block address
        struct MemBlock *p = (struct MemBlock *)( (unsigned)ptr - sizeof(struct MemBlock) );

#ifdef RTOS_MALLOC_ENDMARKER
        // Calculate end marker address (1 word back from size)
        unsigned int *e = (unsigned int*)(((unsigned int)p) + (p->size & ~USED) - 4);

        // Verify end marker is correct
        OS_ASSERT(*e == MARKER_CHECKWORD);

        // Reset end marker
        *e = ~MARKER_CHECKWORD;
#endif

        // Mark block as un-used
        p->size &= ~USED;
    }

    critical_end(l);
}
//-----------------------------------------------------------------
// rtos_mem_calloc: 'calloc' function (thread safe)
//-----------------------------------------------------------------
void* rtos_mem_calloc( unsigned size )
{
    void *p = rtos_mem_alloc(size);
    if (p)
    {
        unsigned i;
        unsigned int *ptr = (unsigned int *)p;
        
        // Removed dependency on memset
        for (i=0;i<size;i++)
            *ptr++ = 0;
    }
    return p;
}
//-----------------------------------------------------------------
// compact_blocks: Find a large enough free block on the heap
// Args: p = heap, nsize = requested block size
// Returns: Pointer to free block if large enough one found.
//-----------------------------------------------------------------
static struct MemBlock* compact_blocks( struct MemBlock *p, unsigned nsize )
{
    unsigned bsize, psize;
    struct MemBlock *best;

    best = p;
    bsize = 0;

    // While not end of heap
    while( psize = p->size, psize )
    {
        // Is block allocated
        if( psize & USED )
        {
            // If we have previously found some free blocks
            if( bsize != 0 )
            {
                // Set size of block to new total free size
                // NOTE: This has the effect of compacting free space
                // into larger blocks even if this block is not big enough.
                best->size = bsize;

                // Is free space big enough for requested ammount
                if( bsize >= nsize )
                    return best;
            }

            // Reset free space counter
            bsize = 0;

            // Skip to the start of the next block
            best = p = (struct MemBlock *)( (unsigned)p + (psize & ~USED) );
        }
        // Free block
        else
        {
            // Add size to running total of contiguous free space
            bsize += psize;

            // Find next block pointer
            p = (struct MemBlock *)( (unsigned)p + psize );
        }
    }

    if( bsize != 0 )
    {
        // Set size of block to new total free size
        // NOTE: This has the effect of compacting free space
        // into larger blocks even if this block is not big enough.
        best->size = bsize;

        // Is free space big enough for requested ammount
        if( bsize >= nsize )
            return best;
    }

    return 0;
}
//-----------------------------------------------------------------
// rtos_mem_size_largest: Find the size of the largest free block
//-----------------------------------------------------------------
unsigned rtos_mem_size_largest(void)
{
    unsigned psize, largest;
    struct MemBlock *p = MemHeap;

    int l = critical_start();

    largest = 0;

    // Run the memory compactor first
    compact_blocks( MemHeap, (unsigned)-1);

    // While not end of heap
    while( psize = p->size, psize )
    {
        // Is block allocated
        if( psize & USED )
        {
            // Skip to the start of the next block
            p = (struct MemBlock *)( (unsigned)p + (psize & ~USED) );
        }
        // Free block
        else
        {
            if (psize > largest)
                largest = psize;

            // Find next block pointer
            p = (struct MemBlock *)( (unsigned)p + psize );
        }
    }

    critical_end(l);

    return largest;
}
//-----------------------------------------------------------------
// rtos_mem_size_free: Find the total free space
//-----------------------------------------------------------------
unsigned rtos_mem_size_free(void)
{
    unsigned psize, total;
    struct MemBlock *p = MemHeap;

    int l = critical_start();

    total = 0;

    // Run the memory compactor first
    compact_blocks( MemHeap, (unsigned)-1);

    // While not end of heap
    while( psize = p->size, psize )
    {
        // Is block allocated
        if( psize & USED )
        {
            // Skip to the start of the next block
            p = (struct MemBlock *)( (unsigned)p + (psize & ~USED) );
        }
        // Free block
        else
        {
            total += psize;

            // Find next block pointer
            p = (struct MemBlock *)( (unsigned)p + psize );
        }
    }

    critical_end(l);

    return total;
}
#endif
