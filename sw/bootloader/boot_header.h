#ifndef __BOOT_HEADER_H__
#define __BOOT_HEADER_H__

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

#endif // __BOOT_HEADER_H__
