##########################################################################
# Top level makefile
##########################################################################

##########################################################################
# Rules
##########################################################################
all: build_tools build_sim  build_verilator build_bootloader

# Build simulator & run test image
build_sim:
	make -C or32-sim
	./or32-sim/or32-sim -f ./or32-sim/test_firmware.bin
	
build_verilator:
	make -C rtl/sim_verilator
	
build_bootloader:
	make -C sw/bootloader	

# Build tools
build_tools:
	make -C tools

clean:
	make -C or32-sim clean
	make -C tools clean
	make -C rtl/sim_verilator clean
	make -C sw/bootloader clean
