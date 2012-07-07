//-----------------------------------------------------------------
//                           AltOR32 
//              Alternative Lightweight OpenRisc 
//                            V0.1
//                     Ultra-Embedded.com
//                   Copyright 2011 - 2012
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
// Copyright (C) 2011 - 2012 Ultra-Embedded.com
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
`include "alt_soc_defs.v"
`include "alt_soc_conf.v"

//-----------------------------------------------------------------
// Module:
//-----------------------------------------------------------------
module alt_soc 
( 
    // General - Clocking & Reset
    clk_i, 
    rst_i, 
    en_i, 
    ext_intr_i, 
    fault_o,
    break_o,
    
    // UART
    uart_tx_o, 
    uart_rx_i, 
    
    // BootRAM
    int_mem_addr_o, 
    int_mem_data_o, 
    int_mem_data_i, 
    int_mem_wr_o, 
    int_mem_rd_o, 
    int_mem_pause_i, 
    
    // External IO
    ext_io_addr_o, 
    ext_io_data_o, 
    ext_io_data_i, 
    ext_io_wr_o, 
    ext_io_rd_o, 
    ext_io_pause_i, 
        
    // SPI Flash
    flash_cs_o, 
    flash_si_o, 
    flash_so_i, 
    flash_sck_o,       

    // Debug Status
    dbg_pc_o, 
    
    // Debug UART output
    dbg_uart_data_o, 
    dbg_uart_wr_o    
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter  [31:0]   CLK_KHZ             = 12288;
parameter  [31:0]   UART_BAUD           = 115200;
parameter  [31:0]   SPI_FLASH_CLK_KHZ   = (12288/2);
parameter  [31:0]   EXTERNAL_INTERRUPTS = 1;
parameter           CORE_ID             = 0;
parameter           BOOT_VECTOR         = 0;
parameter           ISR_VECTOR          = 0;
    
//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------     
input               clk_i /*verilator public*/;
input               rst_i /*verilator public*/;
input               en_i /*verilator public*/;
output              fault_o /*verilator public*/;
output              break_o /*verilator public*/;
input [(EXTERNAL_INTERRUPTS - 1):0]  ext_intr_i /*verilator public*/;
output              uart_tx_o /*verilator public*/;
input               uart_rx_i /*verilator public*/;
output [31:0]       int_mem_addr_o /*verilator public*/;
output [31:0]       int_mem_data_o /*verilator public*/;
input [31:0]        int_mem_data_i /*verilator public*/;
output [3:0]        int_mem_wr_o /*verilator public*/;
output              int_mem_rd_o /*verilator public*/;
input               int_mem_pause_i /*verilator public*/;
output [31:0]       ext_io_addr_o /*verilator public*/;
output [31:0]       ext_io_data_o /*verilator public*/;
input [31:0]        ext_io_data_i /*verilator public*/;
output [3:0]        ext_io_wr_o /*verilator public*/;
output              ext_io_rd_o /*verilator public*/;
input               ext_io_pause_i /*verilator public*/;
output              flash_cs_o /*verilator public*/;
output              flash_si_o /*verilator public*/;
input               flash_so_i /*verilator public*/;
output              flash_sck_o /*verilator public*/;
output [31:0]       dbg_pc_o /*verilator public*/;
output [7:0]        dbg_uart_data_o /*verilator public*/;
output              dbg_uart_wr_o /*verilator public*/;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [31:0]          v_irq_status;
reg [2:0]           r_mem_sel;
wire [31:0]         cpu_address;
wire [3:0]          cpu_byte_we;
wire                cpu_oe;
wire [31:0]         cpu_data_w;
reg [31:0]          cpu_data_r;
reg                 cpu_pause;

reg [31:0]          io_address;
reg [31:0]          io_data_w;
wire [31:0]         io_data_r;
reg [3:0]           io_wr;
reg                 io_rd;

// IRQ Status
wire                intr_in;

// Output Signals
wire                uart_tx_o;
reg [31:0]          int_mem_addr_o;
reg [31:0]          int_mem_data_o;
reg [3:0]           int_mem_wr_o;
reg                 int_mem_rd_o;
reg [31:0]          ext_io_addr_o;
reg [31:0]          ext_io_data_o;
reg [3:0]           ext_io_wr_o;
reg                 ext_io_rd_o;
wire                flash_cs_o;
wire                flash_si_o;
wire                flash_sck_o;

// Peripheral Interface
wire [7:0]         uart_addr;
wire [31:0]        uart_data_o;
wire [31:0]        uart_data_i;
wire [3:0]         uart_wr;
wire               uart_rd;
wire               uart_intr;

wire [7:0]         spi_addr;
wire [31:0]        spi_data_o;
wire [31:0]        spi_data_i;
wire [3:0]         spi_wr;
wire               spi_rd;

wire [7:0]         timer_addr;
wire [31:0]        timer_data_o;
wire [31:0]        timer_data_i;
wire [3:0]         timer_wr;
wire               timer_rd;
wire               timer_intr_systick;
wire               timer_intr_hires;

wire [7:0]         intr_addr;
wire [31:0]        intr_data_o;
wire [31:0]        intr_data_i;
wire [3:0]         intr_wr;
wire               intr_rd;

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------  

// MPX CPU   
altor32  
u1_cpu
(
    .clk_i(clk_i), 
    .rst_i(rst_i), 
    .en_i(en_i), 
    .intr_i(intr_in), 
    .fault_o(fault_o), 
    .break_o(break_o), 
    .mem_addr_o(cpu_address), 
    .mem_data_out_o(cpu_data_w), 
    .mem_data_in_i(cpu_data_r), 
    .mem_wr_o(cpu_byte_we), 
    .mem_rd_o(cpu_oe), 
    .mem_pause_i(cpu_pause), 
    .dbg_pc_o(dbg_pc_o)
);

// Peripheral Interconnect
soc_pif  
u2_soc
( 
    // General - Clocking & Reset
    .clk_i(clk_i), 
    .rst_i(rst_i), 

    // I/O bus
    .io_addr_i(io_address), 
    .io_data_i(io_data_w), 
    .io_data_o(io_data_r), 
    .io_wr_i(io_wr), 
    .io_rd_i(io_rd), 
    
    // Peripherals      
    .periph0_addr_o(uart_addr), 
    .periph0_data_o(uart_data_o), 
    .periph0_data_i(uart_data_i), 
    .periph0_wr_o(uart_wr), 
    .periph0_rd_o(uart_rd),   
    
    .periph1_addr_o(timer_addr), 
    .periph1_data_o(timer_data_o), 
    .periph1_data_i(timer_data_i), 
    .periph1_wr_o(timer_wr), 
    .periph1_rd_o(timer_rd),     
    
    .periph2_addr_o(intr_addr), 
    .periph2_data_o(intr_data_o), 
    .periph2_data_i(intr_data_i), 
    .periph2_wr_o(intr_wr), 
    .periph2_rd_o(intr_rd),         
    
`ifdef SOC_CONF_ENABLE_SPI_FLASH    
    .periph3_addr_o(spi_addr), 
    .periph3_data_o(spi_data_o), 
    .periph3_data_i(spi_data_i), 
    .periph3_wr_o(spi_wr), 
    .periph3_rd_o(spi_rd),   
`else
    .periph3_addr_o(/*open*/), 
    .periph3_data_o(/*open*/), 
    .periph3_data_i(32'h00000000), 
    .periph3_wr_o(/*open*/), 
    .periph3_rd_o(/*open*/), 
`endif    
    
    .periph4_addr_o(/*open*/), 
    .periph4_data_o(/*open*/), 
    .periph4_data_i(32'h00000000), 
    .periph4_wr_o(/*open*/), 
    .periph4_rd_o(/*open*/), 
    
    .periph5_addr_o(/*open*/), 
    .periph5_data_o(/*open*/), 
    .periph5_data_i(32'h00000000), 
    .periph5_wr_o(/*open*/), 
    .periph5_rd_o(/*open*/), 
    
    .periph6_addr_o(/*open*/), 
    .periph6_data_o(/*open*/), 
    .periph6_data_i(32'h00000000), 
    .periph6_wr_o(/*open*/), 
    .periph6_rd_o(/*open*/), 
    
    .periph7_addr_o(/*open*/), 
    .periph7_data_o(/*open*/), 
    .periph7_data_i(32'h00000000), 
    .periph7_wr_o(/*open*/), 
    .periph7_rd_o(/*open*/)                            
);

// UART
uart_periph  
#(
    .UART_DIVISOR(((CLK_KHZ * 1000) / UART_BAUD))
) 
u3_uart
(
    .clk_i(clk_i), 
    .rst_i(rst_i), 
    .intr_o(uart_intr),
    .addr_i(uart_addr), 
    .data_o(uart_data_i), 
    .data_i(uart_data_o), 
    .wr_i(uart_wr), 
    .rd_i(uart_rd),
    .rx_i(uart_rx_i), 
    .tx_o(uart_tx_o)
);

`ifdef SOC_CONF_ENABLE_SPI_FLASH
    // SPI Flash Master
    spim_periph  
    #(
        .CLK_DIV(CLK_KHZ / SPI_FLASH_CLK_KHZ)
    ) 
    u4_spi_flash
    (
        // Clocking / Reset
        .clk_i(clk_i), 
        .rst_i(rst_i), 
        .intr_o(/*open*/),
        // Peripheral I/O
        .addr_i(spi_addr), 
        .data_o(spi_data_i), 
        .data_i(spi_data_o), 
        .wr_i(spi_wr), 
        .rd_i(spi_rd),         
        // SPI interface
        .spi_clk_o(flash_sck_o), 
        .spi_ss_o(flash_cs_o), 
        .spi_mosi_o(flash_si_o), 
        .spi_miso_i(flash_so_i)
    );
`else
    // SPI Flash Disabled
    assign flash_cs_o   = 1'b1;
    assign flash_si_o   = 1'b0;
    assign flash_sck_o  = 1'b0;
`endif

timer_periph  
#(
    .CLK_KHZ(CLK_KHZ)
) 
u5_timer
(
    .clk_i(clk_i), 
    .rst_i(rst_i), 
    .intr_systick_o(timer_intr_systick),
    .intr_hires_o(timer_intr_hires),
    .addr_i(timer_addr), 
    .data_o(timer_data_i), 
    .data_i(timer_data_o), 
    .wr_i(timer_wr), 
    .rd_i(timer_rd)
);

intr_periph  
#(
    .EXTERNAL_INTERRUPTS(EXTERNAL_INTERRUPTS)
) 
u6_intr
(
    .clk_i(clk_i), 
    .rst_i(rst_i), 
    .intr_o(intr_in),
    
    .intr0_i(uart_intr),
    .intr1_i(timer_intr_systick),
    .intr2_i(timer_intr_hires),
    .intr3_i(/*open*/),
    .intr4_i(/*open*/),
    .intr5_i(/*open*/),
    .intr6_i(/*open*/),
    .intr7_i(/*open*/),
    .intr_ext_i(ext_intr_i),
    
    .addr_i(intr_addr), 
    .data_o(intr_data_i), 
    .data_i(intr_data_o), 
    .wr_i(intr_wr), 
    .rd_i(intr_rd)
);

//-----------------------------------------------------------------
// Memory Map
//-----------------------------------------------------------------   
always @ (cpu_address or cpu_byte_we or cpu_oe or cpu_data_w )
begin 
   case (cpu_address[30:28])
   
   // Block RAM
   `MEM_REGION_INTERNAL : 
   begin 
       int_mem_addr_o       = cpu_address;
       int_mem_wr_o         = cpu_byte_we;
       int_mem_rd_o         = cpu_oe;
       int_mem_data_o       = cpu_data_w;
       
       io_address           = 32'h00000000;
       io_wr                = 4'b0000;
       io_rd                = 1'b0;
       io_data_w            = 32'h00000000;
       
       ext_io_addr_o        = 32'h00000000;
       ext_io_wr_o          = 4'b0000;
       ext_io_rd_o          = 1'b0;
       ext_io_data_o        = 32'h00000000;
   end
   
   // Core I/O peripherals
   `MEM_REGION_CORE_IO : 
   begin 
       io_address           = cpu_address;
       io_wr                = cpu_byte_we;
       io_rd                = cpu_oe;
       io_data_w            = cpu_data_w;
       
       int_mem_addr_o       = 32'h00000000;
       int_mem_wr_o         = 4'b0000;
       int_mem_rd_o         = 1'b0;
       int_mem_data_o       = 32'h00000000;
       
       ext_io_addr_o        = 32'h00000000;
       ext_io_wr_o          = 4'b0000;
       ext_io_rd_o          = 1'b0;
       ext_io_data_o        = 32'h00000000;
   end
   
   // Extended I/O peripherals   
   `MEM_REGION_EXT_IO : 
   begin 
       ext_io_addr_o        = cpu_address;
       ext_io_wr_o          = cpu_byte_we;
       ext_io_rd_o          = cpu_oe;
       ext_io_data_o        = cpu_data_w;
       
       int_mem_addr_o       = 32'h00000000;
       int_mem_wr_o         = 4'b0000;
       int_mem_rd_o         = 1'b0;
       int_mem_data_o       = 32'h00000000;
       
       io_address           = 32'h00000000;
       io_wr                = 4'b0000;
       io_rd                = 1'b0;
       io_data_w            = 32'h00000000;
   end
      
   default : 
   begin 
       io_address           = 32'h00000000;
       io_wr                = 4'b0000;
       io_rd                = 1'b0;
       io_data_w            = 32'h00000000;
       
       int_mem_addr_o       = 32'h00000000;
       int_mem_wr_o         = 4'b0000;
       int_mem_rd_o         = 1'b0;
       int_mem_data_o       = 32'h00000000;
       
       ext_io_addr_o        = 32'h00000000;
       ext_io_wr_o          = 4'b0000;
       ext_io_rd_o          = 1'b0;
       ext_io_data_o        = 32'h00000000;
   end
   endcase
end
   
//-----------------------------------------------------------------
// Read Port
//-----------------------------------------------------------------   
always @ (r_mem_sel or int_mem_data_i or io_data_r or ext_io_data_i or int_mem_pause_i or ext_io_pause_i)
begin 
   case (r_mem_sel)
   
   // Block RAM
   `MEM_REGION_INTERNAL : 
   begin 
       cpu_data_r   = int_mem_data_i;
       cpu_pause    = int_mem_pause_i;
   end
     
   // Core I/O peripherals
   `MEM_REGION_CORE_IO : 
   begin 
       cpu_data_r   = io_data_r;
       cpu_pause    = 1'b0;
   end
   
   // Extended I/O peripherals
   `MEM_REGION_EXT_IO : 
   begin 
       cpu_data_r   = ext_io_data_i;
       cpu_pause    = ext_io_pause_i;
   end
   
   default : 
   begin 
       cpu_data_r   = 32'h00000000;
       cpu_pause    = 1'b0;
   end
   endcase
end
   
//-----------------------------------------------------------------
// Registered device select
//----------------------------------------------------------------- 
reg [31:0] v_mem_sel;
  
always @ (posedge clk_i or posedge rst_i )
begin
   if (rst_i == 1'b1)
   begin 
       v_mem_sel = BOOT_VECTOR;
       r_mem_sel <= v_mem_sel[30:28];
   end
   else 
       r_mem_sel <= cpu_address[30:28];
end
   
//-----------------------------------------------------------------
// External Interface
//-----------------------------------------------------------------  
// Debug UART
assign dbg_uart_data_o  = uart_data_o[7:0];
assign dbg_uart_wr_o    = (uart_wr != 4'b0000) ? 1'b1 : 1'b0;

endmodule
