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
// Module - Writeback
//-----------------------------------------------------------------
module altor32_writeback
(
    // General
    input               clk_i /*verilator public*/,
    input               rst_i /*verilator public*/,

    // Opcode
    input [31:0]        opcode_i /*verilator public*/,

    // Register target
    input [4:0]         rd_i /*verilator public*/,

    // ALU result
    input [31:0]        alu_result_i /*verilator public*/,

    // Memory load result
    input [31:0]        mem_result_i /*verilator public*/,
    input [1:0]         mem_offset_i /*verilator public*/,
    input               mem_ready_i /*verilator public*/,

    // Multiplier result
    input               mult_i /*verilator public*/,
    input [31:0]        mult_result_i /*verilator public*/,

    // Outputs
    output              write_enable_o /*verilator public*/,
    output [4:0]        write_addr_o /*verilator public*/,
    output [31:0]       write_data_o /*verilator public*/
);

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------

// Register address
reg [4:0]  r_w_rd;

// Register writeback value
reg [31:0] r_result;

reg [7:0]  r_opcode;

// Register writeback enable
reg        r_w_write_rd;

//-------------------------------------------------------------------
// Writeback
//-------------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
begin
   if (rst_i == 1'b1)
   begin
       r_w_write_rd <= 1'b1;
       r_result     <= 32'h00000000;
       r_w_rd       <= 5'b00000;
       r_opcode     <= 8'b0;
   end
   else
   begin
        r_w_write_rd    <= 1'b0;

        r_w_rd          <= rd_i;
        r_result        <= alu_result_i;

        r_opcode        <= {2'b00,opcode_i[31:26]};     
        
        // Register writeback required?
        if (rd_i != 5'b00000)
            r_w_write_rd <= 1'b1;
   end
end

//-------------------------------------------------------------------
// Load result resolve
//-------------------------------------------------------------------
wire            load_insn;
wire [31:0]     load_result;

altor32_lfu
u_lfu
(
    // Opcode
    .opcode_i(r_opcode),

    // Memory load result
    .mem_result_i(mem_result_i),
    .mem_offset_i(mem_offset_i),

    // Result
    .load_result_o(load_result),
    .load_insn_o(load_insn)
);

//-------------------------------------------------------------------
// Assignments
//-------------------------------------------------------------------
assign write_enable_o = load_insn ? (r_w_write_rd & mem_ready_i) : r_w_write_rd;
assign write_data_o   = load_insn ? load_result : (mult_i ? mult_result_i : r_result);
assign write_addr_o   = r_w_rd;

endmodule
