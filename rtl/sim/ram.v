//-----------------------------------------------------------------
// Module: ram - dual port block RAM
//-----------------------------------------------------------------
module ram
(
    // Port A
    input clka_i /*verilator public*/,
    input ena_i /*verilator public*/,
    input [3:0] wea_i /*verilator public*/,
    input [31:2] addra_i /*verilator public*/,
    input [31:0] dataa_i /*verilator public*/,
    output [31:0] dataa_o /*verilator public*/,

    // Port B
    input clkb_i /*verilator public*/,
    input enb_i /*verilator public*/,
    input [3:0] web_i /*verilator public*/,
    input [31:2] addrb_i /*verilator public*/,
    input [31:0] datab_i /*verilator public*/,
    output [31:0] datab_o /*verilator public*/
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter  [31:0]       block_count  = 6;
parameter  [31:0]       SIZE         = 14;

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------

ram_dp8  
#(
    .WIDTH(8),
    .SIZE(SIZE)
) 
u0
(
    .aclk_i(clka_i), 
    .aadr_i(addra_i[SIZE+2-1:2]), 
    .adat_o(dataa_o[7:0]), 
    .adat_i(dataa_i[7:0]),
    .awr_i(wea_i[0]),
    
    .bclk_i(clkb_i), 
    .badr_i(addrb_i[SIZE+2-1:2]), 
    .bdat_o(datab_o[7:0]), 
    .bdat_i(datab_i[7:0]),
    .bwr_i(web_i[0])
);

ram_dp8  
#(
    .WIDTH(8),
    .SIZE(SIZE)
) 
u1
(
    .aclk_i(clka_i), 
    .aadr_i(addra_i[SIZE+2-1:2]), 
    .adat_o(dataa_o[15:8]), 
    .adat_i(dataa_i[15:8]),
    .awr_i(wea_i[1]),
    
    .bclk_i(clkb_i), 
    .badr_i(addrb_i[SIZE+2-1:2]), 
    .bdat_o(datab_o[15:8]), 
    .bdat_i(datab_i[15:8]),
    .bwr_i(web_i[1])
);

ram_dp8  
#(
    .WIDTH(8),
    .SIZE(SIZE)
) 
u2
(
    .aclk_i(clka_i), 
    .aadr_i(addra_i[SIZE+2-1:2]), 
    .adat_o(dataa_o[23:16]), 
    .adat_i(dataa_i[23:16]),
    .awr_i(wea_i[2]),
    
    .bclk_i(clkb_i), 
    .badr_i(addrb_i[SIZE+2-1:2]), 
    .bdat_o(datab_o[23:16]), 
    .bdat_i(datab_i[23:16]),
    .bwr_i(web_i[2])
);

ram_dp8  
#(
    .WIDTH(8),
    .SIZE(SIZE)
) 
u3
(
    .aclk_i(clka_i), 
    .aadr_i(addra_i[SIZE+2-1:2]), 
    .adat_o(dataa_o[31:24]), 
    .adat_i(dataa_i[31:24]),
    .awr_i(wea_i[3]),
    
    .bclk_i(clkb_i), 
    .badr_i(addrb_i[SIZE+2-1:2]), 
    .bdat_o(datab_o[31:24]), 
    .bdat_i(datab_i[31:24]),
    .bwr_i(web_i[3])    
);

endmodule
