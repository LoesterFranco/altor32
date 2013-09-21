//-----------------------------------------------------------------
//                           AltOR32 
//                Alternative Lightweight OpenRisc 
//                            V2.0
//                     Ultra-Embedded.com
//                   Copyright 2011 - 2013
//
//               Email: admin@ultra-embedded.com
//
//                       License: LGPL
//-----------------------------------------------------------------
//
// Copyright (C) 2011 - 2013 Ultra-Embedded.com
//
// This source file may be used and distributed without         
// restriction provided that this copyright statement is not    
// removed from the file and that any derivative work contains  
// the original copyright notice and the associated disclaimer. 
//
// This source file is free software; you can redistribute it   
// and/or modify it under the terms of the GNU Lesser General   
// Public License as published by the Free Software Foundation; 
// either version 2.1 of the License, or (at your option) any   
// later version.
//
// This source is distributed in the hope that it will be       
// useful, but WITHOUT ANY WARRANTY; without even the implied   
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
// PURPOSE.  See the GNU Lesser General Public License for more 
// details.
//
// You should have received a copy of the GNU Lesser General    
// Public License along with this source; if not, write to the 
// Free Software Foundation, Inc., 59 Temple Place, Suite 330, 
// Boston, MA  02111-1307  USA
//-----------------------------------------------------------------

//`define CONF_CORE_DEBUG
//`define CONF_CORE_DEBUG_BUBBLE
//`define CONF_CORE_TRACE
//`define CONF_CORE_FAULT_ON_OPCODE0

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "altor32_defs.v"

//-----------------------------------------------------------------
// Module - Instruction Execute
//-----------------------------------------------------------------
module altor32_exec
(
    // General
    input               clk_i /*verilator public*/,
    input               rst_i /*verilator public*/,

    // Maskable interrupt    
    input               intr_i /*verilator public*/,

    // Unmaskable interrupt
    input               nmi_i /*verilator public*/,

    // Fault
    output reg          fault_o /*verilator public*/,

    // Breakpoint / Trap
    output reg          break_o /*verilator public*/,

    // Cache control
    output reg          icache_flush_o /*verilator public*/,
    output reg          dcache_flush_o /*verilator public*/,
        
    // Branch
    output              branch_o /*verilator public*/,
    output [31:0]       branch_pc_o /*verilator public*/,
    output              stall_o /*verilator public*/,

    // Opcode & arguments
    input [31:0]        opcode_i /*verilator public*/,
    input [31:0]        opcode_pc_i /*verilator public*/,
    input               opcode_valid_i /*verilator public*/,

    // Reg A
    input [4:0]         reg_ra_i /*verilator public*/,
    input [31:0]        reg_ra_value_i /*verilator public*/,

    // Reg B
    input [4:0]         reg_rb_i /*verilator public*/,
    input [31:0]        reg_rb_value_i /*verilator public*/,

    // Reg D
    input [4:0]         reg_rd_i /*verilator public*/,

    // Output
    output [31:0]       opcode_o /*verilator public*/,
    output [4:0]        reg_rd_o /*verilator public*/,
    output [31:0]       reg_rd_value_o /*verilator public*/,
    output              mult_o /*verilator public*/,
    output [31:0]       mult_res_o /*verilator public*/,

    // Register write back bypass
    input [4:0]         wb_rd_i /*verilator public*/,
    input [31:0]        wb_rd_value_i /*verilator public*/,

    // Memory Interface
    output reg [31:0]   dmem_addr_o /*verilator public*/,
    output reg [31:0]   dmem_data_out_o /*verilator public*/,
    input [31:0]        dmem_data_in_i /*verilator public*/,
    output reg [3:0]    dmem_wr_o /*verilator public*/,
    output reg          dmem_rd_o /*verilator public*/,
    input               dmem_accept_i /*verilator public*/,
    input               dmem_ack_i /*verilator public*/
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter           BOOT_VECTOR         = 32'h00000000;
parameter           ISR_VECTOR          = 32'h00000000;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------

// Branch PC
reg [31:0] r_pc_branch;
reg        r_pc_fetch;
reg        r_stall;

// Exception saved program counter
reg [31:0] r_epc;

// Supervisor register
reg [31:0] r_sr;

// Exception saved supervisor register
reg [31:0] r_esr;

// Destination register number (post execute stage)
reg [4:0] r_e_rd;

// Current opcode (PC for debug)
reg [31:0] r_e_opcode;
reg [31:0] r_e_opcode_pc;

// ALU input A
reg [31:0] r_e_alu_a;

// ALU input B
reg [31:0] r_e_alu_b;

// ALU output
wire [31:0] r_e_result;

// Resolved RA/RB register contents
wire [31:0] ra_value_resolved;
wire [31:0] rb_value_resolved;
wire        resolve_failed;

// ALU Carry
wire alu_carry_out;
wire alu_carry_update;

// ALU operation selection
reg [3:0] r_e_alu_func;

// Load instruction details
reg [4:0] r_load_rd;
reg [7:0] r_load_inst;
reg [1:0] r_load_offset;

// Load forwarding
wire         load_insn;
wire [31:0]  load_result;

// Memory access?
reg r_mem_load;
reg r_mem_store;
reg r_mem_access;

wire load_pending;
wire store_pending;
wire load_insert;
wire load_stall;

reg d_mem_load;

// Delayed NMI
reg r_nmi;

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------

// ALU
altor32_alu alu
(
    // ALU operation select
    .op_i(r_e_alu_func),

    // Operands
    .a_i(r_e_alu_a),
    .b_i(r_e_alu_b),
    .c_i(r_sr[`OR32_SR_CY]),

    // Result
    .p_o(r_e_result),

    // Carry
    .c_o(alu_carry_out),
    .c_update_o(alu_carry_update)
);

// Load result forwarding
altor32_lfu
u_lfu
(
    // Opcode
    .opcode_i(r_load_inst),

    // Memory load result
    .mem_result_i(dmem_data_in_i),
    .mem_offset_i(r_load_offset),

    // Result
    .load_result_o(load_result),
    .load_insn_o(load_insn)
);

// Load / store pending logic
altor32_lsu
u_lsu
(
    // Current instruction
    .opcode_valid_i(opcode_valid_i & ~r_pc_fetch),
    .opcode_i({2'b00,opcode_i[31:26]}),

    // Load / Store pending
    .load_pending_i(r_mem_load),
    .store_pending_i(r_mem_store),

    // Load dest register
    .rd_load_i(r_load_rd),

    // Load insn in WB stage
    .load_wb_i(d_mem_load),

    // Memory status
    .mem_access_i(r_mem_access),
    .mem_ack_i(dmem_ack_i),

    // Load / store still pending
    .load_pending_o(load_pending),
    .store_pending_o(store_pending),

    // Insert load result into pipeline
    .write_result_o(load_insert),

    // Stall pipeline due
    .stall_o(load_stall)
);

// Operand forwarding
altor32_dfu
u_dfu
(
    // Input registers
    .ra_i(reg_ra_i),
    .rb_i(reg_rb_i),

    // Input register contents
    .ra_regval_i(reg_ra_value_i),
    .rb_regval_i(reg_rb_value_i),

    // Dest register (EXEC stage)
    .rd_ex_i(r_e_rd),

    // Dest register (WB stage)
    .rd_wb_i(wb_rd_i),

    // Load pending / target
    .load_pending_i(load_pending),
    .rd_load_i(r_load_rd),

    // Multiplier status
    .mult_lo_ex_i(1'b0),
    .mult_hi_ex_i(1'b0),
    .mult_lo_wb_i(1'b0),
    .mult_hi_wb_i(1'b0),

    // Multiplier result
    .result_mult_i(64'b0),

    // Result (EXEC)
    .result_ex_i(r_e_result),

    // Result (WB)
    .result_wb_i(wb_rd_value_i),

    // Resolved register values
    .result_ra_o(ra_value_resolved),
    .result_rb_o(rb_value_resolved),

    // Stall due to failed resolve
    .stall_o(resolve_failed)
);

//-------------------------------------------------------------------
// Execute: Execute opcode
//-------------------------------------------------------------------

// Execute stage blocking assignment vars
reg [7:0] v_inst;
reg [4:0] v_rd;
reg [7:0] v_alu_op;
reg [1:0] v_shift_op;
reg [15:0] v_sfxx_op;
reg [15:0] v_imm;
reg [31:0] v_imm_uint32;
reg [31:0] v_imm_int32;
reg [31:0] v_store_imm;
reg [15:0] v_mxspr_imm;
reg [31:0] v_target;
reg [31:0] v_reg_ra;
reg [31:0] v_reg_rb;
reg [31:0] v_pc;
reg [31:0] v_offset;
reg [31:0] v_shift_val;
reg [31:0] v_shift_imm;
reg [31:0] v_vector;
reg [31:0] v_sr;
reg [31:0] v_mem_addr;
reg [31:0] v_mem_data_in;
reg v_exception;
reg v_branch;
reg v_jmp;
reg v_write_rd;
reg v_store_pending;
reg v_load_pending;
reg v_inst_load;
reg v_inst_store;
reg v_stall;
reg v_no_intr;
reg v_opcode_valid;
reg v_check_load_rd;

always @ (posedge clk_i or posedge rst_i)
begin
   if (rst_i == 1'b1)
   begin
       r_pc_branch          <= 32'h00000000;
       r_pc_fetch           <= 1'b0;
       r_stall              <= 1'b0;

       // Status registers
       r_epc                <= 32'h00000000;
       r_sr                 <= 32'h00000000;
       r_esr                <= 32'h00000000;
       
       r_e_rd               <= 5'b00000;

       // Default to no ALU operation
       r_e_alu_func         <= `ALU_NONE;
       r_e_alu_a            <= 32'h00000000;
       r_e_alu_b            <= 32'h00000000;
       
       r_e_opcode           <= 32'h00000000;
       r_e_opcode_pc        <= 32'h00000000;

       // Data memory
       dmem_addr_o          <= 32'h00000000;
       dmem_data_out_o      <= 32'h00000000;
       dmem_rd_o            <= 1'b0;
       dmem_wr_o            <= 4'b0000;

       fault_o              <= 1'b0;
       break_o              <= 1'b0;

       r_nmi                <= 1'b0;
       
       icache_flush_o       <= 1'b0; 
       dcache_flush_o       <= 1'b0;
       
       r_mem_load           <= 1'b0;
       r_mem_store          <= 1'b0;
       r_mem_access         <= 1'b0;
       
       r_load_rd            <= 5'b00000;
       r_load_inst          <= 8'h00;
       r_load_offset        <= 2'b00;

       d_mem_load           <= 1'b0;      
   end
   else
   begin

       // If memory access accepted by slave
       if (dmem_accept_i)
       begin
           dmem_rd_o            <= 1'b0;
           dmem_wr_o            <= 4'b0000;
       end
       
       r_mem_access         <= 1'b0;
       break_o              <= 1'b0;
       icache_flush_o       <= 1'b0; 
       dcache_flush_o       <= 1'b0;

      // Record NMI in-case it can't be processed this cycle
      if (nmi_i)
          r_nmi <= 1'b1;   
       
       // Reset branch request
       r_pc_fetch           <= 1'b0;

       v_exception          = 1'b0;
       v_vector             = 32'h00000000;
       v_branch             = 1'b0;
       v_jmp                = 1'b0;
       v_write_rd           = 1'b0;
       v_sr                 = r_sr;
       v_stall              = 1'b0;
       v_no_intr            = 1'b0;

       d_mem_load          <= r_mem_access & r_mem_load;

       //---------------------------------------------------------------
       // Opcode
       //---------------------------------------------------------------   

       // Instruction not ready
       if (!opcode_valid_i)
       begin
            v_opcode_valid  = 1'b0;  
                      
`ifdef CONF_CORE_DEBUG_BUBBLE
            $display("%08x: Execute - Instruction not ready", opcode_pc_i);
`endif
       end
       // Branch request, always drop the next instruction
       else if (r_pc_fetch)
       begin            
            v_opcode_valid    = 1'b0;
            
`ifdef CONF_CORE_DEBUG
            $display("%08x: Exec - Branch pending, skip instruction (%x)", opcode_pc_i, opcode_i);
`endif       
       end       
       // Valid instruction ready     
       else
       begin
            v_mem_data_in   = opcode_i;
            v_opcode_valid  = 1'b1;            

`ifdef CONF_CORE_FAULT_ON_OPCODE0
            // This is a valid opcode (branch to same instruction), 
            // but rare and useful for catching pipeline errors
            if (v_mem_data_in == 32'h00000000)
                fault_o <= 1'b1;
`endif
       end

       //---------------------------------------------------------------
       // Decode opcode
       //---------------------------------------------------------------          
       v_alu_op             = {v_mem_data_in[9:6],v_mem_data_in[3:0]};
       v_sfxx_op            = {5'b00,v_mem_data_in[31:21]};
       v_shift_op           = v_mem_data_in[7:6];
       v_target             = sign_extend_imm26(v_mem_data_in[25:0]);
       v_store_imm          = sign_extend_imm16({v_mem_data_in[25:21],v_mem_data_in[10:0]});

       // Signed & unsigned imm -> 32-bits
       v_imm                = v_mem_data_in[15:0];
       v_imm_int32          = sign_extend_imm16(v_imm);
       v_imm_uint32         = extend_imm16(v_imm);

       // Load register[ra]
       v_reg_ra             = ra_value_resolved;

       // Load register[rb]
       v_reg_rb             = rb_value_resolved;
       
       // Default to no ALU operation (output == input_a)
       r_e_alu_func         <= `ALU_NONE;
       r_e_alu_a            <= 32'h00000000;    
       
       // Default target is R[d]
       v_rd                 = reg_rd_i;
       
       //---------------------------------------------------------------
       // Outstanding memory access
       //--------------------------------------------------------------- 

       // Pending accesses
       v_load_pending   = load_pending;
       v_store_pending  = store_pending;
       v_check_load_rd  = 1'b1;
       
       // Stall pipeline due to load / store
       if (v_opcode_valid & load_stall)
       begin
           v_stall        = 1'b1;
           v_opcode_valid = 1'b0;
       end

       // Insert load result into pipeline?
       if (load_insert)
       begin
           // Feed load result into pipeline
           r_e_alu_func         <= `ALU_NONE;
           r_e_alu_a            <= load_result;
           v_rd                  = r_load_rd;
           v_write_rd            = 1'b1;
       end

       //---------------------------------------------------------------
       // Invalid PC detection
       //---------------------------------------------------------------
              
       // Detect incorrect program counter and cause FAULT
       if (opcode_valid_i && (opcode_pc_i[1:0] != 2'b00))
       begin
            fault_o        <= 1'b1;
            v_opcode_valid  = 1'b0;
            v_exception     = 1'b1;
            v_vector        = ISR_VECTOR + `VECTOR_BUS_ERROR;
       end
       
       //---------------------------------------------------------------
       // Failed operand resolve?
       //---------------------------------------------------------------
       if (opcode_valid_i & resolve_failed)
       begin
`ifdef CONF_CORE_DEBUG
            $display("%08x: Operand resolve failed RA=%d, RB=%d", opcode_pc_i, reg_ra_i, reg_rb_i);
`endif
            // Stall!
            v_opcode_valid  = 1'b0;
            v_stall         = 1'b1;   
       end    
       
       //---------------------------------------------------------------
       // Final instruction decoding
       //--------------------------------------------------------------- 
       
       // Insert bubble into the pipeline?
       if (!v_opcode_valid)
       begin
            v_mem_data_in   = `OPCODE_INST_BUBBLE;
            v_check_load_rd = 1'b0;
       end

       // Store opcode (after possible bubble generation)
       r_e_opcode            <= v_mem_data_in;
       r_e_opcode_pc         <= opcode_pc_i;

       // Decode instruction
       v_inst               = {2'b00,v_mem_data_in[31:26]};

       // Shift ammount (from register[rb])
       v_shift_val          = {26'b00,v_reg_rb[5:0]};

       // Shift ammount (from immediate)
       v_shift_imm          = {26'b00,v_imm[5:0]};

       // MTSPR/MFSPR operand
       v_mxspr_imm          =  (v_reg_ra[15:0] | {5'b00000,v_mem_data_in[10:0]});

       // Next expected PC (current PC + 4)
       v_pc                 = (opcode_pc_i + 4);
       
       // Latch carry if updated
       if (alu_carry_update)
            v_sr[`OR32_SR_CY] = alu_carry_out;       

`ifdef CONF_CORE_TRACE
       if (v_opcode_valid)
       begin
            $display("%08x: Execute 0x%08x", opcode_pc_i, v_mem_data_in);
            $display(" rA[%d] = 0x%08x", reg_ra_i, v_reg_ra);
            $display(" rB[%d] = 0x%08x", reg_rb_i, v_reg_rb);
       end
`endif

       //---------------------------------------------------------------
       // Execute instruction
       //---------------------------------------------------------------
       case (v_inst)
           `INST_OR32_BUBBLE :
           begin
                // Do not allow external interrupts whilst executing a bubble
                // as this will result in pipeline issues.
                v_no_intr = 1'b1;
           end
           `INST_OR32_ALU :
           begin
               case (v_alu_op)
                   `INST_OR32_ADD: // l.add
                   begin
                       r_e_alu_func <= `ALU_ADD;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_reg_rb;
                       v_write_rd = 1'b1;
                   end
                   
                   `INST_OR32_ADDC: // l.addc
                   begin
                       r_e_alu_func <= `ALU_ADDC;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_reg_rb;
                       v_write_rd = 1'b1;
                   end                     

                   `INST_OR32_AND: // l.and
                   begin
                       r_e_alu_func <= `ALU_AND;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_reg_rb;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_OR: // l.or
                   begin
                       r_e_alu_func <= `ALU_OR;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_reg_rb;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_SLL: // l.sll
                   begin
                       r_e_alu_func <= `ALU_SHIFTL;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_shift_val;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_SRA: // l.sra
                   begin
                       r_e_alu_func <= `ALU_SHIRTR_ARITH;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_shift_val;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_SRL: // l.srl
                   begin
                       r_e_alu_func <= `ALU_SHIFTR;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_shift_val;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_SUB: // l.sub
                   begin
                       r_e_alu_func <= `ALU_SUB;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_reg_rb;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_XOR: // l.xor
                   begin
                       r_e_alu_func <= `ALU_XOR;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_reg_rb;
                       v_write_rd = 1'b1;
                   end

                   default:
                   begin
                       fault_o <= 1'b1;
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
                   end
               endcase
           end

           `INST_OR32_ADDI: // l.addi
           begin
               r_e_alu_func <= `ALU_ADD;
               r_e_alu_a <= v_reg_ra;
               r_e_alu_b <= v_imm_int32;
               v_write_rd = 1'b1;
           end

           `INST_OR32_ANDI: // l.andi
           begin
               r_e_alu_func <= `ALU_AND;
               r_e_alu_a <= v_reg_ra;
               r_e_alu_b <= v_imm_uint32;
               v_write_rd = 1'b1;
           end

           `INST_OR32_BF: // l.bf
           begin
               if (v_sr[`OR32_SR_F] == 1'b1)
                    v_branch = 1'b1;
           end

           `INST_OR32_BNF: // l.bnf
           begin
               if (v_sr[`OR32_SR_F] == 1'b0)
                    v_branch = 1'b1;
           end

           `INST_OR32_J: // l.j
           begin
               v_branch = 1'b1;
           end

           `INST_OR32_JAL: // l.jal
           begin
               r_e_alu_a <= v_pc;
               v_write_rd = 1'b1;
               v_rd       = 5'b01001; // Write to REG_9_LR
`ifdef CONF_CORE_DEBUG               
               $display(" Save 0x%x to LR", v_pc);
`endif               
               v_branch = 1'b1;
           end

          `INST_OR32_JALR: // l.jalr
           begin
               r_e_alu_a <= v_pc;
               v_write_rd = 1'b1;
               v_rd       = 5'b01001; // Write to REG_9_LR
`ifdef CONF_CORE_DEBUG               
               $display(" Save 0x%x to LR", v_pc);
`endif               
               v_pc = v_reg_rb;
               v_jmp = 1;
           end

          `INST_OR32_JR: // l.jr
           begin
               v_pc = v_reg_rb;
               v_jmp = 1;
           end

           // l.lbs l.lhs l.lws l.lbz l.lhz l.lwz
           `INST_OR32_LBS, `INST_OR32_LHS, `INST_OR32_LWS, `INST_OR32_LBZ, `INST_OR32_LHZ, `INST_OR32_LWZ :
           begin
               v_mem_addr = (v_reg_ra + v_imm_int32);
               dmem_addr_o <= v_mem_addr;
               dmem_data_out_o <= 32'h00000000;
               dmem_rd_o <= 1'b1;
               
               // Writeback if load result ready
               v_write_rd = 1'b1;
               v_check_load_rd = 1'b0;
               
               // Mark load as pending
               v_load_pending   = 1'b1;
               r_mem_access    <= 1'b1;
               
               // Record target register
               r_load_rd    <= reg_rd_i;
               r_load_inst  <= v_inst;
               r_load_offset<= v_mem_addr[1:0];
               
`ifdef CONF_CORE_DEBUG
               $display(" Load from 0x%08x to R%d", v_mem_addr, reg_rd_i);
`endif
                // Detect bad load address & fault (ignore bit 31)
                if (v_mem_addr[30:28] != 3'h1)
                begin
                    v_load_pending  = 1'b0;
                    dmem_rd_o      <= 1'b0;
                    r_mem_access   <= 1'b0;                
                    fault_o        <= 1'b1;
                    v_exception     = 1'b1;
                    v_vector        = ISR_VECTOR + `VECTOR_BUS_ERROR;
                end
           end

          `INST_OR32_MFSPR: // l.mfspr
          begin
               case (v_mxspr_imm)
                   // SR - Supervision register
                   `SPR_REG_SR:
                   begin
                       r_e_alu_a <= v_sr;
                       v_write_rd = 1'b1;
                   end

                   // EPCR - EPC Exception saved PC
                   `SPR_REG_EPCR:
                   begin
                       r_e_alu_a <= r_epc;
                       v_write_rd = 1'b1;
                   end

                   // ESR - Exception saved SR
                   `SPR_REG_ESR:
                   begin
                       r_e_alu_a <= r_esr;
                       v_write_rd = 1'b1;
                   end

                   default:
                   begin
                       fault_o <= 1'b1;
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
                   end
               endcase
           end

          `INST_OR32_MTSPR: // l.mtspr
          begin
               case (v_mxspr_imm)
                   // SR - Supervision register
                   `SPR_REG_SR:
                   begin
                       v_sr = v_reg_rb;
                       
                       // Cache flush request?
                       icache_flush_o <= v_reg_rb[`OR32_SR_ICACHE_FLUSH];
                       dcache_flush_o <= v_reg_rb[`OR32_SR_DCACHE_FLUSH];
                       
                       // Don't store cache flush requests
                       v_sr[`OR32_SR_ICACHE_FLUSH] = 1'b0;
                       v_sr[`OR32_SR_DCACHE_FLUSH] = 1'b0;
                   end

                   // EPCR - EPC Exception saved PC
                   `SPR_REG_EPCR:
                   begin
                       r_epc <= v_reg_rb;
                   end

                   // ESR - Exception saved SR
                   `SPR_REG_ESR:
                   begin
                       r_esr <= v_reg_rb;
                   end
                   
                   default:
                   begin
                       fault_o <= 1'b1;
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
                   end
               endcase
           end

           `INST_OR32_MOVHI: // l.movhi
           begin
               r_e_alu_a <= {v_imm,16'h0000};
               v_write_rd = 1'b1;
           end

           `INST_OR32_NOP: // l.nop
           begin
              `ifdef SIMULATION
              case (v_imm)
              // NOP_PUTC
              16'h0004:  $write("%c", v_reg_ra[7:0]);
              // NOP
              16'h0000: ;
              endcase
              `endif
           end

           `INST_OR32_ORI: // l.ori
           begin
               r_e_alu_func <= `ALU_OR;
               r_e_alu_a <= v_reg_ra;
               r_e_alu_b <= v_imm_uint32;
               v_write_rd = 1'b1;
           end

           `INST_OR32_RFE: // l.rfe
           begin
                v_pc      = r_epc;
                v_sr      = r_esr;
                v_jmp     = 1;
           end

          `INST_OR32_SHIFTI :
          begin
               case (v_shift_op)
                   `INST_OR32_SLLI: // l.slli
                   begin
                       r_e_alu_func <= `ALU_SHIFTL;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_shift_imm;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_SRAI: // l.srai
                   begin
                       r_e_alu_func <= `ALU_SHIRTR_ARITH;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_shift_imm;
                       v_write_rd = 1'b1;
                   end

                   `INST_OR32_SRLI: // l.srli
                     begin
                       r_e_alu_func <= `ALU_SHIFTR;
                       r_e_alu_a <= v_reg_ra;
                       r_e_alu_b <= v_shift_imm;
                       v_write_rd = 1'b1;
                   end

                   default:
                   begin
                       fault_o <= 1'b1;
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
                   end
               endcase
           end

           `INST_OR32_SB:
           begin
               v_mem_addr = (v_reg_ra + v_store_imm);
               dmem_addr_o <= v_mem_addr;
               r_mem_access <= 1'b1;
               case (v_mem_addr[1:0])
                   2'b00 :
                   begin
                       dmem_data_out_o <= {v_reg_rb[7:0],24'h000000};
                       dmem_wr_o <= 4'b1000;
                       v_store_pending  = 1'b1;
                   end
                   2'b01 :
                   begin
                       dmem_data_out_o <= {{8'h00,v_reg_rb[7:0]},16'h0000};
                       dmem_wr_o <= 4'b0100;
                       v_store_pending  = 1'b1;
                   end
                   2'b10 :
                   begin
                       dmem_data_out_o <= {{16'h0000,v_reg_rb[7:0]},8'h00};
                       dmem_wr_o <= 4'b0010;
                       v_store_pending  = 1'b1;
                   end
                   2'b11 :
                   begin
                       dmem_data_out_o <= {24'h000000,v_reg_rb[7:0]};
                       dmem_wr_o <= 4'b0001;
                       v_store_pending  = 1'b1;
                   end
                   default :
                   begin
                       dmem_data_out_o <= 32'h00000000;
                       dmem_wr_o <= 4'b0000;
                   end
               endcase
           end

          `INST_OR32_SFXX, `INST_OR32_SFXXI:
          begin
               case (v_sfxx_op)
                   `INST_OR32_SFEQ: // l.sfeq
                   begin
                        if (v_reg_ra == v_reg_rb)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFEQI: // l.sfeqi
                   begin
                        if (v_reg_ra == v_imm_int32)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGES: // l.sfges
                   begin
                        if (greater_than_equal_signed(v_reg_ra, v_reg_rb) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGESI: // l.sfgesi
                   begin
                        if (greater_than_equal_signed(v_reg_ra, v_imm_int32) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGEU: // l.sfgeu
                   begin
                        if (v_reg_ra >= v_reg_rb)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGEUI: // l.sfgeui
                   begin
                        if (v_reg_ra >= v_imm_int32)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGTS: // l.sfgts
                   begin
                        if (greater_than_signed(v_reg_ra, v_reg_rb) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGTSI: // l.sfgtsi
                   begin
                        if (greater_than_signed(v_reg_ra, v_imm_int32) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGTU: // l.sfgtu
                   begin
                        if (v_reg_ra > v_reg_rb)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFGTUI: // l.sfgtui
                   begin
                        if (v_reg_ra > v_imm_int32)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLES: // l.sfles
                   begin
                        if (less_than_equal_signed(v_reg_ra, v_reg_rb) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLESI: // l.sflesi
                   begin
                        if (less_than_equal_signed(v_reg_ra, v_imm_int32) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLEU: // l.sfleu
                   begin
                        if (v_reg_ra <= v_reg_rb)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLEUI: // l.sfleui
                   begin
                        if (v_reg_ra <= v_imm_int32)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLTS: // l.sflts
                   begin
                        if (less_than_signed(v_reg_ra, v_reg_rb) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLTSI: // l.sfltsi
                   begin
                        if (less_than_signed(v_reg_ra, v_imm_int32) == 1'b1)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLTU: // l.sfltu
                   begin
                        if (v_reg_ra < v_reg_rb)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFLTUI: // l.sfltui
                   begin
                        if (v_reg_ra < v_imm_int32)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFNE: // l.sfne
                   begin
                        if (v_reg_ra != v_reg_rb)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   `INST_OR32_SFNEI: // l.sfnei
                   begin
                        if (v_reg_ra != v_imm_int32)
                            v_sr[`OR32_SR_F] = 1'b1;
                        else
                            v_sr[`OR32_SR_F] = 1'b0;
                   end

                   default:
                   begin
                       fault_o <= 1'b1;
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
                   end
               endcase
           end

           `INST_OR32_SH: // l.sh
           begin
               v_mem_addr = (v_reg_ra + v_store_imm);
               dmem_addr_o <= v_mem_addr;
               r_mem_access <= 1'b1;
               case (v_mem_addr[1:0])
                   2'b00 :
                   begin
                       dmem_data_out_o <= {v_reg_rb[15:0],16'h0000};
                       dmem_wr_o <= 4'b1100;
                       v_store_pending  = 1'b1;
                   end
                   2'b10 :
                   begin
                       dmem_data_out_o <= {16'h0000,v_reg_rb[15:0]};
                       dmem_wr_o <= 4'b0011;
                       v_store_pending  = 1'b1;
                   end
                   default :
                   begin
                       dmem_data_out_o <= 32'h00000000;
                       dmem_wr_o <= 4'b0000;
                   end
               endcase
           end

           `INST_OR32_SW: // l.sw
           begin
               v_mem_addr = (v_reg_ra + v_store_imm);
               dmem_addr_o <= v_mem_addr;
               dmem_data_out_o <= v_reg_rb;
               dmem_wr_o <= 4'b1111;
               r_mem_access <= 1'b1;
               v_store_pending  = 1'b1;

`ifdef CONF_CORE_DEBUG
               $display(" Store R%d to 0x%08x = 0x%08x", reg_rb_i, {v_mem_addr[31:2],2'b00}, v_reg_rb);
`endif
           end

          `INST_OR32_MISC:
          begin
               case (v_mem_data_in[31:24])
                   `INST_OR32_SYS: // l.sys
                   begin
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_SYSCALL;
                   end

                   `INST_OR32_TRAP: // l.trap
                   begin
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_TRAP;
                       break_o <= 1'b1;
                   end

                   default :
                   begin
                       fault_o <= 1'b1;
                       v_exception = 1'b1;
                       v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
                   end
               endcase
           end

           `INST_OR32_XORI: // l.xori
           begin
               r_e_alu_func <= `ALU_XOR;
               r_e_alu_a <= v_reg_ra;
               r_e_alu_b <= v_imm_int32;
               v_write_rd = 1'b1;
           end

           default :
           begin
               fault_o <= 1'b1;
               v_exception = 1'b1;
               v_vector = ISR_VECTOR + `VECTOR_ILLEGAL_INST;
           end
       endcase

       //---------------------------------------------------------------
       // Branch logic
       //---------------------------------------------------------------

       // If relative branch, calculate target before possible interrupt/exception
       if (v_branch == 1'b1)
       begin
           v_offset = {v_target[29:0],2'b00};
           v_pc     = (opcode_pc_i + v_offset);
       end
        
       // Pipeline stall due to load result not ready
       if (v_stall == 1'b1)
       begin
            // No exceptions whilst stalled
       end                     
       // Exception (Fault/Syscall/Break)
       else if (v_exception == 1'b1)
       begin
            // Save PC of next instruction
            r_epc       <= v_pc;

            // Disable further interrupts
            r_esr       <= v_sr;
            v_sr         = 0;

            // Set PC to exception vector
            v_pc         = v_vector;
            r_pc_branch <= v_pc;
            r_pc_fetch  <= 1'b1;         
            
`ifdef CONF_CORE_DEBUG
           $display(" Exception 0x%08x", v_vector);
`endif
       end
       // Non-maskable interrupt
       else if (nmi_i | r_nmi)
       begin
            r_nmi       <= 1'b0;

            // Save PC of next instruction
            r_epc       <= v_pc;

            // Disable further interrupts
            r_esr       <= v_sr;
            v_sr         = 0;

            // Set PC to exception vector
            v_pc         = ISR_VECTOR + `VECTOR_NMI;
            r_pc_branch <= v_pc;
            r_pc_fetch  <= 1'b1;
            
`ifdef CONF_CORE_DEBUG
           $display(" NMI 0x%08x", v_pc);
`endif
       end       
       // External interrupt
       else if (v_no_intr == 1'b0 && 
                ((intr_i && v_sr[`OR32_SR_IEE])))
       begin
            // Save PC of next instruction & SR
            r_epc       <= v_pc;          

            // Disable further interrupts
            r_esr       <= v_sr;
            v_sr         = 0;

            // Set PC to external interrupt vector
            v_pc    = ISR_VECTOR + `VECTOR_EXTINT;

            r_pc_branch <= v_pc;
            r_pc_fetch  <= 1'b1;
            
`ifdef CONF_CORE_DEBUG
           $display(" External Interrupt 0x%08x", v_pc);
`endif
       end         
       // Handle relative branches (l.bf, l.bnf, l.j, l.jal)
       else if (v_branch == 1'b1)
       begin
            // Perform branch (already in v_pc)
            r_pc_branch    <= v_pc;
            r_pc_fetch     <= 1'b1;
           
`ifdef CONF_CORE_DEBUG
           $display(" Branch to 0x%08x", v_pc);
`endif
       end
       // Handle absolute jumps (l.jr, l.jalr, l.rfe)
       else if (v_jmp == 1'b1)
       begin
            // Perform branch
            r_pc_branch    <= v_pc;
            r_pc_fetch     <= 1'b1;
           
`ifdef CONF_CORE_DEBUG
           $display(" Jump to 0x%08x", v_pc);
`endif
       end


       // Update other registers with variable values
       r_stall      <= v_stall;                  
       r_sr         <= v_sr;

       // Memory access?
       r_mem_load <= v_load_pending;
       r_mem_store<= v_store_pending;
       
       // No writeback required?
       if (v_write_rd == 1'b0)
       begin
           // Target register is R0 which is read-only
           r_e_rd <= 5'b00000;           
       end
       // Writeback required
       else
       begin
            // Load outstanding, check if result target is being
            // overwritten (to avoid WAR hazard)
            if (v_check_load_rd && v_rd == r_load_rd)
            begin
            `ifdef CONF_CORE_DEBUG
                if (v_rd != 5'b0)
                    $display("%08x: Load target overwrite, clear target (R%d)", opcode_pc_i, r_load_rd);
            `endif   

                // Ditch load result when it arrives
                r_load_rd <= 5'b00000;
            end

            // Target Rd
            r_e_rd <= v_rd;
       end
   end
end

//-------------------------------------------------------------------
// Assignments
//-------------------------------------------------------------------

assign branch_pc_o          = r_pc_branch;
assign branch_o             = r_pc_fetch;
assign stall_o              = r_stall;

assign opcode_o             = r_e_opcode;

assign reg_rd_o             = r_e_rd;
assign reg_rd_value_o       = r_e_result;

assign mult_o               = 1'b0;
assign mult_res_o           = 32'b0;

`include "altor32_funcs.v"

//-------------------------------------------------------------------
// Hooks for debug
//-------------------------------------------------------------------
`ifdef verilator
   function [31:0] get_opcode_ex;
      // verilator public
      get_opcode_ex = r_e_opcode;
   endfunction
   function [31:0] get_pc_ex;
      // verilator public
      get_pc_ex = r_e_opcode_pc;
   endfunction   
`endif

endmodule
