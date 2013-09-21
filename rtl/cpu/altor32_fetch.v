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

//`define CONF_FETCH_DEBUG

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "altor32_defs.v"

//-----------------------------------------------------------------
// Module - Instruction Fetch
//-----------------------------------------------------------------
module altor32_fetch
(
    // General
    input               clk_i /*verilator public*/,
    input               rst_i /*verilator public*/,

    // Instruction Fetch
    output              fetch_o /*verilator public*/,
    output [31:0]       pc_o /*verilator public*/,
    input [31:0]        data_i /*verilator public*/,
    input               data_valid_i/*verilator public*/,

    // Branch target
    input               branch_i /*verilator public*/,
    input [31:0]        branch_pc_i /*verilator public*/,
    input               stall_i /*verilator public*/,

    // Decoded opcode
    output [31:0]       opcode_o /*verilator public*/,
    output [31:0]       opcode_pc_o /*verilator public*/,
    output              opcode_valid_o /*verilator public*/,

    // Decoded register details
    output [4:0]        ra_o /*verilator public*/,
    output [4:0]        rb_o /*verilator public*/,
    output [4:0]        rd_o /*verilator public*/
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter           BOOT_VECTOR             = 32'h00000000;
parameter           CACHE_LINE_SIZE_WIDTH   = 5; /* 5-bits -> 32 entries */

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [31:0]  r_pc;
reg         r_rd;
reg [31:0]  r_last_opcode;
reg [31:0]  r_last_pc;
reg         r_last_valid;
reg [31:0]  d_pc;

//-------------------------------------------------------------------
// Next PC state machine
//-------------------------------------------------------------------
reg [31:0] v_pc;

always @ (posedge clk_i or posedge rst_i)
begin
   if (rst_i)
   begin
        r_pc        <= BOOT_VECTOR + `VECTOR_RESET;
        d_pc        <= BOOT_VECTOR + `VECTOR_RESET;
        r_rd        <= 1'b1;
   end
   else
   begin
        r_rd        <= 1'b0;
        d_pc        <= pc_o;

        // Branch - Next PC = branch target + 4
        if (branch_i)
        begin
            r_pc <= branch_pc_i + 4;
        end
        // Stall - rollback to previous PC + 4
        else if (stall_i)
        begin
            r_pc <= d_pc + 4;       
        end
        // Normal sequential execution (and instruction is ready)
        else if (data_valid_i)
        begin
            v_pc = r_pc + 4;

            // New cache line?
            if (v_pc[CACHE_LINE_SIZE_WIDTH-1:0] == {CACHE_LINE_SIZE_WIDTH{1'b0}})
            begin
                // Start fetch of next line
                r_rd  <= 1'b1;
            end

            r_pc <= v_pc;
        end
   end
end

//-------------------------------------------------------------------
// Pipeline storage of last PC/opcode passed to exec stage
//-------------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
begin
   if (rst_i)
   begin
        r_last_opcode   <= 32'b0;
        r_last_pc       <= 32'b0;
        r_last_valid    <= 1'b0;

   end
   else
   begin
        // Record last valid instruction passed to exec stage
        if (!stall_i | !data_valid_i)
        begin
            r_last_pc        <= opcode_pc_o;
            r_last_opcode    <= opcode_o;
            r_last_valid     <= opcode_valid_o;
        end        
   end
end

//-------------------------------------------------------------------
// Assignments
//-------------------------------------------------------------------

// Instruction Fetch
assign pc_o            = stall_i ? d_pc : (branch_i ? branch_pc_i : (~data_valid_i ? d_pc : r_pc));
assign fetch_o         = branch_i ? 1'b1 : r_rd;

// Opcode output
assign opcode_valid_o  = stall_i ? r_last_valid : (data_valid_i & !branch_i);
assign opcode_o        = stall_i ? r_last_opcode : (opcode_valid_o ? data_i : 32'b0);
assign opcode_pc_o     = stall_i ? r_last_pc : (opcode_valid_o ? d_pc : 32'b0);

// If simulation, RA = 03 if NOP instruction
`ifdef SIMULATION
    wire [7:0] v_fetch_inst = {2'b00, opcode_o[31:26]};
    wire       v_is_nop     = (v_fetch_inst == `INST_OR32_NOP);
    assign     ra_o         = v_is_nop ? 5'd3 : opcode_o[20:16];
`else
    assign     ra_o         = opcode_o[20:16];
`endif

assign rb_o            = opcode_o[15:11];
assign rd_o            = opcode_o[25:21];

endmodule
