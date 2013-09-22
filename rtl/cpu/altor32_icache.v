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
// Module - Instruction Cache
//-----------------------------------------------------------------
module altor32_icache 
( 
    input                       clk_i /*verilator public*/,
    input                       rst_i /*verilator public*/,

    // Processor interface
    input                       rd_i /*verilator public*/,
    input [31:0]                pc_i /*verilator public*/,
    output [31:0]               instruction_o /*verilator public*/,
    output                      valid_o /*verilator public*/,
    input                       invalidate_i /*verilator public*/,

    // Status
    output                      miss_o /*verilator public*/,
    output                      busy_o /*verilator public*/,

    // Memory interface (slave)
    output reg [31:0]           mem_addr_o /*verilator public*/,
    input [31:0]                mem_data_i /*verilator public*/,
    output reg                  mem_burst_o /*verilator public*/,
    output reg                  mem_rd_o /*verilator public*/,
    input                       mem_accept_i/*verilator public*/,
    input                       mem_ack_i/*verilator public*/
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter BOOT_VECTOR               = 32'h00000000;

parameter CACHE_LINE_SIZE_WIDTH     = 5; /* 5-bits -> 32 entries */
parameter CACHE_LINE_SIZE_BYTES     = 2 ** CACHE_LINE_SIZE_WIDTH; /* 32 bytes / 4 words per line */
parameter CACHE_LINE_ADDR_WIDTH     = 8; /* 256 lines */
parameter CACHE_LINE_WORDS_IDX_MAX  = CACHE_LINE_SIZE_WIDTH - 2; /* 3-bit = 111 */
parameter CACHE_TAG_ENTRIES         = 2 ** CACHE_LINE_ADDR_WIDTH ; /* 256 tag entries */
parameter CACHE_DSIZE               = CACHE_LINE_ADDR_WIDTH * CACHE_LINE_SIZE_BYTES; /* 8KB data */
parameter CACHE_DWIDTH              = CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 2; /* 10-bits */

parameter CACHE_TAG_WIDTH           = 16; /* 16-bit tag entry size */
parameter CACHE_TAG_LINE_ADDR_WIDTH = CACHE_TAG_WIDTH - 1; /* 15 bits of data (tag entry size minus valid bit) */

parameter CACHE_TAG_ADDR_LOW        = CACHE_LINE_SIZE_WIDTH + CACHE_LINE_ADDR_WIDTH;
parameter CACHE_TAG_ADDR_HIGH       = CACHE_TAG_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH + CACHE_LINE_ADDR_WIDTH - 1;

// Tag fields
parameter CACHE_TAG_VALID_BIT       = 15;

//  31          16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
// |--------------|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
//  +--------------------+  +-------------------+   +-----------+      
//    Tag entry                     Line address         Address 
//       (15-bits)                    (8-bits)           within line 
//                                                       (5-bits)

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
wire [CACHE_TAG_WIDTH-1:0]      tag_data_out;
reg  [CACHE_TAG_WIDTH-1:0]      tag_data_in;
reg                             tag_wr;

wire [CACHE_LINE_ADDR_WIDTH-1:0] tag_entry;
wire [CACHE_DWIDTH-1:0]         cache_address_rd;

reg [CACHE_DWIDTH-1:0]          cache_address_wr;
reg [31:0]                      cache_data_w;
reg                             cache_wr;

reg [CACHE_LINE_SIZE_WIDTH-3:0] fetch_word;

reg [31:0]                      last_pc;
reg [31:0]                      miss_pc;

reg                             initial_fetch;
reg                             flush_req;

reg [CACHE_LINE_ADDR_WIDTH-1:0] flush_addr;
reg                             flush_wr;

reg                             read_while_busy;

// Current state
parameter STATE_CHECK       = 0;
parameter STATE_FETCH       = 1;
parameter STATE_WAIT        = 2;
parameter STATE_WAIT2       = 3;
parameter STATE_FLUSH       = 4;
reg [3:0]                       state;

assign tag_entry        = (state != STATE_CHECK) ? miss_pc[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH] : pc_i[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH];
assign cache_address_rd = pc_i[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:2];

assign miss_o           = (!tag_data_out[CACHE_TAG_VALID_BIT] || (last_pc[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW] != tag_data_out[14:0])) ? 1'b1: 1'b0;

assign valid_o            = !miss_o && !busy_o;

//-----------------------------------------------------------------
// Control logic
//-----------------------------------------------------------------
reg [CACHE_LINE_SIZE_WIDTH-3:0] v_line_word;

always @ (posedge rst_i or posedge clk_i )
begin
   if (rst_i == 1'b1)
   begin
        fetch_word      <= {CACHE_LINE_SIZE_WIDTH-2{1'b0}};
        mem_addr_o      <= 32'h00000000;
        mem_rd_o        <= 1'b0;
        mem_burst_o     <= 1'b0;
        tag_wr          <= 1'b0;
        cache_address_wr<= {CACHE_DWIDTH{1'b0}};
        cache_data_w    <= 32'h00000000;
        cache_wr        <= 1'b0;
        miss_pc         <= BOOT_VECTOR + `VECTOR_RESET;
        last_pc         <= 32'h00000000;
        state           <= STATE_CHECK;   
        initial_fetch   <= 1'b1;
        read_while_busy <= 1'b0;
        
        flush_addr      <= {CACHE_LINE_ADDR_WIDTH{1'b0}};
        flush_wr        <= 1'b0;
        flush_req       <= 1'b0;
   end
   else
   begin
   
        if (mem_accept_i)
            mem_rd_o        <= 1'b0;
        tag_wr          <= 1'b0;
        cache_wr        <= 1'b0;
        initial_fetch   <= 1'b0;
        flush_wr        <= 1'b0;
        last_pc         <= pc_i;
        
        // Latch invalidate request even if can't be actioned now...
        if (invalidate_i)
            flush_req <= 1'b1;

        // New request whilst cache busy?
        if (rd_i)
            read_while_busy <= 1'b1;

        case (state)

            //-----------------------------------------
            // CHECK - check cache for hit or miss
            //-----------------------------------------
            STATE_CHECK :
            begin
                // Cache flush request pending?
                if (flush_req || invalidate_i)
                begin
                    flush_req       <= 1'b0;
                    flush_addr      <= {CACHE_LINE_ADDR_WIDTH{1'b1}};
                    flush_wr        <= 1'b1;
                    state           <= STATE_FLUSH;

`ifdef CONF_CORE_DEBUG                       
                    $display("Fetch: Cache flush request");
`endif                    
                end
                // Cache miss (& new read request not pending)
                else if ((miss_o && !initial_fetch) && !rd_i && !read_while_busy)
                begin
                    read_while_busy <= 1'b0;

                    fetch_word    <= {CACHE_LINE_SIZE_WIDTH-2{1'b0}};

`ifdef CONF_CORE_DEBUG                     
                    $display("Fetch: Cache miss at 0x%x (last=%x, current=%x)", miss_pc, last_pc, pc_i);
`endif                     
                    
                    // Start fetch from memory
                    mem_addr_o  <= {miss_pc[31:CACHE_LINE_SIZE_WIDTH], {CACHE_LINE_SIZE_WIDTH{1'b0}}};
                    mem_rd_o    <= 1'b1;
                    mem_burst_o <= 1'b1;
                    state       <= STATE_FETCH;
                 
                    // Update tag memory with this line's details   
                    tag_data_in <= {1'b1, miss_pc[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW]};
                    tag_wr      <= 1'b1;
                end
                // Cache hit (or new read request)
                else
                begin
`ifdef CONF_CORE_DEBUG 
                    $display("Fetch: Cache hit at PC=%x (current=%x)", last_pc, pc_i);
                    if (read_while_busy)
                        $display("Fetch: Read request whilst busy PC=%x (current=%x)", last_pc, pc_i);
`endif

                    // Store fetch PC
                    miss_pc     <= pc_i;
                    state       <= STATE_CHECK;                    
                    read_while_busy <= 1'b0;
                end
            end
            //-----------------------------------------
            // FETCH - Fetch row from memory
            //-----------------------------------------
            STATE_FETCH :
            begin
                // Data ready from memory?
                if (mem_ack_i)
                begin
                    // Write data into cache
                    cache_address_wr<= {miss_pc[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH], fetch_word};
                    cache_data_w    <= mem_data_i;
                    cache_wr        <= 1'b1;
                
                    // Line fetch complete?
                    if (fetch_word == {CACHE_LINE_WORDS_IDX_MAX{1'b1}})
                    begin
                        state       <= STATE_WAIT;
                    end
                    // Fetch next word for line
                    else
                    begin
                        v_line_word = fetch_word + 1'b1;
                        fetch_word <= v_line_word;
                        
                        mem_addr_o <= {mem_addr_o[31:CACHE_LINE_SIZE_WIDTH], v_line_word, 2'b00};
                        mem_rd_o   <= 1'b1;
                        
                        if (fetch_word == ({CACHE_LINE_WORDS_IDX_MAX{1'b1}}-1))
                        begin
                            mem_burst_o <= 1'b0;
                        end
                    end
                end
            end
            //-----------------------------------------
            // FLUSH - Invalidate tag memory
            //-----------------------------------------
            STATE_FLUSH :
            begin
                if (flush_addr == {CACHE_LINE_ADDR_WIDTH{1'b0}})
                begin
                    // Fetch current PC line again
                    mem_addr_o  <= {pc_i[31:CACHE_LINE_SIZE_WIDTH], {CACHE_LINE_SIZE_WIDTH{1'b0}}};
                    mem_rd_o    <= 1'b1;
                    mem_burst_o <= 1'b1;
                    state       <= STATE_FETCH;
                 
                    // Update tag memory with this line's details   
                    tag_data_in <= {1'b1, pc_i[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW]};
                    tag_wr      <= 1'b1;                    

                    // Start of line
                    fetch_word    <= {CACHE_LINE_SIZE_WIDTH-2{1'b0}};

                    // Clear pending reads whilst busy
                    read_while_busy <= 1'b0;
                end
                else
                begin
                    flush_addr  <= flush_addr - 1;
                    flush_wr    <= 1'b1;
                    state       <= STATE_FLUSH;
                end
            end    
            //-----------------------------------------
            // WAIT - Wait cycle
            //-----------------------------------------
            STATE_WAIT :
            begin
                // Allow extra wait state to handle write & read collision               
                state   <= STATE_WAIT2;
            end    
            //-----------------------------------------
            // WAIT2 - Wait cycle
            //-----------------------------------------
            STATE_WAIT2 :
            begin         
`ifdef CONF_CORE_DEBUG            
                $display("Fetch: Filled line containing PC=%x", miss_pc);
`endif                
                state   <= STATE_CHECK;
            end            
                                
            
            default:
                ;
           endcase
   end
end

// Stall the CPU if cache state machine is not idle!
assign busy_o = (state == STATE_CHECK & ~read_while_busy) ? 1'b0 : 1'b1;

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------
    
// Tag memory    
altor32_ram_dp  
#(
    .WIDTH(CACHE_TAG_WIDTH),
    .SIZE(CACHE_LINE_ADDR_WIDTH)
) 
u1_tag_mem
(
    .aclk_i(clk_i), 
    .adat_o(tag_data_out), 
    .adat_i(tag_data_in), 
    .aadr_i(tag_entry), 
    .awr_i(tag_wr),
    
    .bclk_i(clk_i), 
    .badr_i(flush_addr), 
    .bdat_o(/*open*/), 
    .bdat_i({CACHE_TAG_WIDTH{1'b0}}),     
    .bwr_i(flush_wr)    
);
   
// Data memory
altor32_ram_dp  
#(
    .WIDTH(32),
    .SIZE(CACHE_DWIDTH)
) 
u2_data_mem
(
    .aclk_i(clk_i), 
    .aadr_i(cache_address_rd), 
    .adat_o(instruction_o), 
    .adat_i(32'h00),
    .awr_i(1'b0),
    
    .bclk_i(clk_i), 
    .badr_i(cache_address_wr), 
    .bdat_o(/*open*/), 
    .bdat_i(cache_data_w),
    .bwr_i(cache_wr)
);

endmodule

