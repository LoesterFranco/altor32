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
// Module - Data Cache Memory Interface
//-----------------------------------------------------------------
module altor32_dcache_mem_if
( 
    input           clk_i /*verilator public*/, 
    input           rst_i /*verilator public*/, 
    
    // Cache interface
    input [31:0]    address_i /*verilator public*/,
    input [31:0]    data_i /*verilator public*/,
    output [31:0]   data_o /*verilator public*/,
    input           fill_i /*verilator public*/,
    input           evict_i /*verilator public*/,
    input  [31:0]   evict_addr_i /*verilator public*/,
    input           rd_single_i /*verilator public*/,
    input [3:0]     wr_single_i /*verilator public*/,
    output          done_o /*verilator public*/,

    // Cache memory (fill/evict)
    output [31:2]   cache_addr_o /*verilator public*/,
    output [31:0]   cache_data_o /*verilator public*/,
    input  [31:0]   cache_data_i /*verilator public*/,
    output          cache_wr_o /*verilator public*/,
    
    // Memory interface (slave)
    output [31:0]   mem_addr_o /*verilator public*/,
    input  [31:0]   mem_data_i /*verilator public*/,
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
parameter CACHE_LINE_SIZE_WIDTH     = 5;                         /* 5-bits -> 32 entries */
parameter CACHE_LINE_WORDS_IDX_MAX  = CACHE_LINE_SIZE_WIDTH - 2; /* 3-bit -> 8 words */

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------

reg [31:2]                      cache_addr_o;
reg [31:0]                      cache_data_o;
reg                             cache_wr_o;
  
reg [31:CACHE_LINE_SIZE_WIDTH]  line_address;
reg [CACHE_LINE_SIZE_WIDTH-3:0] line_word;

reg [31:0]                      data_o;
reg                             done_o;

reg [31:0]                      mem_addr_o;
reg [31:0]                      mem_data_o;
reg                             mem_rd_o;
reg [3:0]                       mem_wr_o;
reg                             mem_burst_o;

// Current state
parameter STATE_IDLE        = 0;
parameter STATE_FETCH       = 1;
parameter STATE_READ_WAIT   = 2;
parameter STATE_WRITE       = 3;
parameter STATE_WRITE_WAIT  = 4;
parameter STATE_READ_SINGLE = 5;
parameter STATE_WRITE_SINGLE= 6;

reg [3:0] state;

//-----------------------------------------------------------------
// Control logic
//-----------------------------------------------------------------
reg [CACHE_LINE_SIZE_WIDTH-3:0] v_line_word;

always @ (posedge rst_i or posedge clk_i )
begin
   if (rst_i == 1'b1)
   begin
        line_address    <= {32-CACHE_LINE_SIZE_WIDTH{1'b0}};
        line_word       <= {CACHE_LINE_SIZE_WIDTH-2{1'b0}};
        mem_addr_o      <= 32'h00000000;
        mem_data_o      <= 32'h00000000;
        mem_wr_o        <= 4'h0;
        mem_rd_o        <= 1'b0;
        mem_burst_o     <= 1'b0;
        cache_addr_o    <= 30'h00000000;
        cache_data_o    <= 32'h00000000;
        cache_wr_o      <= 1'b0;
        done_o          <= 1'b0;
        data_o          <= 32'h00000000;
        state           <= STATE_IDLE;
   end
   else
   begin
   
        if (mem_accept_i)
        begin
            mem_rd_o        <= 1'b0;
            mem_wr_o        <= 4'h0;
        end

        done_o          <= 1'b0;
        cache_wr_o      <= 1'b0;
        
        case (state)

            //-----------------------------------------
            // IDLE
            //-----------------------------------------
            STATE_IDLE :
            begin
                // Perform cache evict (write)     
                if (evict_i)
                begin
                    line_address  <= evict_addr_i[31:CACHE_LINE_SIZE_WIDTH];
                    line_word     <= {CACHE_LINE_SIZE_WIDTH-2{1'b0}};

                    // Read data from cache
                    cache_addr_o  <= {evict_addr_i[31:CACHE_LINE_SIZE_WIDTH], {CACHE_LINE_SIZE_WIDTH-2{1'b0}}};
                    state         <= STATE_READ_WAIT;
                end
                // Perform cache fill (read)
                else if (fill_i)
                begin
                    line_address <= address_i[31:CACHE_LINE_SIZE_WIDTH];
                    line_word    <= {CACHE_LINE_SIZE_WIDTH-2{1'b0}};
                    
                    // Start fetch from memory
                    mem_addr_o   <= {address_i[31:CACHE_LINE_SIZE_WIDTH], {CACHE_LINE_SIZE_WIDTH{1'b0}}};
                    mem_rd_o     <= 1'b1;
                    mem_burst_o  <= 1'b1;
                    state        <= STATE_FETCH;
                end                
                // Read single
                else if (rd_single_i)
                begin
                    // Start fetch from memory
                    mem_addr_o   <= address_i;
                    mem_data_o   <= 32'b0;
                    mem_rd_o     <= 1'b1;
                    mem_burst_o  <= 1'b0;
                    state        <= STATE_READ_SINGLE;
                end
                // Write single
                else if (|wr_single_i)
                begin
                    // Start fetch from memory
                    mem_addr_o   <= address_i;
                    mem_data_o   <= data_i;
                    mem_wr_o     <= wr_single_i;
                    mem_burst_o  <= 1'b0;
                    state        <= STATE_WRITE_SINGLE;
                end
            end
            //-----------------------------------------
            // FETCH - Fetch line from memory
            //-----------------------------------------
            STATE_FETCH :
            begin
                // Data ready from memory?
                if (mem_ack_i && mem_rd_o == 1'b0)
                begin
                    // Write data into cache
                    cache_addr_o    <= {line_address, line_word};
                    cache_data_o    <= mem_data_i;
                    cache_wr_o      <= 1'b1;        
                
                    // Line fetch complete?
                    if (line_word == {CACHE_LINE_WORDS_IDX_MAX{1'b1}})
                    begin
                        done_o      <= 1'b1;
                        state       <= STATE_IDLE;
                    end
                    // Fetch next word for line
                    else
                    begin
                        v_line_word = line_word + 1'b1;
                        line_word   <= v_line_word;
                        
                        mem_addr_o <= {line_address, v_line_word, 2'b00};
                        mem_rd_o   <= 1'b1;
                        
                        if (line_word == ({CACHE_LINE_WORDS_IDX_MAX{1'b1}}-1))
                        begin
                            mem_burst_o <= 1'b0;
                        end
                    end
                end
            end
            //-----------------------------------------
            // READ_WAIT - Wait for data from cache
            //-----------------------------------------
            STATE_READ_WAIT :
            begin
                // Not used yet, but set for start of burst
                mem_burst_o  <= 1'b1;
                state        <= STATE_WRITE;
            end
            //-----------------------------------------
            // WRITE - Write word to memory
            //-----------------------------------------
            STATE_WRITE :
            begin
                // Write data into memory from cache
                mem_addr_o   <= {line_address, line_word, 2'b00};
                mem_data_o   <= cache_data_i;
                mem_wr_o     <= 4'b1111;                        

                // Setup next word read from cache
                v_line_word = line_word + 1'b1;
                cache_addr_o <= {line_address, v_line_word};    

                state        <= STATE_WRITE_WAIT;
            end            
            //-----------------------------------------
            // WRITE_WAIT - Wait for write to complete
            //-----------------------------------------
            STATE_WRITE_WAIT:
            begin
                // Write to memory complete
                if (mem_ack_i && mem_wr_o == 4'b0)
                begin
                    // Line write complete?
                    if (line_word == {CACHE_LINE_WORDS_IDX_MAX{1'b1}})
                    begin
                        done_o      <= 1'b1;
                        state       <= STATE_IDLE;
                    end
                    // Fetch next word for line
                    else
                    begin
                        line_word   <= line_word + 1'b1;
                        state       <= STATE_WRITE;
                        
                        if (line_word == ({CACHE_LINE_WORDS_IDX_MAX{1'b1}}-1))
                            mem_burst_o <= 1'b0;
                    end
                end
            end            
            //-----------------------------------------
            // READ_SINGLE - Single access to memory
            //-----------------------------------------
            STATE_READ_SINGLE:
            begin
                // Data ready from memory?
                if (mem_ack_i && mem_rd_o == 1'b0)
                begin
                    data_o      <= mem_data_i;
                    done_o      <= 1'b1;
                    state       <= STATE_IDLE;
                end
            end
            //-----------------------------------------
            // WRITE_SINGLE - Single access to memory
            //-----------------------------------------
            STATE_WRITE_SINGLE:
            begin
                if (mem_ack_i && mem_wr_o == 4'b0)
                begin
                    done_o      <= 1'b1;
                    state       <= STATE_IDLE;
                end
            end             
            default:
                ;
           endcase
   end
end

endmodule
