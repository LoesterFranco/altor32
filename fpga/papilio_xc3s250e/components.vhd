-------------------------------------------------------------------
--                           AltOR32 
--              Alternative Lightweight OpenRisc 
--                            V0.1
--                     Ultra-Embedded.com
--                   Copyright 2011 - 2012
--
--               Email: admin@ultra-embedded.com
--
--                       License: LGPL
--
-- If you would like a version with a different license for use 
-- in commercial projects please contact the above email address 
-- for more details.
-------------------------------------------------------------------
--
-- Copyright (C) 2011 - 2012 Ultra-Embedded.com
--
-- This source file may be used and distributed without         
-- restriction provided that this copyright statement is not    
-- removed from the file and that any derivative work contains  
-- the original copyright notice and the associated disclaimer. 
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, write to the 
-- Free Software Foundation, Inc., 59 Temple Place, Suite 330, 
-- Boston, MA  02111-1307  USA              
-------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package peripherals is

-------------------------------------------------------------------
-- Components:
-------------------------------------------------------------------
component alt_soc
generic
(
    CLK_KHZ             : integer := 12288;
    UART_BAUD           : integer := 115200;
    SPI_FLASH_CLK_KHZ   : integer := 12288 / 2;
    EXTERNAL_INTERRUPTS : integer := 1;
    CORE_ID             : std_logic_vector := X"00000000";
    BOOT_VECTOR         : std_logic_vector := X"00000000";
    ISR_VECTOR          : std_logic_vector := X"0000003C"    
);
port
(
    -- General - clocking & rst_i
    clk_i               : in std_logic;
    rst_i               : in std_logic;   
    en_i                : in std_logic;
    ext_intr_i          : in std_logic_vector(EXTERNAL_INTERRUPTS-1 downto 0);
    fault_o             : out std_logic;
    break_o             : out std_logic;

    -- UART
    uart_tx_o           : out std_logic;   
    uart_rx_i           : in  std_logic;
    
    -- BootRAM
    int_mem_addr_o      : out std_logic_vector(32-1 downto 0);
    int_mem_data_o      : out std_logic_vector(32-1 downto 0);
    int_mem_data_i      : in  std_logic_vector(32-1 downto 0);
    int_mem_wr_o        : out std_logic_vector(3 downto 0);    
    int_mem_rd_o        : out std_logic;    
    int_mem_pause_i     : in  std_logic;
    
    -- External IO
    ext_io_addr_o       : out std_logic_vector(32-1 downto 0);
    ext_io_data_o       : out std_logic_vector(32-1 downto 0);
    ext_io_data_i       : in  std_logic_vector(32-1 downto 0);
    ext_io_wr_o         : out std_logic_vector(3 downto 0);
    ext_io_rd_o         : out std_logic;   
    ext_io_pause_i      : in  std_logic;
    
    -- SPI Flash
    flash_cs_o          : out std_logic;   
    flash_si_o          : out std_logic;
    flash_so_i          : in  std_logic;   
    flash_sck_o         : out std_logic;        
    
    -- Debug Access
    dbg_pc_o            : out std_logic_vector(31 downto 0);
    
    -- Debug UART Output
    dbg_uart_data_o     : out std_logic_vector(7 downto 0);
    dbg_uart_wr_o       : out std_logic                
);
end component;

component ClockDCM is
generic 
(
    CLK_IN_MHZ          : integer := 32;
    CLK_OUT_MHZ         : integer := 64
);
port
( 
    CLKIN_IN            : in    std_logic; 
    CLKFX_OUT           : out   std_logic; 
    CLKIN_IBUFG_OUT     : out   std_logic
);
end component;

end peripherals;
                                         
package body peripherals is
                                        
end; --package body
