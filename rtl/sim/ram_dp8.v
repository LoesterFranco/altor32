
//-----------------------------------------------------------------
// Module: ram_dp8 - dual port block RAM
//-----------------------------------------------------------------
module ram_dp8
(
    aclk_i,
    aadr_i,
    adat_i,
    awr_i,
    adat_o,

    bclk_i,
    badr_i,
    bdat_i,
    bwr_i,
    bdat_o
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter  [31:0]       WIDTH = 8;
parameter  [31:0]       SIZE = 14;

//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------
input                   aclk_i /*verilator public*/;
output [(WIDTH - 1):0]  adat_o /*verilator public*/;
input [(WIDTH - 1):0]   adat_i /*verilator public*/;
input [(SIZE - 1):0]    aadr_i /*verilator public*/;
input                   awr_i /*verilator public*/;
input                   bclk_i /*verilator public*/;
output [(WIDTH - 1):0]  bdat_o /*verilator public*/;
input [(WIDTH - 1):0]   bdat_i /*verilator public*/;
input [(SIZE - 1):0]    badr_i /*verilator public*/;
input                   bwr_i /*verilator public*/;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
/* verilator lint_off MULTIDRIVEN */
reg [(WIDTH - 1):0]     ram [((2<< (SIZE-1)) - 1):0] /*verilator public*/;
/* verilator lint_on MULTIDRIVEN */

reg [(SIZE - 1):0]      rd_addr_a;
reg [(SIZE - 1):0]      rd_addr_b;
wire [(WIDTH - 1):0]    adat_o;
wire [(WIDTH - 1):0]    bdat_o;

//-----------------------------------------------------------------
// Processes
//-----------------------------------------------------------------
always @ (posedge aclk_i)
begin
    if (awr_i == 1'b1)
        ram[aadr_i] <= adat_i;
    rd_addr_a <= aadr_i;
end
always @ (posedge bclk_i)
begin
    if (bwr_i == 1'b1)
        ram[badr_i] <= bdat_i;
    rd_addr_b <= badr_i;
end

//-------------------------------------------------------------------
// Combinatorial
//-------------------------------------------------------------------
assign adat_o = ram[rd_addr_a];
assign bdat_o = ram[rd_addr_b];

endmodule
