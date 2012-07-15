#include "../rtos/arch/altor32/exception.inc"

#-------------------------------------------------------------
# VECTOR 0x000 - Application Header
#-------------------------------------------------------------
.org    0x000

# This code is not executed as execution starts from reset vector
.word 0x00000000
.word 0x00000000
.word 0xb00710ad
.word 0x00000000

#-------------------------------------------------------------
# VECTOR 0x100 - Reset
#-------------------------------------------------------------
.org    0x100
vector_reset:

    # Setup SP (R1)
    l.movhi r4,hi(_sp);
    l.ori r1,r4,lo(_sp);
            
    # R4 = _bss_start
    l.movhi r4,hi(_bss_start);
    l.ori r4,r4,lo(_bss_start);
    
    # R5 = _end
    l.movhi r5,hi(_bss_end);
    l.ori r5,r5,lo(_bss_end);
    
BSS_CLEAR:
    l.sw 0x0(r4),r0         # Write 0x00 to mem[r4]
    l.sfleu r4,r5           # SR[F] = (r4 < r5)
    l.bf  BSS_CLEAR         # If SR[F] == 0, jump to BSS_CLEAR
    l.addi r4, r4, 4        # r4 += 4	

    # Jump to main routine
    l.jal   main            
    l.nop 

#-------------------------------------------------------------
# VECTOR 0x200 - Fault / Illegal Instruction
#-------------------------------------------------------------
.org    0x200
vector_fault:

    # Jump to cpu_fault
    l.movhi r10,hi(cpu_fault);
    l.ori r10,r10,lo(cpu_fault);   
    l.jalr r10  
    l.nop       
    
.size	vector_fault, .-vector_fault        

#-------------------------------------------------------------
# VECTOR 0x300 - External Interrupt
#-------------------------------------------------------------
.org    0x300
vector_extint:

    #---------------------------------------------------------
    # Save context
    #---------------------------------------------------------
    asm_save_context
       	
    # Load TCB address 
	l.movhi r10,hi(_currentTCB);
    l.ori r10,r10,lo(_currentTCB);
    l.lwz r10, 0(r10)  
    
    # _currentTCB == NULL, goto no_tcb
    l.sfeq r0, r10
    l.bf no_tcb2
    l.nop
    
    # Store SP to TCB
    l.sw 0(r10), r1
    
    no_tcb2:
    #---------------------------------------------------------
    
    # Setup kernel stack pointer to system stack
    l.movhi r1,hi(_sp);
    l.ori r1,r1,lo(_sp);

    # Jump to irq handling function
    l.movhi r10,hi(cpu_irq);
    l.ori r10,r10,lo(cpu_irq);   
    l.jalr r10  
    l.nop

    l.j common_int_end
    l.nop 
    
.size	vector_extint, .-vector_extint   

#-------------------------------------------------------------
# VECTOR 0x400 - Syscall
#-------------------------------------------------------------
.org    0x400
vector_syscall:

    #---------------------------------------------------------
    # Save context
    #---------------------------------------------------------
    asm_save_context
       	
    # Load TCB address 
	l.movhi r10,hi(_currentTCB);
    l.ori r10,r10,lo(_currentTCB);
    l.lwz r10, 0(r10)  
    
    # _currentTCB == NULL, goto no_tcb
    l.sfeq r0, r10
    l.bf no_tcb 
    l.nop
    
    # Store SP to TCB
    l.sw 0(r10), r1
    
    no_tcb:
    #---------------------------------------------------------
    
    # Setup kernel stack pointer to system stack
    l.movhi r1,hi(_sp);
    l.ori r1,r1,lo(_sp);

    # Jump to irq handling function
    l.movhi r10,hi(cpu_syscall);
    l.ori r10,r10,lo(cpu_syscall);   
    l.jalr r10  
    l.nop
    
    #---------------------------------------------------------
    # Load context
    #---------------------------------------------------------
common_int_end:
    
	# Get TCB pointer address
    l.movhi r13,hi(_currentTCB);
    l.ori r13,r13,lo(_currentTCB);
    
    # Load current TCB address
	l.lwz r13, 0(r13)
	
	# Load stack pointer from TCB	
	l.lwz r1, 0(r13)       
	
    # Restore context
    asm_load_context	
	#---------------------------------------------------------
    
.size	vector_syscall, .-vector_syscall   

#-------------------------------------------------------------
# VECTOR 0x600 - Trap
#-------------------------------------------------------------
.org    0x600
vector_trap:

    # Jump to cpu_fault
    l.movhi r10,hi(cpu_trap);
    l.ori r10,r10,lo(cpu_trap);   
    l.jalr r10  
    l.nop       
    
.size	vector_trap, .-vector_trap