
//-----------------------------------------------------------------
// Module:
//-----------------------------------------------------------------
module cpu_if
(
    // General - Clocking & Reset
    clk_i,
    rst_i,

    // Instruction Memory 0 (0x10000000 - 0x10FFFFFF)
    imem0_addr_o,
    imem0_rd_o,
    imem0_burst_o,
    imem0_data_in_i,
    imem0_accept_i,
    imem0_ack_i,

    // Data Memory 0 (0x10000000 - 0x10FFFFFF)
    dmem0_addr_o,
    dmem0_data_o,
    dmem0_data_i,
    dmem0_wr_o,
    dmem0_rd_o,
    dmem0_burst_o,
    dmem0_accept_i,
    dmem0_ack_i,
    // Data Memory 1 (0x11000000 - 0x11FFFFFF)
    dmem1_addr_o,
    dmem1_data_o,
    dmem1_data_i,
    dmem1_wr_o,
    dmem1_rd_o,
    dmem1_burst_o,
    dmem1_accept_i,
    dmem1_ack_i,
    // Data Memory 2 (0x12000000 - 0x12FFFFFF)
    dmem2_addr_o,
    dmem2_data_o,
    dmem2_data_i,
    dmem2_wr_o,
    dmem2_rd_o,
    dmem2_burst_o,
    dmem2_accept_i,
    dmem2_ack_i,

    fault_o,
    break_o,
    intr_i,
    nmi_i    
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter  [31:0]   CLK_KHZ              = 12288;
parameter           ENABLE_ICACHE        = "ENABLED";
parameter           ENABLE_DCACHE        = "DISABLED";
parameter           BOOT_VECTOR          = 0;
parameter           ISR_VECTOR           = 0;
parameter           REGISTER_FILE_TYPE   = "SIMULATION";

//-----------------------------------------------------------------
// I/O
//-----------------------------------------------------------------
input               clk_i /*verilator public*/;
input               rst_i /*verilator public*/;

// Instruction Memory 0 (0x10000000 - 0x10FFFFFF)
output [31:0]       imem0_addr_o /*verilator public*/;
output              imem0_rd_o /*verilator public*/;
output              imem0_burst_o /*verilator public*/;
input [31:0]        imem0_data_in_i /*verilator public*/;
input               imem0_accept_i /*verilator public*/;
input               imem0_ack_i /*verilator public*/;

// Data Memory 0 (0x10000000 - 0x10FFFFFF)
output [31:0]       dmem0_addr_o /*verilator public*/;
output [31:0]       dmem0_data_o /*verilator public*/;
input [31:0]        dmem0_data_i /*verilator public*/;
output [3:0]        dmem0_wr_o /*verilator public*/;
output              dmem0_rd_o /*verilator public*/;
output              dmem0_burst_o /*verilator public*/;
input               dmem0_accept_i /*verilator public*/;
input               dmem0_ack_i /*verilator public*/;
// Data Memory 1 (0x11000000 - 0x11FFFFFF)
output [31:0]       dmem1_addr_o /*verilator public*/;
output [31:0]       dmem1_data_o /*verilator public*/;
input [31:0]        dmem1_data_i /*verilator public*/;
output [3:0]        dmem1_wr_o /*verilator public*/;
output              dmem1_rd_o /*verilator public*/;
output              dmem1_burst_o /*verilator public*/;
input               dmem1_accept_i /*verilator public*/;
input               dmem1_ack_i /*verilator public*/;
// Data Memory 2 (0x12000000 - 0x12FFFFFF)
output [31:0]       dmem2_addr_o /*verilator public*/;
output [31:0]       dmem2_data_o /*verilator public*/;
input [31:0]        dmem2_data_i /*verilator public*/;
output [3:0]        dmem2_wr_o /*verilator public*/;
output              dmem2_rd_o /*verilator public*/;
output              dmem2_burst_o /*verilator public*/;
input               dmem2_accept_i /*verilator public*/;
input               dmem2_ack_i /*verilator public*/;

output              fault_o /*verilator public*/;
output              break_o /*verilator public*/;
input               nmi_i /*verilator public*/;
input               intr_i /*verilator public*/;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
wire [31:0]         cpu_address;
wire [3:0]          cpu_wr;
wire                cpu_rd;
wire                cpu_burst;
wire [31:0]         cpu_data_w;
wire [31:0]         cpu_data_r;
wire                cpu_accept;
wire                cpu_ack;
    
wire [31:0]         imem_address;
wire [31:0]         imem_data;
wire                imem_rd;
wire                imem_burst;
wire                imem_ack;
wire                imem_accept;

//-----------------------------------------------------------------
// CPU core
//-----------------------------------------------------------------
cpu
#(
    .BOOT_VECTOR(BOOT_VECTOR),
    .ISR_VECTOR(ISR_VECTOR),
    .REGISTER_FILE_TYPE(REGISTER_FILE_TYPE),
    .ENABLE_ICACHE(ENABLE_ICACHE),
    .ENABLE_DCACHE(ENABLE_DCACHE)
)
u1_cpu
(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .intr_i(intr_i),
    .nmi_i(nmi_i),
    
    // Status
    .fault_o(fault_o),
    .break_o(break_o),
    
    // Instruction memory
    .imem_addr_o(imem_address),
    .imem_rd_o(imem_rd),
    .imem_burst_o(imem_burst),    
    .imem_data_in_i(imem_data),
    .imem_accept_i(imem_accept),
    .imem_ack_i(imem_ack),    
    
    // Data memory
    .dmem_addr_o(cpu_address),
    .dmem_data_out_o(cpu_data_w),
    .dmem_data_in_i(cpu_data_r),
    .dmem_wr_o(cpu_wr),
    .dmem_rd_o(cpu_rd),
    .dmem_burst_o(cpu_burst),
    .dmem_accept_i(cpu_accept),
    .dmem_ack_i(cpu_ack)
);

//-----------------------------------------------------------------
// Instruction Memory MUX
//-----------------------------------------------------------------

assign imem0_addr_o     = imem_address;
assign imem0_rd_o       = imem_rd;
assign imem0_burst_o    = imem_burst;
assign imem_data        = imem0_data_in_i;
assign imem_accept      = imem0_accept_i;
assign imem_ack         = imem0_ack_i;


//-----------------------------------------------------------------
// Data Memory MUX
//-----------------------------------------------------------------
dmem_mux3
#(
    .ADDR_MUX_START(24)
)
u_dmux
(
    // Outputs
    // 0x10000000 - 0x10FFFFFF
    .out0_addr_o(dmem0_addr_o),
    .out0_data_o(dmem0_data_o),
    .out0_data_i(dmem0_data_i),
    .out0_wr_o(dmem0_wr_o),
    .out0_rd_o(dmem0_rd_o),
    .out0_burst_o(dmem0_burst_o),
    .out0_ack_i(dmem0_ack_i),
    .out0_accept_i(dmem0_accept_i),
    // 0x11000000 - 0x11FFFFFF
    .out1_addr_o(dmem1_addr_o),
    .out1_data_o(dmem1_data_o),
    .out1_data_i(dmem1_data_i),
    .out1_wr_o(dmem1_wr_o),
    .out1_rd_o(dmem1_rd_o),
    .out1_burst_o(dmem1_burst_o),
    .out1_ack_i(dmem1_ack_i),
    .out1_accept_i(dmem1_accept_i),
    // 0x12000000 - 0x12FFFFFF
    .out2_addr_o(dmem2_addr_o),
    .out2_data_o(dmem2_data_o),
    .out2_data_i(dmem2_data_i),
    .out2_wr_o(dmem2_wr_o),
    .out2_rd_o(dmem2_rd_o),
    .out2_burst_o(dmem2_burst_o),
    .out2_ack_i(dmem2_ack_i),
    .out2_accept_i(dmem2_accept_i),

    // Input - CPU core bus
    .mem_addr_i(cpu_address),
    .mem_data_i(cpu_data_w),
    .mem_data_o(cpu_data_r),
    .mem_wr_i(cpu_wr),
    .mem_rd_i(cpu_rd),
    .mem_burst_i(cpu_burst),
    .mem_ack_o(cpu_ack),
    .mem_accept_o(cpu_accept)
);

endmodule
