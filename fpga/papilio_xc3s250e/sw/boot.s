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

    l.j init
    l.nop

    # Magic header word
    .word 0xb00710ad
    
    # File length
    .word 0x00000000

init:
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

