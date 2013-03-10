//-----------------------------------------------------------------
//                           AltOR32 
//              Alternative Lightweight OpenRisc 
//                     Ultra-Embedded.com
//                   Copyright 2011 - 2013
//
//               Email: admin@ultra-embedded.com
//
//                       License: LGPL
//
// If you would like a version with a different license for use 
// in commercial projects please contact the above email address 
// for more details.
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

//-----------------------------------------------------------------
// Module - Altera LPM register file
//-----------------------------------------------------------------
module altor32_regfile_alt
(
    clk_i,
    rst_i,
    en_i,
    wr_i,
    rs_i,
    rt_i,
    rd_i,
    reg_rs_o,
    reg_rt_o,
    reg_rd_i
);

//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------
input           clk_i       /*verilator public*/;
input           rst_i       /*verilator public*/;
input           en_i        /*verilator public*/;
input           wr_i        /*verilator public*/;
input [4:0]     rs_i        /*verilator public*/;
input [4:0]     rt_i        /*verilator public*/;
input [4:0]     rd_i        /*verilator public*/;
output [31:0]   reg_rs_o    /*verilator public*/;
output [31:0]   reg_rt_o    /*verilator public*/;
input [31:0]    reg_rd_i    /*verilator public*/;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg             clk_delayed;
wire [31:0]     data_out1;
wire [31:0]     data_out2;
reg             write_enable;

reg [31:0]      reg_rs_o;
reg [31:0]      reg_rt_o;

reg [4:0]       addr_reg;
reg [31:0]      data_reg;

wire [31:0]     q1;
wire [31:0]     q2;

//-----------------------------------------------------------------
// Async Read Process
//-----------------------------------------------------------------
always @ (clk_i or rs_i or rt_i or rd_i or reg_rd_i or data_out1 or data_out2 or rst_i or wr_i)
begin
    // Read Rs
    if (rs_i == 5'b00000)
        reg_rs_o <= 32'h00000000;
    else
        reg_rs_o <= data_out1;

    // Read Rt
    if (rt_i == 5'b00000)
        reg_rt_o <= 32'h00000000;
    else
        reg_rt_o <= data_out2;

    // Write enabled?
    if ((rd_i != 5'b00000) & (wr_i == 1'b1))
        write_enable <= 1'b1;
    else
        write_enable <= 1'b0;
end

//-----------------------------------------------------------------
// Sync addr & data
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
begin
   if (rst_i)
   begin
        addr_reg <= 5'b00000;
        data_reg <= 32'h00000000;

   end
   else if (en_i == 1'b1)
   begin
        addr_reg <= rd_i;
        data_reg <= reg_rd_i;
   end
end

//-----------------------------------------------------------------
// Register File (using lpm_ram_dp)
// Unfortunatly, LPM_RAM_DP primitives have synchronous read ports.
// As this core requires asynchronous/non-registered read ports,
// we have to invert the readclock edge to get close to what we
// require.
// This will have negative timing implications!
//-----------------------------------------------------------------
lpm_ram_dp
#(
    .lpm_width(32),
    .lpm_widthad(5),
    .lpm_indata("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .lpm_rdaddress_control("REGISTERED"),
    .lpm_wraddress_control("REGISTERED"),
    .lpm_file("UNUSED"),
    .lpm_type("lpm_ram_dp"),
    .lpm_hint("UNUSED")
)
lpm1
(
    .rdclock(clk_delayed),
    .rdclken(1'b1),
    .rdaddress(rs_i),
    .rden(1'b1),
    .data(reg_rd_i),
    .wraddress(rd_i),
    .wren(write_enable),
    .wrclock(clk_i),
    .wrclken(1'b1),
    .q(q1)
);


lpm_ram_dp
#(
    .lpm_width(32),
    .lpm_widthad(5),
    .lpm_indata("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .lpm_rdaddress_control("REGISTERED"),
    .lpm_wraddress_control("REGISTERED"),
    .lpm_file("UNUSED"),
    .lpm_type("lpm_ram_dp"),
    .lpm_hint("UNUSED")
)
lpm2
(
    .rdclock(clk_delayed),
    .rdclken(1'b1),
    .rdaddress(rt_i),
    .rden(1'b1),
    .data(reg_rd_i),
    .wraddress(rd_i),
    .wren(write_enable),
    .wrclock(clk_i),
    .wrclken(1'b1),
    .q(q2)
);

//-----------------------------------------------------------------
// Combinatorial Assignments
//-----------------------------------------------------------------

// Delayed clock
assign clk_delayed  = !clk_i;

// Reads are bypassed during write-back
assign data_out1    = (rs_i != addr_reg) ? q1 : data_reg;
assign data_out2    = (rt_i != addr_reg) ? q2 : data_reg;

endmodule
