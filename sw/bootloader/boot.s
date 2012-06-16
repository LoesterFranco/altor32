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
    l.movhi r5,hi(_end);
    l.ori r5,r5,lo(_end);
    
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

    # Jump to 0x2000 + vector
    l.j (0x2000 >> 2)
    l.nop
    
#-------------------------------------------------------------
# VECTOR 0x300 - External Interrupt
#-------------------------------------------------------------
.org    0x300
vector_extint:

    # Jump to 0x2000 + vector
    l.j (0x2000 >> 2)
    l.nop    

#-------------------------------------------------------------
# VECTOR 0x400 - Syscall
#-------------------------------------------------------------
.org    0x400
vector_syscall:

    # Jump to 0x2000 + vector
    l.j (0x2000 >> 2)
    l.nop
    
#-------------------------------------------------------------
# VECTOR 0x600 - Trap
#-------------------------------------------------------------
.org    0x600
vector_trap:

    # Jump to 0x2000 + vector
    l.j (0x2000 >> 2)
    l.nop
