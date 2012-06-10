##########################################################################
# Top level makefile
##########################################################################

##########################################################################
# Rules
##########################################################################
all: build_sim 

# Build simulator & run test image
build_sim:
	make -C or32-sim 
	./or32-sim/or32-sim -f ./or32-sim/test_firmware.bin

clean:
	make -C or32-sim clean
