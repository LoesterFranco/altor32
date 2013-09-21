
//-----------------------------------------------------------------
// Module:
//-----------------------------------------------------------------
module soc_pif8
(
    // General - Clocking & Reset
    clk_i,
    rst_i,

    // Peripherals
    periph0_addr_o,
    periph0_data_o,
    periph0_data_i,
    periph0_wr_o,
    periph0_rd_o,
    periph1_addr_o,
    periph1_data_o,
    periph1_data_i,
    periph1_wr_o,
    periph1_rd_o,
    periph2_addr_o,
    periph2_data_o,
    periph2_data_i,
    periph2_wr_o,
    periph2_rd_o,
    periph3_addr_o,
    periph3_data_o,
    periph3_data_i,
    periph3_wr_o,
    periph3_rd_o,
    periph4_addr_o,
    periph4_data_o,
    periph4_data_i,
    periph4_wr_o,
    periph4_rd_o,
    periph5_addr_o,
    periph5_data_o,
    periph5_data_i,
    periph5_wr_o,
    periph5_rd_o,
    periph6_addr_o,
    periph6_data_o,
    periph6_data_i,
    periph6_wr_o,
    periph6_rd_o,
    periph7_addr_o,
    periph7_data_o,
    periph7_data_i,
    periph7_wr_o,
    periph7_rd_o,

    // I/O bus
    io_addr_i,
    io_data_i,
    io_data_o,
    io_wr_i,
    io_rd_i
);

//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------
input               clk_i /*verilator public*/;
input               rst_i /*verilator public*/;

input [31:0]        io_addr_i /*verilator public*/;
output [31:0]       io_data_o /*verilator public*/;
input [31:0]        io_data_i /*verilator public*/;
input [3:0]         io_wr_i /*verilator public*/;
input               io_rd_i /*verilator public*/;

output [7:0]        periph0_addr_o /*verilator public*/;
output [31:0]       periph0_data_o /*verilator public*/;
input [31:0]        periph0_data_i /*verilator public*/;
output [3:0]        periph0_wr_o /*verilator public*/;
output              periph0_rd_o /*verilator public*/;
output [7:0]        periph1_addr_o /*verilator public*/;
output [31:0]       periph1_data_o /*verilator public*/;
input [31:0]        periph1_data_i /*verilator public*/;
output [3:0]        periph1_wr_o /*verilator public*/;
output              periph1_rd_o /*verilator public*/;
output [7:0]        periph2_addr_o /*verilator public*/;
output [31:0]       periph2_data_o /*verilator public*/;
input [31:0]        periph2_data_i /*verilator public*/;
output [3:0]        periph2_wr_o /*verilator public*/;
output              periph2_rd_o /*verilator public*/;
output [7:0]        periph3_addr_o /*verilator public*/;
output [31:0]       periph3_data_o /*verilator public*/;
input [31:0]        periph3_data_i /*verilator public*/;
output [3:0]        periph3_wr_o /*verilator public*/;
output              periph3_rd_o /*verilator public*/;
output [7:0]        periph4_addr_o /*verilator public*/;
output [31:0]       periph4_data_o /*verilator public*/;
input [31:0]        periph4_data_i /*verilator public*/;
output [3:0]        periph4_wr_o /*verilator public*/;
output              periph4_rd_o /*verilator public*/;
output [7:0]        periph5_addr_o /*verilator public*/;
output [31:0]       periph5_data_o /*verilator public*/;
input [31:0]        periph5_data_i /*verilator public*/;
output [3:0]        periph5_wr_o /*verilator public*/;
output              periph5_rd_o /*verilator public*/;
output [7:0]        periph6_addr_o /*verilator public*/;
output [31:0]       periph6_data_o /*verilator public*/;
input [31:0]        periph6_data_i /*verilator public*/;
output [3:0]        periph6_wr_o /*verilator public*/;
output              periph6_rd_o /*verilator public*/;
output [7:0]        periph7_addr_o /*verilator public*/;
output [31:0]       periph7_data_o /*verilator public*/;
input [31:0]        periph7_data_i /*verilator public*/;
output [3:0]        periph7_wr_o /*verilator public*/;
output              periph7_rd_o /*verilator public*/;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [3:0]           r_mem_sel;

reg [31:0]          io_data_o;

reg [7:0]           periph0_addr_o;
reg [31:0]          periph0_data_o;
reg [3:0]           periph0_wr_o;
reg                 periph0_rd_o;
reg [7:0]           periph1_addr_o;
reg [31:0]          periph1_data_o;
reg [3:0]           periph1_wr_o;
reg                 periph1_rd_o;
reg [7:0]           periph2_addr_o;
reg [31:0]          periph2_data_o;
reg [3:0]           periph2_wr_o;
reg                 periph2_rd_o;
reg [7:0]           periph3_addr_o;
reg [31:0]          periph3_data_o;
reg [3:0]           periph3_wr_o;
reg                 periph3_rd_o;
reg [7:0]           periph4_addr_o;
reg [31:0]          periph4_data_o;
reg [3:0]           periph4_wr_o;
reg                 periph4_rd_o;
reg [7:0]           periph5_addr_o;
reg [31:0]          periph5_data_o;
reg [3:0]           periph5_wr_o;
reg                 periph5_rd_o;
reg [7:0]           periph6_addr_o;
reg [31:0]          periph6_data_o;
reg [3:0]           periph6_wr_o;
reg                 periph6_rd_o;
reg [7:0]           periph7_addr_o;
reg [31:0]          periph7_data_o;
reg [3:0]           periph7_wr_o;
reg                 periph7_rd_o;

//-----------------------------------------------------------------
// Memory Map
//-----------------------------------------------------------------
always @ (io_addr_i or io_wr_i or io_rd_i or io_data_i)
begin

   periph0_addr_o       = 8'h00;
   periph0_wr_o         = 4'b0000;
   periph0_rd_o         = 1'b0;
   periph0_data_o       = 32'h00000000;
   periph1_addr_o       = 8'h00;
   periph1_wr_o         = 4'b0000;
   periph1_rd_o         = 1'b0;
   periph1_data_o       = 32'h00000000;
   periph2_addr_o       = 8'h00;
   periph2_wr_o         = 4'b0000;
   periph2_rd_o         = 1'b0;
   periph2_data_o       = 32'h00000000;
   periph3_addr_o       = 8'h00;
   periph3_wr_o         = 4'b0000;
   periph3_rd_o         = 1'b0;
   periph3_data_o       = 32'h00000000;
   periph4_addr_o       = 8'h00;
   periph4_wr_o         = 4'b0000;
   periph4_rd_o         = 1'b0;
   periph4_data_o       = 32'h00000000;
   periph5_addr_o       = 8'h00;
   periph5_wr_o         = 4'b0000;
   periph5_rd_o         = 1'b0;
   periph5_data_o       = 32'h00000000;
   periph6_addr_o       = 8'h00;
   periph6_wr_o         = 4'b0000;
   periph6_rd_o         = 1'b0;
   periph6_data_o       = 32'h00000000;
   periph7_addr_o       = 8'h00;
   periph7_wr_o         = 4'b0000;
   periph7_rd_o         = 1'b0;
   periph7_data_o       = 32'h00000000;

   // Decode 4-bit peripheral select
   case (io_addr_i[11:8])

   // Peripheral 0
   4'd 0 :
   begin
       periph0_addr_o       = io_addr_i[7:0];
       periph0_wr_o         = io_wr_i;
       periph0_rd_o         = io_rd_i;
       periph0_data_o       = io_data_i;
   end
   // Peripheral 1
   4'd 1 :
   begin
       periph1_addr_o       = io_addr_i[7:0];
       periph1_wr_o         = io_wr_i;
       periph1_rd_o         = io_rd_i;
       periph1_data_o       = io_data_i;
   end
   // Peripheral 2
   4'd 2 :
   begin
       periph2_addr_o       = io_addr_i[7:0];
       periph2_wr_o         = io_wr_i;
       periph2_rd_o         = io_rd_i;
       periph2_data_o       = io_data_i;
   end
   // Peripheral 3
   4'd 3 :
   begin
       periph3_addr_o       = io_addr_i[7:0];
       periph3_wr_o         = io_wr_i;
       periph3_rd_o         = io_rd_i;
       periph3_data_o       = io_data_i;
   end
   // Peripheral 4
   4'd 4 :
   begin
       periph4_addr_o       = io_addr_i[7:0];
       periph4_wr_o         = io_wr_i;
       periph4_rd_o         = io_rd_i;
       periph4_data_o       = io_data_i;
   end
   // Peripheral 5
   4'd 5 :
   begin
       periph5_addr_o       = io_addr_i[7:0];
       periph5_wr_o         = io_wr_i;
       periph5_rd_o         = io_rd_i;
       periph5_data_o       = io_data_i;
   end
   // Peripheral 6
   4'd 6 :
   begin
       periph6_addr_o       = io_addr_i[7:0];
       periph6_wr_o         = io_wr_i;
       periph6_rd_o         = io_rd_i;
       periph6_data_o       = io_data_i;
   end
   // Peripheral 7
   4'd 7 :
   begin
       periph7_addr_o       = io_addr_i[7:0];
       periph7_wr_o         = io_wr_i;
       periph7_rd_o         = io_rd_i;
       periph7_data_o       = io_data_i;
   end

   default :
      ;
   endcase
end

//-----------------------------------------------------------------
// Read Port
//-----------------------------------------------------------------
always @ *
begin
   case (r_mem_sel)

   // Peripheral 0
   4'd 0 :
   begin
       io_data_o   = periph0_data_i;
   end
   // Peripheral 1
   4'd 1 :
   begin
       io_data_o   = periph1_data_i;
   end
   // Peripheral 2
   4'd 2 :
   begin
       io_data_o   = periph2_data_i;
   end
   // Peripheral 3
   4'd 3 :
   begin
       io_data_o   = periph3_data_i;
   end
   // Peripheral 4
   4'd 4 :
   begin
       io_data_o   = periph4_data_i;
   end
   // Peripheral 5
   4'd 5 :
   begin
       io_data_o   = periph5_data_i;
   end
   // Peripheral 6
   4'd 6 :
   begin
       io_data_o   = periph6_data_i;
   end
   // Peripheral 7
   4'd 7 :
   begin
       io_data_o   = periph7_data_i;
   end

   default :
   begin
       io_data_o   = 32'h00000000;
   end
   endcase
end

//-----------------------------------------------------------------
// Registered peripheral select
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
begin
   if (rst_i == 1'b1)
       r_mem_sel <= 4'h0;
   else
       r_mem_sel <= io_addr_i[11:8];
end

endmodule
