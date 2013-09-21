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
// Module - Data Cache (write back)
//-----------------------------------------------------------------
module altor32_dcache
( 
    input           clk_i /*verilator public*/,
    input           rst_i /*verilator public*/,

    input           flush_i /*verilator public*/,

    // Input (CPU)
    input [31:0]    address_i /*verilator public*/,
    output [31:0]   data_o /*verilator public*/,
    input [31:0]    data_i /*verilator public*/,
    input           rd_i /*verilator public*/,
    input [3:0]     wr_i /*verilator public*/,
    output          accept_o /*verilator public*/,
    output          ack_o /*verilator public*/,

    // Output (Memory)
    output [31:0]   mem_addr_o /*verilator public*/,
    input [31:0]    mem_data_i /*verilator public*/,
    output [31:0]   mem_data_o /*verilator public*/,
    output          mem_burst_o /*verilator public*/,
    output          mem_rd_o /*verilator public*/,
    output [3:0]    mem_wr_o /*verilator public*/,
    input           mem_accept_i/*verilator public*/,
    input           mem_ack_i/*verilator public*/ 
);

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
parameter CACHE_LINE_SIZE_WIDTH     = 5; /* 5-bits -> 32 entries */
parameter CACHE_LINE_SIZE_BYTES     = 2 ** CACHE_LINE_SIZE_WIDTH; /* 32 bytes / 8 words per line */
parameter CACHE_LINE_ADDR_WIDTH     = 8; /* 256 lines */
parameter CACHE_LINE_WORDS_IDX_MAX  = CACHE_LINE_SIZE_WIDTH - 2; /* 3-bit = 8 words */
parameter CACHE_TAG_ENTRIES         = 2 ** CACHE_LINE_ADDR_WIDTH ; /* 256 tag entries */
parameter CACHE_DSIZE               = CACHE_LINE_ADDR_WIDTH * CACHE_LINE_SIZE_BYTES; /* 8KB data */
parameter CACHE_DWIDTH              = CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 2; /* 11-bits */

parameter CACHE_TAG_WIDTH           = 16; /* 16-bit tag entry size */
parameter CACHE_TAG_LINE_ADDR_WIDTH = CACHE_TAG_WIDTH - 2; /* 14 bits of data (tag entry size minus valid/dirty bit) */

parameter CACHE_TAG_ADDR_LOW        = CACHE_LINE_SIZE_WIDTH + CACHE_LINE_ADDR_WIDTH;
parameter CACHE_TAG_ADDR_HIGH       = CACHE_TAG_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH + CACHE_LINE_ADDR_WIDTH - 1;

// Tag fields
parameter CACHE_TAG_DIRTY_BIT       = 14;
parameter CACHE_TAG_VALID_BIT       = 15;
parameter ADDR_NO_CACHE_BIT         = 25;
parameter ADDR_CACHE_BYPASS_BIT     = 31;

//  31          16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
// |--------------|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
//  +--------------------+   +-------------------+   +-----------+      
//    Tag entry                     Line address         Address 
//       (15-bits)                    (8-bits)           within line 
//                                                       (5-bits)

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
wire [CACHE_LINE_ADDR_WIDTH-1:0] tag_entry;
wire [CACHE_TAG_WIDTH-1:0]       tag_data_out;
reg  [CACHE_TAG_WIDTH-1:0]       tag_data_in;
reg                              tag_wr;

wire [CACHE_DWIDTH-1:0]          cache_address;
wire [31:0]                      cache_data_r;
reg [31:0]                       cache_data_w;
reg [3:0]                        cache_wr;

wire [31:2]                      cache_update_addr;
wire [31:0]                      cache_update_data_w;
wire [31:0]                      cache_update_data_r;
wire                             cache_update_wr;

reg                              ack;

reg                              fill;
reg                              evict;
wire                             done;

reg [31:0]                       data_w;
wire [31:0]                      data_r;
reg                              data_rd;
reg [3:0]                        data_wr;

reg                              req_rd;
reg [3:0]                        req_wr;
reg                              req_ack;
reg [31:0]                       req_address;

reg                              req_flush;
reg                              flush_single;

wire [31:0]                      line_address;

wire [31:0]                      muxed_address = (state == STATE_IDLE) ? address_i : req_address;

// Current state
parameter STATE_IDLE        = 0;
parameter STATE_SINGLE      = 1;
parameter STATE_CHECK       = 2;
parameter STATE_FETCH       = 3;
parameter STATE_WAIT        = 4;
parameter STATE_WAIT2       = 5;
parameter STATE_WRITE       = 6;
parameter STATE_SINGLE_READY= 7;
parameter STATE_EVICTING    = 8;
parameter STATE_UPDATE      = 9;
parameter STATE_FLUSH1      = 10;
parameter STATE_FLUSH2      = 11;
parameter STATE_FLUSH3      = 12;
parameter STATE_FLUSH4      = 13;
reg [3:0] state;

assign tag_entry               = muxed_address[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH];
assign cache_address           = {tag_entry, muxed_address[CACHE_LINE_SIZE_WIDTH-1:2]};

assign data_o                  = (state == STATE_SINGLE_READY) ? data_r : cache_data_r;
assign accept_o                = (state == STATE_IDLE);


wire valid                     = tag_data_out[CACHE_TAG_VALID_BIT];
wire dirty                     = tag_data_out[CACHE_TAG_DIRTY_BIT];

// Access is cacheable?
wire cacheable                 = ~muxed_address[ADDR_NO_CACHE_BIT] & ~muxed_address[ADDR_CACHE_BYPASS_BIT];

// Cache hit?
wire hit                       = cacheable & valid & (muxed_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW] == tag_data_out[13:0]) & (state == STATE_CHECK);

assign ack_o                   = ack | hit;

assign line_address[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH] = tag_entry;
assign line_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW] = tag_data_out[13:0];
assign line_address[CACHE_LINE_SIZE_WIDTH-1:0] = {CACHE_LINE_SIZE_WIDTH{1'b0}};

//-----------------------------------------------------------------
// Control logic
//-----------------------------------------------------------------
always @ (posedge rst_i or posedge clk_i )
begin
   if (rst_i == 1'b1)
   begin
        data_w          <= 32'h00000000;
        data_wr         <= 4'h0;
        data_rd         <= 1'b0;
        req_address     <= 32'h00000000;
        req_ack         <= 1'b0;
        req_wr          <= 4'h0;
        req_rd          <= 1'b0;
        tag_wr          <= 1'b0;
        req_flush       <= 1'b0;
        flush_single    <= 1'b0;
        fill            <= 1'b0;
        evict           <= 1'b0;
        cache_data_w    <= 32'h00000000;
        cache_wr        <= 4'b0;
        ack             <= 1'b0;
        state           <= STATE_IDLE;
   end
   else
   begin
        ack             <= 1'b0;
        tag_wr          <= 1'b0;
        fill            <= 1'b0;
        evict           <= 1'b0;
        cache_wr        <= 4'b0;
        data_wr         <= 4'b0;
        data_rd         <= 1'b0;

        if (flush_i)
            req_flush       <= 1'b1;

        case (state)

            //-----------------------------------------
            // IDLE
            //-----------------------------------------
            STATE_IDLE :
            begin      
                // Read (uncacheable)
                if (rd_i & ~cacheable)
                begin
                    // Start read single from memory
                    req_address <= address_i;
                    req_address[ADDR_CACHE_BYPASS_BIT] <= 1'b0;
                    data_rd     <= 1'b1;
                    req_rd      <= 1'b1;
                    req_wr      <= 4'b0;
                    req_ack     <= 1'b1;
                    state       <= STATE_SINGLE;
                end
                // Read (cacheable)
                else if (rd_i)
                begin
                    req_address <= address_i;
                    req_rd      <= 1'b1;
                    req_wr      <= 4'b0;
                    req_ack     <= 1'b1;
                    state       <= STATE_CHECK;
                end                
                // Write (uncacheable)
                else if (wr_i != 4'b0000 & ~cacheable)
                begin
                    // Perform write single
                    req_address <= address_i;
                    req_address[ADDR_CACHE_BYPASS_BIT] <= 1'b0;
                    data_w      <= data_i;
                    data_wr     <= wr_i;
                    req_wr      <= wr_i;
                    req_rd      <= 1'b0;                    
                    req_ack     <= 1'b1;     
                    state       <= STATE_SINGLE;
                end
                // Write (cacheable)
                else if (wr_i != 4'b0000)
                begin
                    req_address <= address_i;
                    data_w      <= data_i;
                    req_wr      <= wr_i;
                    req_rd      <= 1'b0;
                    req_ack     <= 1'b0;

                    // Early ACK
                    ack         <= 1'b1;

                    state       <= STATE_WRITE;
                end              
                // Cache flush request
                else if (flush_i | req_flush)
                begin
                    // Set to first line address
                    req_address <= 32'h00000000;
                    req_flush   <= 1'b0;
                    req_ack     <= 1'b0;
                    flush_single<= 1'b0;
                    state       <= STATE_FLUSH2;
                end
            end         
            //-----------------------------------------
            // WRITE - Wait for write-thru to complete
            //-----------------------------------------
            STATE_WRITE :
            begin            
                // Cache hit
                if (valid && 
                    (req_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW] == tag_data_out[13:0]))
                begin
                    // Update line already in cache
                    cache_data_w <= data_w;
                    cache_wr     <= req_wr;

                    // Mark line as dirty
                    tag_data_in  <= tag_data_out;
                    tag_data_in[CACHE_TAG_DIRTY_BIT] <= 1'b1;
                    tag_wr       <= 1'b1;  

                    state        <= STATE_WAIT2;
                end
                // Cache dirty
                else if (valid & dirty)
                begin
                    // Evict cache line
                    evict       <= 1'b1;
                    state       <= STATE_EVICTING;
                end                
                // Cache miss
                else
                begin
                    // Update tag memory with this line's details   
                    tag_data_in <= {1'b1, 1'b1, req_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW]};
                    tag_wr      <= 1'b1;

                    // Fill cache line
                    fill        <= 1'b1;
                    state       <= STATE_UPDATE;
                end
            end
            //-----------------------------------------
            // EVICTING - Evicting cache line
            //-----------------------------------------
            STATE_EVICTING:
            begin
                // Data ready from memory?
                if (done)
                begin
                    // Update tag memory with this new line's details   
                    tag_data_in <= {1'b1, 1'b0, req_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW]};
                    tag_wr      <= 1'b1;

                    // Fill cache line
                    fill        <= 1'b1;

                    // Evict for read?
                    if (req_rd)
                        state   <= STATE_FETCH;
                    // Evict for write
                    else
                        state   <= STATE_UPDATE;
                end
            end
            //-----------------------------------------
            // UPDATE - Update fetched cache line
            //-----------------------------------------
            STATE_UPDATE:
            begin
                // Data ready from memory?
                if (done)
                begin
                    // Update line already in cache
                    cache_data_w <= data_w;
                    cache_wr     <= req_wr;

                    // Mark line as dirty
                    tag_data_in  <= tag_data_out;
                    tag_data_in[CACHE_TAG_DIRTY_BIT] <= 1'b1;
                    tag_wr       <= 1'b1;  

                    state        <= STATE_WAIT2;
                end
            end            
            //-----------------------------------------
            // CHECK - check cache for hit or miss
            //-----------------------------------------
            STATE_CHECK :
            begin         
                // Cache hit
                if (valid && 
                    (req_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW] == tag_data_out[13:0]))
                begin
                    state       <= STATE_IDLE;
                end
                // Cache dirty
                else if (valid & dirty)
                begin
                    // Evict cache line
                    evict       <= 1'b1;
                    state       <= STATE_EVICTING;
                end                     
                // Cache miss
                else
                begin
                    // Update tag memory with this line's details   
                    tag_data_in <= {1'b1, 1'b0, req_address[CACHE_TAG_ADDR_HIGH:CACHE_TAG_ADDR_LOW]};
                    tag_wr      <= 1'b1;

                    // Fill cache line
                    fill        <= 1'b1;
                    state       <= STATE_FETCH;
                end
            end
            //-----------------------------------------
            // FETCH_SINGLE - Single access to memory
            //-----------------------------------------
            STATE_SINGLE:
            begin
                // Data ready from memory?
                if (done)
                begin
                    // Single WRITE?
                    if (~req_rd)
                    begin
                        state       <= STATE_SINGLE_READY;
                        ack         <= req_ack;                    
                    end                
                    // Dirty? Write back
                    else if (valid & dirty)
                    begin
                        // Evict cache line
                        evict       <= 1'b1;
                        flush_single<= 1'b1;
                        state       <= STATE_FLUSH4;                           
                    end
                    // Valid line, invalidate
                    else if (valid)
                    begin
                        tag_data_in  <= tag_data_out;
                        tag_data_in[CACHE_TAG_VALID_BIT] <= 1'b0;
                        tag_wr       <= 1'b1;

                        state       <= STATE_SINGLE_READY;
                        ack         <= req_ack;                        
                    end
                    else
                    begin
                        state       <= STATE_SINGLE_READY;
                        ack         <= req_ack;                    
                    end
                end
            end            
            //-----------------------------------------
            // FETCH - Fetch row from memory
            //-----------------------------------------
            STATE_FETCH :
            begin
                // Cache line filled?
                if (done)
                   state    <= STATE_WAIT;
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
                state   <= STATE_IDLE;
                ack     <= req_ack;
            end            
            //-----------------------------------------
            // SINGLE_READY - Uncached access ready
            //-----------------------------------------
            STATE_SINGLE_READY :
            begin
                // Allow extra wait state to handle write & read collision               
                state   <= STATE_IDLE;
            end
            //-----------------------------------------
            // FLUSHx - Flush dirty lines & invalidate
            //-----------------------------------------
            STATE_FLUSH1 :
            begin
                if (req_address[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH] == {CACHE_LINE_ADDR_WIDTH{1'b1}})
                begin
                    req_ack <= 1'b0;
                    state   <= STATE_WAIT;
                end
                else
                begin
                    // Increment flush line address
                    req_address[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH] <=
                    req_address[CACHE_LINE_ADDR_WIDTH + CACHE_LINE_SIZE_WIDTH - 1:CACHE_LINE_SIZE_WIDTH] + 1;

                    state   <= STATE_FLUSH2;
                end
            end
            //-----------------------------------------
            // FLUSH2 - Wait state
            //-----------------------------------------
            STATE_FLUSH2 :
            begin
                // Allow a cycle to read line state
                state   <= STATE_FLUSH3;
            end
            //-----------------------------------------
            // FLUSH3 - Check if line dirty & flush
            //-----------------------------------------            
            STATE_FLUSH3 :
            begin
                // Dirty line? Evict line first
                if (dirty)
                begin
                    // Evict cache line
                    evict       <= 1'b1;
                    state       <= STATE_FLUSH4;                
                end
                // Not dirty? Just invalidate
                else
                begin
                    tag_data_in  <= tag_data_out;
                    tag_data_in[CACHE_TAG_VALID_BIT] <= 1'b0;
                    tag_wr       <= 1'b1;

                    if (flush_single)
                        state    <= STATE_WAIT;
                    else
                        state    <= STATE_FLUSH1;
                end
            end
            //-----------------------------------------
            // FLUSH4 - Wait for line flush to complete
            //-----------------------------------------            
            STATE_FLUSH4 :
            begin
                // Cache line filled?
                if (done)
                begin
                    // Invalidate line
                    tag_data_in  <= tag_data_out;
                    tag_data_in[CACHE_TAG_VALID_BIT] <= 1'b0;
                    tag_data_in[CACHE_TAG_DIRTY_BIT] <= 1'b0;
                    tag_wr       <= 1'b1;

                    if (flush_single)
                    begin
                        state   <= STATE_SINGLE_READY;
                        ack     <= req_ack;
                    end
                    else                    
                        state   <= STATE_FLUSH1;
                end
            end          
            default:
                ;
           endcase
   end
end

//-----------------------------------------------------------------
// Instantiation
//-----------------------------------------------------------------

altor32_dcache_mem_if
#(
    .CACHE_LINE_SIZE_WIDTH(CACHE_LINE_SIZE_WIDTH),
    .CACHE_LINE_WORDS_IDX_MAX(CACHE_LINE_WORDS_IDX_MAX)
)
u_mem_if
( 
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    // Cache interface
    .address_i(muxed_address),
    .data_i(data_w),
    .data_o(data_r),
    .fill_i(fill),
    .evict_i(evict),
    .evict_addr_i(line_address),
    .rd_single_i(data_rd),
    .wr_single_i(data_wr),
    .done_o(done),

    // Cache memory (fill/evict)
    .cache_addr_o(cache_update_addr),
    .cache_data_o(cache_update_data_w),
    .cache_data_i(cache_update_data_r),
    .cache_wr_o(cache_update_wr),    
    
    // Memory interface (slave)
    .mem_addr_o(mem_addr_o),
    .mem_data_i(mem_data_i),
    .mem_data_o(mem_data_o),
    .mem_burst_o(mem_burst_o),
    .mem_rd_o(mem_rd_o),
    .mem_wr_o(mem_wr_o),
    .mem_accept_i(mem_accept_i),
    .mem_ack_i(mem_ack_i)
);
    
// Tag memory    
altor32_ram_sp  
#(
    .WIDTH(CACHE_TAG_WIDTH),
    .SIZE(CACHE_LINE_ADDR_WIDTH)
) 
u1_tag_mem
(
    .clk_i(clk_i), 
    .dat_o(tag_data_out), 
    .dat_i(tag_data_in), 
    .adr_i(tag_entry), 
    .wr_i(tag_wr)
);
   
// Data memory   
altor32_ram_dp  
#(
    .WIDTH(8),
    .SIZE(CACHE_DWIDTH)
) 
u2_data_mem0
(
    .aclk_i(clk_i), 
    .aadr_i(cache_address), 
    .adat_o(cache_data_r[7:0]), 
    .adat_i(cache_data_w[7:0]),     
    .awr_i(cache_wr[0]),
    
    .bclk_i(clk_i), 
    .badr_i(cache_update_addr[CACHE_DWIDTH+2-1:2]), 
    .bdat_o(cache_update_data_r[7:0]), 
    .bdat_i(cache_update_data_w[7:0]),     
    .bwr_i(cache_update_wr)
);

altor32_ram_dp  
#(
    .WIDTH(8),
    .SIZE(CACHE_DWIDTH)
) 
u2_data_mem1
(
    .aclk_i(clk_i), 
    .aadr_i(cache_address), 
    .adat_o(cache_data_r[15:8]), 
    .adat_i(cache_data_w[15:8]),     
    .awr_i(cache_wr[1]),
    
    .bclk_i(clk_i), 
    .badr_i(cache_update_addr[CACHE_DWIDTH+2-1:2]), 
    .bdat_o(cache_update_data_r[15:8]), 
    .bdat_i(cache_update_data_w[15:8]),     
    .bwr_i(cache_update_wr)   
);

altor32_ram_dp  
#(
    .WIDTH(8),
    .SIZE(CACHE_DWIDTH)
) 
u2_data_mem2
(
    .aclk_i(clk_i), 
    .aadr_i(cache_address), 
    .adat_o(cache_data_r[23:16]), 
    .adat_i(cache_data_w[23:16]),     
    .awr_i(cache_wr[2]),
    
    .bclk_i(clk_i), 
    .badr_i(cache_update_addr[CACHE_DWIDTH+2-1:2]), 
    .bdat_o(cache_update_data_r[23:16]), 
    .bdat_i(cache_update_data_w[23:16]),     
    .bwr_i(cache_update_wr)       
);

altor32_ram_dp  
#(
    .WIDTH(8),
    .SIZE(CACHE_DWIDTH)
) 
u2_data_mem3
(
    .aclk_i(clk_i), 
    .aadr_i(cache_address), 
    .adat_o(cache_data_r[31:24]), 
    .adat_i(cache_data_w[31:24]),     
    .awr_i(cache_wr[3]),
    
    .bclk_i(clk_i), 
    .badr_i(cache_update_addr[CACHE_DWIDTH+2-1:2]), 
    .bdat_o(cache_update_data_r[31:24]), 
    .bdat_i(cache_update_data_w[31:24]),     
    .bwr_i(cache_update_wr)       
);

endmodule
