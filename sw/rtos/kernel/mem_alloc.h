#ifndef __MEM_ALLOC_H__
#define __MEM_ALLOC_H__

//-----------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------

// Initialise RTOS memory allocator
void        rtos_mem_init( void *heap, unsigned len );

// 'malloc' function (thread safe)
void*       rtos_mem_alloc( unsigned size );

// 'free' function (thread safe)
void        rtos_mem_free( void *ptr );

// 'calloc' function (thread safe)
void*       rtos_mem_calloc( unsigned size );

// Find the size of the largest free block
unsigned    rtos_mem_size_largest(void);

// Find the total free space
unsigned    rtos_mem_size_free(void);

#endif

