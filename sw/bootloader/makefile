###############################################################################
## Makefile
###############################################################################

# Tools
CC_PREFIX   = or32-elf
CC          = $(CC_PREFIX)-gcc $(CFLAGS)
AS          = $(CC_PREFIX)-as
LD          = $(CC_PREFIX)-ld
OBJDUMP     = $(CC_PREFIX)-objdump
OBJCOPY     = $(CC_PREFIX)-objcopy

# BootRAM
BOOTRAM_GEN         = ../../tools/bootram_gen
BOOTRAM_TEMPLATE    = ../../tools/bootram_template.vhd
BOOTRAM_TARGET     ?= ./program.vhd

# Verilator
VERILATOR_DIR  ?= ../../rtl/sim_verilator
VERILATOR_ARGS ?=  -l 0x10000000

# Target
TARGET		= bootloader

# Options
LDSCRIPT    = linker_script
CFLAGS	   += -Ttext 0x10000000 -O2 -g -Wall
CFLAGS     += -msoft-div -msoft-float -msoft-mul -mno-ror -mno-cmov -mno-sext
CFLAGS	   += -nostartfiles -nodefaultlibs -nostdlib -lgcc 
CFLAGS	   += -L ./ -lgcc -L ./ -T$(LDSCRIPT)
ASFLAGS     = -Wa
LDFLAGS     = 

OBJ += boot.o
OBJ += main.o
OBJ += boot_serial.o
OBJ += boot_flash.o
OBJ += xmodem.o
OBJ += serial.o
OBJ += timer.o
OBJ += spi_flash.o

CFLAGS += -I.
CFLAGS += -DUSE_SPI_FLASH


###############################################################################
# Rules
###############################################################################
all: bootram $(TARGET).elf lst bin 
	
clean:
	-rm $(OBJ) *.map $(TARGET).lst $(TARGET).hex *.txt $(TARGET).elf $(TARGET).bin $(BOOTRAM_TARGET)

%.o : %.s
	$(CC) -c $(ASFLAGS) $< -o $@

%.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(TARGET).elf: $(OBJ) $(LDSCRIPT) makefile
	$(CC) $(LDFLAGS) $(LIBS) $(OBJ) -o $@
	
lst:  $(TARGET).lst

%.lst: $(TARGET).elf
	$(OBJDUMP) -h -d -S $< > $@

bin: $(TARGET).bin

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	
bootram: bin
	$(BOOTRAM_GEN) -f $(TARGET).bin -t $(BOOTRAM_TEMPLATE) -o $(BOOTRAM_TARGET)

run: bin
	make -C $(VERILATOR_DIR) TEST_IMAGE=$(CURDIR)/$(TARGET).bin SIMARGS="$(VERILATOR_ARGS)"
