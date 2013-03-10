###############################################################################
## Makefile
###############################################################################

# Tools
TCHAIN      = or32-elf
CC          = $(TCHAIN)-gcc $(CFLAGS)
AS          = $(TCHAIN)-as
LD          = $(TCHAIN)-ld
OBJDUMP     = $(TCHAIN)-objdump
OBJCOPY     = $(TCHAIN)-objcopy

# Target
TARGET		= image

# Options
LDSCRIPT    = linker_script
CFLAGS	    = -O2 -g -Wall 
CFLAGS	   += -msoft-div -msoft-float -msoft-mul -mno-ror -mno-cmov -mno-sext
CFLAGS	   += -nostartfiles -nodefaultlibs -nostdlib -lgcc -Ttext 0x10002000
CFLAGS	   += -L ./ -lstd -T$(LDSCRIPT)
ASFLAGS     = 
LDFLAGS     = 

# Simulation Configuration
VERILATOR_DIR  ?= ../../rtl/sim_verilator
VERILATOR_ARGS ?=  -l 0x00000000

###############################################################################
# Source Files
###############################################################################
OBJ = 

OBJ += boot.o
OBJ += main.o
OBJ += serial.o
OBJ += irq.o

# RTOS Flags
CFLAGS += -DINCLUDE_RTOS_MALLOC 
CFLAGS += -DINCLUDE_MUTEX 
CFLAGS += -DINCLUDE_SEMAPHORE 
CFLAGS += -DINCLUDE_TIMERCB 
CFLAGS += -DINCLUDE_MAILBOX 
CFLAGS += -DINCLUDE_EVENTS
CFLAGS += -DINCLUDE_RECURSIVE_LOCK
CFLAGS += -DINCLUDE_INTERRUPTS
CFLAGS += -DALTOR32_PLATFORM

# RTOS Kernel
OBJ += ../rtos/kernel/critical.o
OBJ += ../rtos/kernel/event.o
OBJ += ../rtos/kernel/interrupts.o
OBJ += ../rtos/kernel/lock.o
OBJ += ../rtos/kernel/mailbox.o
OBJ += ../rtos/kernel/mem_alloc.o
OBJ += ../rtos/kernel/mutex.o
OBJ += ../rtos/kernel/rtos.o
OBJ += ../rtos/kernel/semaphore.o
OBJ += ../rtos/kernel/thread.o
OBJ += ../rtos/kernel/timer_cb.o

OBJ += ../rtos/arch/altor32/cpu_thread.o
OBJ += ../rtos/arch/altor32/cpu_interrupts.o

CFLAGS += -I. -I./../rtos -I./../rtos/kernel

###############################################################################
# Rules
###############################################################################
all: $(TARGET).elf lst bin 
	
clean:
	-rm $(OBJ) *.map *.lst *.hex *.txt *.elf
	
%.o : %.S
	$(CC) -c $(ASFLAGS) $< -o $@	

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
	
run: bin
	make -C $(VERILATOR_DIR) TEST_IMAGE=$(CURDIR)/$(TARGET).bin SIMARGS="$(VERILATOR_ARGS)"