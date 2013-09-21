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

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "altor32_defs.v"

//-----------------------------------------------------------------
// Module - AltOR32 CPU
//-----------------------------------------------------------------
module cpu
(
    // General
    input               clk_i /*verilator public*/,
    input               rst_i /*verilator public*/,

    input               intr_i /*verilator public*/,
    input               nmi_i /*verilator public*/,
    output              fault_o /*verilator public*/,
    output              break_o /*verilator public*/,

    // Instruction memory
    output [31:0]       imem_addr_o /*verilator public*/,
    output              imem_rd_o /*verilator public*/,
    output              imem_burst_o /*verilator public*/,
    input [31:0]        imem_data_in_i /*verilator public*/,
    input               imem_accept_i /*verilator public*/,
    input               imem_ack_i /*verilator public*/,

    // Data memory
    output [31:0]       dmem_addr_o /*verilator public*/,
    output [31:0]       dmem_data_out_o /*verilator public*/,
    input [31:0]        dmem_data_in_i /*verilator public*/,
    output [3:0]        dmem_wr_o /*verilator public*/,
    output              dmem_rd_o /*verilator public*/,
    output              dmem_burst_o /*verilator public*/,
    input               dmem_accept_i /*verilator public*/,
    input               dmem_ack_i /*verilator public*/
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter           BOOT_VECTOR         = 32'h00000000;
parameter           ISR_VECTOR          = 32'h00000000;
parameter           REGISTER_FILE_TYPE  = "SIMULATION";
parameter           ENABLE_ICACHE       = "ENABLED";
parameter           ENABLE_DCACHE       = "DISABLED";
parameter           SUPPORT_32REGS      = "ENABLED";

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------

// Register number (rA)
wire [4:0]  w_ra;

// Register number (rB)
wire [4:0]  w_rb;

// Destination register number (pre execute stage)
wire [4:0]  w_rd;

// Destination register number (post execute stage)
wire [4:0]  w_e_rd;

// Register value (rA)
wire [31:0] w_reg_ra;

// Register value (rB)
wire [31:0] w_reg_rb;

// Current opcode
wire [31:0] w_d_opcode;
wire [31:0] w_d_pc;
wire        w_d_valid;

wire [31:0] w_e_opcode;

// Register writeback value
wire [4:0]  w_wb_rd;
wire [31:0] w_wb_reg_rd;

// Register writeback enable
wire        w_wb_write_rd;

// Result from execute
wire [31:0] w_e_result;
wire        w_e_mult;
wire [31:0] w_e_mult_result;

// Branch request
wire        w_e_branch;
wire [31:0] w_e_branch_pc;
wire        w_e_stall;

wire        icache_rd;
wire [31:0] icache_pc;
wire [31:0] icache_inst;
wire        icache_miss;
wire        icache_valid;
wire        icache_busy;
wire        icache_invalidate;

wire [31:0] dcache_addr;
wire [31:0] dcache_data_o;
wire [31:0] dcache_data_i;
wire [3:0]  dcache_wr;
wire        dcache_rd;
wire        dcache_ack;
wire        dcache_accept;
wire        dcache_flush;

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------

// Instruction Cache
generate
if (ENABLE_ICACHE == "ENABLED")
begin : ICACHE
    // Instruction cache
    altor32_icache 
    #(
        .BOOT_VECTOR(BOOT_VECTOR)
    )
    u_icache
    ( 
        .clk_i(clk_i),
        .rst_i(rst_i),
        
        // Processor interface
        .rd_i(icache_rd),
        .pc_i(icache_pc), 
        .instruction_o(icache_inst),
        .valid_o(icache_valid),
        .invalidate_i(icache_invalidate),
        
        // Status
        .miss_o(icache_miss),
        .busy_o(icache_busy),
        
        // Instruction memory
        .mem_addr_o(imem_addr_o),
        .mem_data_i(imem_data_in_i),
        .mem_burst_o(imem_burst_o),
        .mem_rd_o(imem_rd_o),
        .mem_accept_i(imem_accept_i),
        .mem_ack_i(imem_ack_i)
    );
end
else
begin
    // No instruction cache
    altor32_noicache 
    u_icache
    ( 
        .clk_i(clk_i),
        .rst_i(rst_i),
        
        // Processor interface
        .rd_i(icache_rd),
        .pc_i(icache_pc), 
        .instruction_o(icache_inst),
        .valid_o(icache_valid),
        
        // Instruction memory
        .mem_addr_o(imem_addr_o),
        .mem_data_i(imem_data_in_i),
        .mem_burst_o(imem_burst_o),
        .mem_rd_o(imem_rd_o),
        .mem_accept_i(imem_accept_i),
        .mem_ack_i(imem_ack_i)
    );
end
endgenerate   

// Instruction Fetch
altor32_fetch 
#(
    .BOOT_VECTOR(BOOT_VECTOR)
)
u_fetch
(
    // General
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    // Instruction memory
    .pc_o(icache_pc),
    .data_i(icache_inst),
    .fetch_o(icache_rd),
    .data_valid_i(icache_valid),
    
    // Fetched opcode
    .opcode_o(w_d_opcode),
    .opcode_pc_o(w_d_pc),
    .opcode_valid_o(w_d_valid),
    
    // Branch target
    .branch_i(w_e_branch),
    .branch_pc_i(w_e_branch_pc),    
    .stall_i(w_e_stall),

    // Decoded register details
    .ra_o(w_ra),
    .rb_o(w_rb),
    .rd_o(w_rd)
);

// Register file
generate
if (REGISTER_FILE_TYPE == "XILINX")
begin
    altor32_regfile_xil
    #(
        .SUPPORT_32REGS(SUPPORT_32REGS)
    )
    reg_bank
    (
        // Clocking
        .clk_i(clk_i),
        .rst_i(rst_i),
        .wr_i(w_wb_write_rd),

        // Tri-port
        .rs_i(w_ra),
        .rt_i(w_rb),
        .rd_i(w_wb_rd),
        .reg_rs_o(w_reg_ra),
        .reg_rt_o(w_reg_rb),
        .reg_rd_i(w_wb_reg_rd)
    );
end
else if (REGISTER_FILE_TYPE == "ALTERA")
begin
    altor32_regfile_alt
    #(
        .SUPPORT_32REGS(SUPPORT_32REGS)
    )    
    reg_bank
    (
        // Clocking
        .clk_i(clk_i),
        .rst_i(rst_i),
        .wr_i(w_wb_write_rd),

        // Tri-port
        .rs_i(w_ra),
        .rt_i(w_rb),
        .rd_i(w_wb_rd),
        .reg_rs_o(w_reg_ra),
        .reg_rt_o(w_reg_rb),
        .reg_rd_i(w_wb_reg_rd)
    );
end
else
begin
    altor32_regfile_sim
    #(
        .SUPPORT_32REGS(SUPPORT_32REGS)
    )
    reg_bank
    (
        // Clocking
        .clk_i(clk_i),
        .rst_i(rst_i),
        .wr_i(w_wb_write_rd),

        // Tri-port
        .rs_i(w_ra),
        .rt_i(w_rb),
        .rd_i(w_wb_rd),
        .reg_rs_o(w_reg_ra),
        .reg_rt_o(w_reg_rb),
        .reg_rd_i(w_wb_reg_rd)
    );
end
endgenerate

generate
if (ENABLE_DCACHE == "ENABLED")
begin
    // Data cache
    altor32_dcache 
    u_dcache
    ( 
        .clk_i(clk_i),
        .rst_i(rst_i),

        .flush_i(dcache_flush),
        
        // Processor interface
        .address_i({dcache_addr[31:2], 2'b00}),
        .data_o(dcache_data_i), 
        .data_i(dcache_data_o),
        .wr_i(dcache_wr),
        .rd_i(dcache_rd),
        .accept_o(dcache_accept),
        .ack_o(dcache_ack),
        
        // Memory interface (slave)
        .mem_addr_o(dmem_addr_o),
        .mem_data_i(dmem_data_in_i),
        .mem_data_o(dmem_data_out_o),
        .mem_burst_o(dmem_burst_o),
        .mem_rd_o(dmem_rd_o),
        .mem_wr_o(dmem_wr_o),
        .mem_accept_i(dmem_accept_i),
        .mem_ack_i(dmem_ack_i)
    );
end
else
begin

    // No data cache
    assign dmem_addr_o      = {dcache_addr[31:2], 2'b00};
    assign dmem_data_out_o  = dcache_data_o;
    assign dcache_data_i    = dmem_data_in_i;
    assign dmem_rd_o        = dcache_rd;
    assign dmem_wr_o        = dcache_wr;
    assign dmem_burst_o     = 1'b0;
    assign dcache_ack       = dmem_ack_i;
    assign dcache_accept    = dmem_accept_i;
end
endgenerate

// Execution unit
altor32_exec
#(
    .BOOT_VECTOR(BOOT_VECTOR),
    .ISR_VECTOR(ISR_VECTOR)
)
u_exec
(
    // General
    .clk_i(clk_i),
    .rst_i(rst_i),

    .intr_i(intr_i),
    .nmi_i(nmi_i),
    
    // Status
    .fault_o(fault_o),
    .break_o(break_o),
    
    // Cache control
    .icache_flush_o(icache_invalidate),
    .dcache_flush_o(dcache_flush),
    
    // Branch target
    .branch_o(w_e_branch),
    .branch_pc_o(w_e_branch_pc),
    .stall_o(w_e_stall),

    // Opcode & arguments
    .opcode_i(w_d_opcode),
    .opcode_pc_i(w_d_pc),
    .opcode_valid_i(w_d_valid),

    .reg_ra_i(w_ra),
    .reg_ra_value_i(w_reg_ra),

    .reg_rb_i(w_rb),
    .reg_rb_value_i(w_reg_rb),
    
    .reg_rd_i(w_rd),

    // Output
    .opcode_o(w_e_opcode),
    .reg_rd_o(w_e_rd),
    .reg_rd_value_o(w_e_result),
    .mult_o(w_e_mult),
    .mult_res_o(w_e_mult_result),

    // Register write back bypass
    .wb_rd_i(w_wb_rd),
    .wb_rd_value_i(w_wb_reg_rd),

    // Memory Interface
    .dmem_addr_o(dcache_addr),
    .dmem_data_out_o(dcache_data_o),
    .dmem_data_in_i(dcache_data_i),
    .dmem_wr_o(dcache_wr),
    .dmem_rd_o(dcache_rd),
    .dmem_accept_i(dcache_accept),
    .dmem_ack_i(dcache_ack)
);

// Register file writeback
altor32_writeback 
u_wb
(
    // General
    .clk_i(clk_i),
    .rst_i(rst_i),

    // Opcode
    .opcode_i(w_e_opcode),

    // Register target
    .rd_i(w_e_rd),
    
    // ALU result
    .alu_result_i(w_e_result),

    // Memory load result
    .mem_result_i(dcache_data_i),
    .mem_offset_i(dcache_addr[1:0]),
    .mem_ready_i(dcache_ack),

    // Multiplier result
    .mult_i(w_e_mult),
    .mult_result_i(w_e_mult_result),

    // Outputs
    .write_enable_o(w_wb_write_rd),
    .write_addr_o(w_wb_rd),
    .write_data_o(w_wb_reg_rd)
);

//-------------------------------------------------------------------
// Hooks for debug
//-------------------------------------------------------------------
`ifdef verilator
   function [31:0] get_pc;
      // verilator public
      get_pc = w_d_pc;
   endfunction
   function get_fault;
      // verilator public
      get_fault = fault_o;
   endfunction  
   function get_break;
      // verilator public
      get_break = break_o;
   endfunction   
`endif

endmodule
