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
// Module - Cache substitute (used when ICache disabled)
//-----------------------------------------------------------------
module altor32_noicache 
( 
    input                       clk_i /*verilator public*/,
    input                       rst_i /*verilator public*/,
    
    // Processor interface
    input                       rd_i /*verilator public*/,
    input [31:0]                pc_i /*verilator public*/,
    output [31:0]               instruction_o /*verilator public*/,
    output                      valid_o /*verilator public*/,
    
    // Memory interface (slave)
    output reg [31:0]           mem_addr_o /*verilator public*/,
    input [31:0]                mem_data_i /*verilator public*/,
    output reg                  mem_burst_o /*verilator public*/,
    output reg                  mem_rd_o /*verilator public*/,
    input                       mem_accept_i/*verilator public*/,
    input                       mem_ack_i/*verilator public*/
);

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------

// Current state
parameter STATE_CHECK       = 0;
parameter STATE_FETCH       = 1;
reg [1:0]                   state;

assign valid_o              = mem_ack_i;
assign instruction_o        = mem_data_i;

//-----------------------------------------------------------------
// Control logic
//-----------------------------------------------------------------
always @ (posedge rst_i or posedge clk_i )
begin
   if (rst_i == 1'b1)
   begin
        mem_addr_o      <= 32'h00000000;
        mem_rd_o        <= 1'b0;
        mem_burst_o     <= 1'b0;
        state           <= STATE_CHECK;   
   end
   else
   begin
   
        if (mem_accept_i)
            mem_rd_o    <= 1'b0;
        
        case (state)

            //-----------------------------------------
            // CHECK - check cache for hit or miss
            //-----------------------------------------
            STATE_CHECK :
            begin
                // Start fetch from memory
                mem_addr_o  <= pc_i;
                mem_rd_o    <= 1'b1;
                mem_burst_o <= 1'b0;
                state       <= STATE_FETCH;
            end
            //-----------------------------------------
            // FETCH - Fetch row from memory
            //-----------------------------------------
            STATE_FETCH :
            begin
                // Data ready from memory?
                if (mem_ack_i)
                    state   <= STATE_CHECK;
            end
            
            default:
                ;
           endcase
   end
end

endmodule

