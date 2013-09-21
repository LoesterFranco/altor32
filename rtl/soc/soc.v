
//-----------------------------------------------------------------
// Module:
//-----------------------------------------------------------------
module soc
(
    // General - Clocking & Reset
    clk_i,
    rst_i,
    ext_intr_i,
    intr_o,









    // Memory interface
    io_addr_i,
    io_data_i,
    io_data_o,
    io_wr_i,
    io_rd_i    
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter  [31:0]   CLK_KHZ              = 12288;
parameter  [31:0]   UART_BAUD            = 115200;
parameter  [31:0]   SPI_FLASH_CLK_KHZ    = (12288/2);
parameter           SD_CLK_KHZ           = 8000;
parameter  [31:0]   EXTERNAL_INTERRUPTS  = 1;
parameter           SYSTICK_INTR_MS      = 1;
parameter           ENABLE_SYSTICK_TIMER = "ENABLED";
parameter           ENABLE_HIGHRES_TIMER = "ENABLED";

//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------
input                   clk_i /*verilator public*/;
input                   rst_i /*verilator public*/;
input [(EXTERNAL_INTERRUPTS - 1):0]  ext_intr_i /*verilator public*/;
output                  intr_o /*verilator public*/;


// Memory Port
input [31:0]            io_addr_i /*verilator public*/;
input [31:0]            io_data_i /*verilator public*/;
output [31:0]           io_data_o /*verilator public*/;
input [3:0]             io_wr_i /*verilator public*/;
input                   io_rd_i /*verilator public*/;








//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------








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
// Peripheral Interconnect
//-----------------------------------------------------------------
soc_pif8
u2_soc
(
    // General - Clocking & Reset
    .clk_i(clk_i),
    .rst_i(rst_i),

    // I/O bus (from mem_mux)
    // 0x12000000 - 0x12FFFFFF
    .io_addr_i(io_addr_i),
    .io_data_i(io_data_i),
    .io_data_o(io_data_o),
    .io_wr_i(io_wr_i),
    .io_rd_i(io_rd_i),

    // Peripherals
    // Unused = 0x12000000 - 0x120000FF
    .periph0_addr_o(/*open*/),
    .periph0_data_o(/*open*/),
    .periph0_data_i(32'h00000000),
    .periph0_wr_o(/*open*/),
    .periph0_rd_o(/*open*/),

    // Timer = 0x12000100 - 0x120001FF
    .periph1_addr_o(timer_addr),
    .periph1_data_o(timer_data_o),
    .periph1_data_i(timer_data_i),
    .periph1_wr_o(timer_wr),
    .periph1_rd_o(timer_rd),

    // Interrupt Controller = 0x12000200 - 0x120002FF
    .periph2_addr_o(intr_addr),
    .periph2_data_o(intr_data_o),
    .periph2_data_i(intr_data_i),
    .periph2_wr_o(intr_wr),
    .periph2_rd_o(intr_rd),

    // Unused = 0x12000300 - 0x120003FF
    .periph3_addr_o(/*open*/),
    .periph3_data_o(/*open*/),
    .periph3_data_i(32'h00000000),
    .periph3_wr_o(/*open*/),
    .periph3_rd_o(/*open*/),

    // Unused = 0x12000400 - 0x120004FF
    .periph4_addr_o(/*open*/),
    .periph4_data_o(/*open*/),
    .periph4_data_i(32'h00000000),
    .periph4_wr_o(/*open*/),
    .periph4_rd_o(/*open*/),

    // Unused = 0x12000500 - 0x120005FF
    .periph5_addr_o(/*open*/),
    .periph5_data_o(/*open*/),
    .periph5_data_i(32'h00000000),
    .periph5_wr_o(/*open*/),
    .periph5_rd_o(/*open*/),

    // Unused = 0x12000600 - 0x120006FF
    .periph6_addr_o(/*open*/),
    .periph6_data_o(/*open*/),
    .periph6_data_i(32'h00000000),
    .periph6_wr_o(/*open*/),
    .periph6_rd_o(/*open*/),

    // Unused = 0x12000700 - 0x120007FF
    .periph7_addr_o(/*open*/),
    .periph7_data_o(/*open*/),
    .periph7_data_i(32'h00000000),
    .periph7_wr_o(/*open*/),
    .periph7_rd_o(/*open*/)
);

//-----------------------------------------------------------------
// Memory master arbiter
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// UART
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// GPIO
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// SPI Flash Master
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// DMA
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// SD
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// Generic Register
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// Timer
//-----------------------------------------------------------------
timer_periph
#(
    .CLK_KHZ(CLK_KHZ),
    .SYSTICK_INTR_MS(SYSTICK_INTR_MS),
    .ENABLE_SYSTICK_TIMER(ENABLE_SYSTICK_TIMER),
    .ENABLE_HIGHRES_TIMER(ENABLE_HIGHRES_TIMER)
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

//-----------------------------------------------------------------
// Interrupt Controller
//-----------------------------------------------------------------
intr_periph
#(
    .EXTERNAL_INTERRUPTS(EXTERNAL_INTERRUPTS)
)
u6_intr
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .intr_o(intr_o),

    .intr0_i(1'b0),

    .intr1_i(timer_intr_systick),
    .intr2_i(timer_intr_hires),
    .intr3_i(1'b0),

    .intr4_i(1'b0),

    .intr5_i(1'b0),

    .intr6_i(1'b0),

    .intr7_i(1'b0),
    .intr_ext_i(ext_intr_i),

    .addr_i(intr_addr),
    .data_o(intr_data_i),
    .data_i(intr_data_o),
    .wr_i(intr_wr),
    .rd_i(intr_rd)
);

//-------------------------------------------------------------------
// Hooks for debug
//-------------------------------------------------------------------
`ifdef verilator
   function [0:0] get_uart_wr;
      // verilator public
      get_uart_wr = 1'b0;
   endfunction
   
   function [7:0] get_uart_data;
      // verilator public
      get_uart_data = 8'b0;
   endfunction
`endif

endmodule
