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
// Module
//-----------------------------------------------------------------
module top
( 
    // Clocking & Reset
    input clk_i, 
    input rst_i, 
    // Fault Output
    output fault_o,
    // Break Output 
    output break_o,
    // Interrupt Input
    input intr_i
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter           CLK_KHZ              = 8192;
parameter           BOOT_VECTOR          = 32'h10000000;
parameter           ISR_VECTOR           = 32'h10000000;

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
wire [31:0]         soc_addr;
wire [31:0]         soc_data_w;
wire [31:0]         soc_data_r;
wire [3:0]          soc_wr;
wire                soc_rd;
wire                soc_irq;

wire[31:0]          dmem_address;
wire[31:0]          dmem_data_w;
wire[31:0]          dmem_data_r;
wire[3:0]           dmem_wr;
wire                dmem_rd;
wire                dmem_burst;
wire                dmem_ack;
reg                 dmem_req_r;

wire[31:0]          imem_addr;
wire[31:0]          imem_data;
wire                imem_rd;
wire                imem_burst;
wire                imem_ack;
reg                 imem_req_r;

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------

// BlockRAM
ram  
#(
    .block_count(128) // 1MB
) 
u_ram
(
    .clka_i(clk_i), 
    .ena_i(1'b1), 
    .wea_i(4'b0), 
    .addra_i(imem_addr[31:2]), 
    .dataa_i(32'b0),
    .dataa_o(imem_data),

    .clkb_i(clk_i), 
    .enb_i(1'b1), 
    .web_i(dmem_wr), 
    .addrb_i(dmem_address[31:2]), 
    .datab_i(dmem_data_w),
    .datab_o(dmem_data_r)    
);


// CPU
cpu_if
#(
    .CLK_KHZ(CLK_KHZ),
    .BOOT_VECTOR(32'h10000000),
    .ISR_VECTOR(32'h10000000),
    .ENABLE_ICACHE("ENABLED"),
    .ENABLE_DCACHE("ENABLED"),
    .REGISTER_FILE_TYPE("SIMULATION")
)
u_cpu
(
    // General - clocking & reset
    .clk_i(clk_i),
    .rst_i(rst_i),
    .fault_o(fault_o),
    .break_o(break_o),
    .nmi_i(1'b0),
    .intr_i(soc_irq),

    // Instruction Memory 0 (0x10000000 - 0x10FFFFFF)
    .imem0_addr_o(imem_addr),
    .imem0_rd_o(imem_rd),
    .imem0_burst_o(imem_burst),
    .imem0_data_in_i(imem_data),
    .imem0_accept_i(1'b1),
    .imem0_ack_i(imem_ack),

    // Data Memory 0 (0x10000000 - 0x10FFFFFF)
    .dmem0_addr_o(dmem_address),
    .dmem0_data_o(dmem_data_w),
    .dmem0_data_i(dmem_data_r),
    .dmem0_wr_o(dmem_wr),
    .dmem0_rd_o(dmem_rd),
    .dmem0_accept_i(1'b1),
    .dmem0_burst_o(dmem_burst),
    .dmem0_ack_i(dmem_ack),
       
    // Data Memory 1 (0x11000000 - 0x11FFFFFF)
    .dmem1_addr_o(),
    .dmem1_data_o(),
    .dmem1_data_i(32'b0),
    .dmem1_wr_o(),
    .dmem1_rd_o(),
    .dmem1_accept_i(1'b1),
    .dmem1_burst_o(/*open*/),
    .dmem1_ack_i(1'b1),

    // Data Memory 2 (0x12000000 - 0x12FFFFFF)
    .dmem2_addr_o(soc_addr),
    .dmem2_data_o(soc_data_w),
    .dmem2_data_i(soc_data_r),
    .dmem2_wr_o(soc_wr),
    .dmem2_rd_o(soc_rd),
    .dmem2_accept_i(1'b1),
    .dmem2_burst_o(/*open*/),
    .dmem2_ack_i(1'b1)
);

// CPU SOC
soc
#(
    .CLK_KHZ(CLK_KHZ),
    .ENABLE_SYSTICK_TIMER("ENABLED"),
    .ENABLE_HIGHRES_TIMER("ENABLED"),
    .EXTERNAL_INTERRUPTS(1)
)
u_soc
(
    // General - clocking & reset
    .clk_i(clk_i),
    .rst_i(rst_i),
    .ext_intr_i(1'b0),
    .intr_o(soc_irq),

    // Memory Port
    .io_addr_i(soc_addr),    
    .io_data_i(soc_data_w),
    .io_data_o(soc_data_r),    
    .io_wr_i(soc_wr),
    .io_rd_i(soc_rd)
);

// Ack
always @(posedge clk_i or posedge rst_i) 
begin
    if (rst_i == 1'b1) 
    begin
        imem_req_r  <= 1'b0;
    end 
    else 
    begin
        imem_req_r  <= imem_rd;
    end
end

assign imem_ack = imem_req_r;

// Ack
always @(posedge clk_i or posedge rst_i) 
begin
    if (rst_i == 1'b1) 
    begin
        dmem_req_r  <= 1'b0;
    end 
    else 
    begin
        dmem_req_r  <= dmem_rd | (|dmem_wr);
    end
end

assign dmem_ack = dmem_req_r;
    
endmodule
