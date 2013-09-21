
//-----------------------------------------------------------------
// Module:
//-----------------------------------------------------------------
module dmem_mux3
(
    // Outputs
    out0_addr_o,
    out0_data_o,
    out0_data_i,
    out0_wr_o,
    out0_rd_o,
    out0_burst_o,
    out0_ack_i,
    out0_accept_i,
    out1_addr_o,
    out1_data_o,
    out1_data_i,
    out1_wr_o,
    out1_rd_o,
    out1_burst_o,
    out1_ack_i,
    out1_accept_i,
    out2_addr_o,
    out2_data_o,
    out2_data_i,
    out2_wr_o,
    out2_rd_o,
    out2_burst_o,
    out2_ack_i,
    out2_accept_i,

    // Input
    mem_addr_i,
    mem_data_i,
    mem_data_o,
    mem_burst_i,
    mem_wr_i,
    mem_rd_i,
    mem_ack_o,
    mem_accept_o
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter           ADDR_MUX_START      = 28;

//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------
input [31:0]        mem_addr_i /*verilator public*/;
input [31:0]        mem_data_i /*verilator public*/;
output [31:0]       mem_data_o /*verilator public*/;
input [3:0]         mem_wr_i /*verilator public*/;
input               mem_rd_i /*verilator public*/;
input               mem_burst_i /*verilator public*/;
output              mem_ack_o /*verilator public*/;
output              mem_accept_o /*verilator public*/;
output [31:0]       out0_addr_o /*verilator public*/;
output [31:0]       out0_data_o /*verilator public*/;
input [31:0]        out0_data_i /*verilator public*/;
output [3:0]        out0_wr_o /*verilator public*/;
output              out0_rd_o /*verilator public*/;
output              out0_burst_o /*verilator public*/;
input               out0_ack_i /*verilator public*/;
input               out0_accept_i /*verilator public*/;
output [31:0]       out1_addr_o /*verilator public*/;
output [31:0]       out1_data_o /*verilator public*/;
input [31:0]        out1_data_i /*verilator public*/;
output [3:0]        out1_wr_o /*verilator public*/;
output              out1_rd_o /*verilator public*/;
output              out1_burst_o /*verilator public*/;
input               out1_ack_i /*verilator public*/;
input               out1_accept_i /*verilator public*/;
output [31:0]       out2_addr_o /*verilator public*/;
output [31:0]       out2_data_o /*verilator public*/;
input [31:0]        out2_data_i /*verilator public*/;
output [3:0]        out2_wr_o /*verilator public*/;
output              out2_rd_o /*verilator public*/;
output              out2_burst_o /*verilator public*/;
input               out2_ack_i /*verilator public*/;
input               out2_accept_i /*verilator public*/;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------

// Output Signals
reg                 mem_ack_o;
reg                 mem_accept_o;
reg [31:0]          mem_data_o;

reg [31:0]          out0_addr_o;
reg [31:0]          out0_data_o;
reg [3:0]           out0_wr_o;
reg                 out0_rd_o;
reg                 out0_burst_o;
reg [31:0]          out1_addr_o;
reg [31:0]          out1_data_o;
reg [3:0]           out1_wr_o;
reg                 out1_rd_o;
reg                 out1_burst_o;
reg [31:0]          out2_addr_o;
reg [31:0]          out2_data_o;
reg [3:0]           out2_wr_o;
reg                 out2_rd_o;
reg                 out2_burst_o;

//-----------------------------------------------------------------
// Memory Map
//-----------------------------------------------------------------
always @ (mem_addr_i or mem_wr_i or mem_rd_i or mem_data_i or mem_burst_i)
begin

   out0_addr_o      = 32'h00000000;
   out0_wr_o        = 4'b0000;
   out0_rd_o        = 1'b0;
   out0_data_o      = 32'h00000000;
   out0_burst_o     = 1'b0;
   out1_addr_o      = 32'h00000000;
   out1_wr_o        = 4'b0000;
   out1_rd_o        = 1'b0;
   out1_data_o      = 32'h00000000;
   out1_burst_o     = 1'b0;
   out2_addr_o      = 32'h00000000;
   out2_wr_o        = 4'b0000;
   out2_rd_o        = 1'b0;
   out2_data_o      = 32'h00000000;
   out2_burst_o     = 1'b0;

   case (mem_addr_i[ADDR_MUX_START+2-1:ADDR_MUX_START])

   2'd0:
   begin
       out0_addr_o      = mem_addr_i;
       out0_wr_o        = mem_wr_i;
       out0_rd_o        = mem_rd_i;
       out0_data_o      = mem_data_i;
       out0_burst_o     = mem_burst_i;
   end
   2'd1:
   begin
       out1_addr_o      = mem_addr_i;
       out1_wr_o        = mem_wr_i;
       out1_rd_o        = mem_rd_i;
       out1_data_o      = mem_data_i;
       out1_burst_o     = mem_burst_i;
   end
   2'd2:
   begin
       out2_addr_o      = mem_addr_i;
       out2_wr_o        = mem_wr_i;
       out2_rd_o        = mem_rd_i;
       out2_data_o      = mem_data_i;
       out2_burst_o     = mem_burst_i;
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
   case (mem_addr_i[ADDR_MUX_START+2-1:ADDR_MUX_START])

    2'd0:
    begin
       mem_data_o   = out0_data_i;
       mem_accept_o = out0_accept_i;
       mem_ack_o    = out0_ack_i;
    end
    2'd1:
    begin
       mem_data_o   = out1_data_i;
       mem_accept_o = out1_accept_i;
       mem_ack_o    = out1_ack_i;
    end
    2'd2:
    begin
       mem_data_o   = out2_data_i;
       mem_accept_o = out2_accept_i;
       mem_ack_o    = out2_ack_i;
    end

   default :
   begin
       mem_data_o   = 32'h00000000;
       mem_accept_o = 1'b0;
       mem_ack_o    = 1'b0;
   end
   endcase
end

endmodule
