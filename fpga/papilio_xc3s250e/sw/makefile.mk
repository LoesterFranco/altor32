##########################################################################
# Files
##########################################################################
INCLUDE_DIRS ?= 
OBJ = boot.o
OBJ+= $(OBJS)

# Target
TARGET ?= firmware

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

VERILATOR_DIR   ?= ../../../rtl/sim_verilator
TEST_IMAGE ?=
SIMULATOR   = ../../../or32-sim/or32-sim -l 0x2000 -x 0x2100 -f 
VERILATOR_ARGS ?=  -l 0x2000
BOOTHDR     = ../../../tools/bootheader

SIMARGS		?=

# Options
CFLAGS 	   ?=
LDSCRIPT    = linker_script
CFLAGS	   += -Ttext 0x2000 -O2 -g -Wall
CFLAGS     += -msoft-div -msoft-float -msoft-mul -mno-ror -mno-cmov -mno-sext
CFLAGS	   += -nostartfiles -nodefaultlibs -nostdlib -lgcc -L . -lstd -T$(LDSCRIPT)
ASFLAGS     = -Wa
LDFLAGS     = 

CFLAGS += -I. $(INCLUDE_DIRS)

###############################################################################
# Rules
###############################################################################
all: $(TARGET).elf lst bin bootable
	
clean:
	-rm $(OBJ) *.map *.lst *.hex *.txt *.elf $(TARGET).bin

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
	
bootable: $(TARGET).bin
	$(BOOTHDR) -f $(TARGET).bin -o $(TARGET).bin
	
run: bin
	make -C $(VERILATOR_DIR) TEST_IMAGE=$(CURDIR)/$(TARGET).bin SIMARGS="$(VERILATOR_ARGS)"
	
sim: bin
	$(SIMULATOR) $(CURDIR)/$(TARGET).bin $(SIMARGS)
