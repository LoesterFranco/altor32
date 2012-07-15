#ifndef __SPI_FLASH_H__
#define __SPI_FLASH_H__

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define SPIFLASH_PAGESIZE               (256)
#define SPIFLASH_BLOCKSIZE              (4 * 1024)
#define SPIFLASH_SECTORSIZE             (SPIFLASH_BLOCKSIZE)
#define SPIFLASH_SIZE                   (512 * 1024)    // 4Mbit
#define    SPIFLASH_FPGA_OFFSET         (0)
#define    SPIFLASH_FPGA_SIZE           (352 * 1024)
#define    SPIFLASH_APP_OFFSET          (SPIFLASH_FPGA_SIZE)
#define    SPIFLASH_APP_SIZE            (SPIFLASH_SIZE - SPIFLASH_APP_OFFSET)

//-----------------------------------------------------------------
// Prototypes:
//-----------------------------------------------------------------
int        spiflash_init(void);
int        spiflash_readblock(unsigned long address, unsigned char *buf, int length);
int        spiflash_writeblock(unsigned long address, unsigned char *buf, int length);
int        spiflash_eraseblock(unsigned long address);
int        spiflash_erasechip(void);

#endif // __SPI_FLASH_H__
