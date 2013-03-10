#ifndef __MEM_MAP_H__
#define __MEM_MAP_H__

//-----------------------------------------------------------------
// Defines:
//-----------------------------------------------------------------
#define INT_BASE            0x10000000
#define INT_APP_BASE        0x10002000
#define IO_BASE             0x12000000
#define EXT_IO_BASE         0x13000000

//-----------------------------------------------------------------
// Macros:
//-----------------------------------------------------------------
#define REG8                (volatile unsigned char*)
#define REG16               (volatile unsigned short*)
#define REG32               (volatile unsigned int*)

//-----------------------------------------------------------------
// Peripheral Base Addresses
//-----------------------------------------------------------------
#define UART_BASE           (IO_BASE + 0x000)
#define TIMER_BASE          (IO_BASE + 0x100)
#define INTR_BASE           (IO_BASE + 0x200)
#define SPI_FLASH_BASE      (IO_BASE + 0x300)

//-----------------------------------------------------------------
// Interrupts
//-----------------------------------------------------------------
#define IRQ_UART_RX             0
#define IRQ_TIMER_SYSTICK       1
#define IRQ_TIMER_HIRES         2

//-----------------------------------------------------------------
// Peripheral Registers
//-----------------------------------------------------------------

#define UART_USR            (*(REG32 (UART_BASE + 0x4)))
#define UART_UDR            (*(REG32 (UART_BASE + 0x8)))

#define TIMER_VAL           (*(REG32 (TIMER_BASE + 0x0)))
#define SYS_CLK_COUNT       (*(REG32 (TIMER_BASE + 0x4)))

#define IRQ_MASK            (*(REG32 (INTR_BASE + 0x00)))
#define IRQ_MASK_SET        (*(REG32 (INTR_BASE + 0x00)))
#define IRQ_MASK_CLR        (*(REG32 (INTR_BASE + 0x04)))
#define IRQ_STATUS          (*(REG32 (INTR_BASE + 0x08)))
    #define IRQ_SYSTICK         (IRQ_TIMER_SYSTICK)
    #define IRQ_UART_RX_AVAIL   (IRQ_UART_RX)
    #define IRQ_PIT             (IRQ_TIMER_HIRES)
    #define IRQ_SW              (3)    
    #define EXT_INT_OFFSET      (8)

#define SPI_PROM_CTRL        (*(REG32 (SPI_FLASH_BASE + 0x00)))
    #define SPI_PROM_CS         (1 << 0)
#define SPI_PROM_STAT        (*(REG32 (SPI_FLASH_BASE + 0x00)))
    #define SPI_PROM_BUSY       (1 << 0)
#define SPI_PROM_DATA        (*(REG32 (SPI_FLASH_BASE + 0x04)))

//-----------------------------------------------------------------
// Extended Peripherals
//-----------------------------------------------------------------

#define GPIO_DIR_OUTPUT         1
#define GPIO_DIR_INPUT          0
#define GPIO_DIR_ALL_OUTPUTS    0xFFFF
#define GPIO_DIR_ALL_INPUTS     0x0000

// GPIO Ports
#define GPIO_W1A_OUT        (*(REG32 (EXT_IO_BASE + 0x10)))
#define GPIO_W1A_IN         (*(REG32 (EXT_IO_BASE + 0x14)))
#define GPIO_W1A_DIR        (*(REG32 (EXT_IO_BASE + 0x1C)))

#define GPIO_W1B_OUT        (*(REG32 (EXT_IO_BASE + 0x20)))
#define GPIO_W1B_IN         (*(REG32 (EXT_IO_BASE + 0x24)))
#define GPIO_W1B_DIR        (*(REG32 (EXT_IO_BASE + 0x2C)))

#define GPIO_W2C_OUT        (*(REG32 (EXT_IO_BASE + 0x30)))
#define GPIO_W2C_IN         (*(REG32 (EXT_IO_BASE + 0x34)))
#define GPIO_W2C_DIR        (*(REG32 (EXT_IO_BASE + 0x3C)))

#endif 
