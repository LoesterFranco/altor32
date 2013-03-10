-------------------------------------------------------------------
--                           AltOR32 
--              Alternative Lightweight OpenRisc 
--                     Ultra-Embedded.com
--                   Copyright 2011 - 2013
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
-- Copyright (C) 2011 - 2013 Ultra-Embedded.com
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.peripherals.all;

entity fpga_top is
generic 
(
    OSC_MHZ     : integer := 32;
    -- Target CPU MHz (must be a multiple of 2)
    CPU_MHZ     : integer := 32
);
port 
(
    W1A         : inout std_logic_vector(15 downto 0);
    W1B         : inout std_logic_vector(15 downto 0);
    W2C         : inout std_logic_vector(15 downto 0);
    rx          : in    std_logic;
    tx          : inout std_logic;
    clk         : in    std_logic;
    flash_cs    : out   std_logic;
    flash_si    : out   std_logic;
    flash_so    : in    std_logic;
    flash_sck   : out   std_logic    
);
end fpga_top;

architecture Behavioral of fpga_top is

-----------------------------------------------
-- Component Definitions
-----------------------------------------------
component ram
generic
(
    -- Number of 8KB blocks of internal RAM, up to 64KB (1 to 8)
    block_count         : integer := 1
); 
port
(
    -- Port A
    clka_i              : in std_logic;
    ena_i               : in std_logic;
    wea_i               : in std_logic_vector(3 downto 0);
    addra_i             : in std_logic_vector(31 downto 2);
    dataa_i             : in std_logic_vector(31 downto 0);
    dataa_o             : out std_logic_vector(31 downto 0);

    -- Port B
    clkb_i              : in std_logic;
    enb_i               : in std_logic;
    web_i               : in std_logic_vector(3 downto 0);
    addrb_i             : in std_logic_vector(31 downto 2);
    datab_i             : in std_logic_vector(31 downto 0);
    datab_o             : out std_logic_vector(31 downto 0)
);
end component;

-----------------------------------------------
-- Signals
-----------------------------------------------
signal cpu_clk              : std_logic;
signal reset                : std_logic:= '1';
signal rst_next             : std_logic:= '1';

-- Block RAM interface
signal bram_mem_address     : std_logic_vector(31 downto 0);
signal bram_mem_data_w      : std_logic_vector(31 downto 0);
signal bram_mem_data_r      : std_logic_vector(31 downto 0);
signal bram_mem_wr          : std_logic_vector(3 downto 0);

-- I/O peripheral bus
signal io_address           : std_logic_vector(31 downto 0);
signal io_data_w            : std_logic_vector(31 downto 0);
signal io_data_r            : std_logic_vector(31 downto 0);
signal io_wr                : std_logic_vector(3 downto 0);
signal io_rd                : std_logic;

-- GPIO ports
signal gpio_w1a_port_out    : std_logic_vector(15 downto 0);
signal gpio_w1a_port_in     : std_logic_vector(15 downto 0);
signal gpio_w1a_port_raw    : std_logic_vector(15 downto 0);
signal gpio_w1a_port_out_en : std_logic_vector(15 downto 0);

signal gpio_w1b_port_out    : std_logic_vector(15 downto 0);
signal gpio_w1b_port_in     : std_logic_vector(15 downto 0);
signal gpio_w1b_port_raw    : std_logic_vector(15 downto 0);
signal gpio_w1b_port_out_en : std_logic_vector(15 downto 0);

signal gpio_w2c_port_out    : std_logic_vector(15 downto 0);
signal gpio_w2c_port_in     : std_logic_vector(15 downto 0);
signal gpio_w2c_port_raw    : std_logic_vector(15 downto 0);
signal gpio_w2c_port_out_en : std_logic_vector(15 downto 0);

-----------------------------------------------
-- I/O Register Map (from 0x13000000)
-----------------------------------------------
constant GPIO_W1A_OUT      : std_logic_vector(7 downto 0)  := X"10";
constant GPIO_W1A_IN       : std_logic_vector(7 downto 0)  := X"14";
constant GPIO_W1A_DIR      : std_logic_vector(7 downto 0)  := X"1C";

constant GPIO_W1B_OUT      : std_logic_vector(7 downto 0)  := X"20";
constant GPIO_W1B_IN       : std_logic_vector(7 downto 0)  := X"24";
constant GPIO_W1B_DIR      : std_logic_vector(7 downto 0)  := X"2C";

constant GPIO_W2C_OUT      : std_logic_vector(7 downto 0)  := X"30";
constant GPIO_W2C_IN       : std_logic_vector(7 downto 0)  := X"34";
constant GPIO_W2C_DIR      : std_logic_vector(7 downto 0)  := X"3C";

begin

-----------------------------------------------
-- Instantiation
-----------------------------------------------
cpu_clk <= clk;

-- 24KB Block RAM (0x10000000 - 0x10006000)
U2_RAM: ram 
generic map 
(
    block_count         => 3
)
port map 
( 
    clka_i      => cpu_clk,
    ena_i       => '1', 
    wea_i       => bram_mem_wr, 
    addra_i     => bram_mem_address(31 downto 2),
    dataa_i     => bram_mem_data_w, 
    dataa_o     => bram_mem_data_r,
    
    clkb_i      => cpu_clk,
    enb_i       => '1', 
    web_i       => "0000", 
    addrb_i     => (others=>'0'),
    datab_i     => (others=>'0'), 
    datab_o     => open
);   

-- CPU SOC
U3_CPU: soc_core
generic map 
(
    CLK_KHZ             => (CPU_MHZ * 1000),
    UART_BAUD           => 115200,
    BOOT_VECTOR         => X"10000000",   
    ISR_VECTOR          => X"10002000",
    REGISTER_FILE_TYPE  => "XILINX",
    ENABLE_UART         => "ENABLED",
    ENABLE_SPI_FLASH    => "ENABLED",
    EXTERNAL_INTERRUPTS => 1
)
port map 
(
    -- General - clocking & reset
    clk_i               => cpu_clk,
    rst_i               => reset,
    en_i                => '1',
    ext_intr_i(0)       => '0',
    fault_o             => open,
    break_o             => open,

    -- UART
    uart_tx_o           => tx,
    uart_rx_i           => rx,
    
    -- BootRAM
    int_mem_addr_o      => bram_mem_address,
    int_mem_data_o      => bram_mem_data_w,
    int_mem_data_i      => bram_mem_data_r,
    int_mem_wr_o        => bram_mem_wr,    
    int_mem_rd_o        => open,
    int_mem_pause_i     => '0',

    -- External IO
    ext_io_addr_o       => io_address,
    ext_io_data_o       => io_data_w,
    ext_io_data_i       => io_data_r,
    ext_io_wr_o         => io_wr,
    ext_io_rd_o         => io_rd,
    ext_io_pause_i      => '0',
    
    -- External Memory
    ext_mem_addr_o      => open,
    ext_mem_data_o      => open,
    ext_mem_data_i      => X"00000000", 
    ext_mem_wr_o        => open,
    ext_mem_rd_o        => open,
    ext_mem_pause_i     => '0',    
    
    -- SPI Flash
    flash_cs_o          => flash_cs,
    flash_si_o          => flash_si,
    flash_so_i          => flash_so,
    flash_sck_o         => flash_sck,
    
    -- Debug UART Output
    dbg_uart_data_o     => open,
    dbg_uart_wr_o       => open
);
  
-----------------------------------------------
-- Implementation
-----------------------------------------------

-- Reset Generator
process (cpu_clk)
    
begin
    if (rising_edge(cpu_clk)) then
        if (rst_next = '0') then
            reset       <= '0';
        else
            rst_next    <= '0';
        end if;
    end if;
end process;

-----------------------------------------------
-- IO memory space WRITE handler
-----------------------------------------------  
process (reset,cpu_clk)

begin
    if (reset = '1') then 
        
        -- GPIO
        gpio_w1a_port_out            <= (others=>'0');
        gpio_w1a_port_out_en         <= (others=>'1');
        
        gpio_w1b_port_out            <= (others=>'0');
        gpio_w1b_port_out_en         <= (others=>'1');
        
        gpio_w2c_port_out            <= (others=>'0');
        gpio_w2c_port_out_en         <= (others=>'1');                
        
    elsif (rising_edge(cpu_clk)) then
        
        -- IO Write Cycle
        if (io_wr /= "0000") then                
                                
            case io_address(7 downto 0) is
            
                when GPIO_W1A_OUT =>
                    gpio_w1a_port_out        <= io_data_w(15 downto 0);
                    
                when GPIO_W1A_DIR =>
                    gpio_w1a_port_out_en     <= io_data_w(15 downto 0);
                    
                when GPIO_W1B_OUT =>
                    gpio_w1b_port_out        <= io_data_w(15 downto 0);
                    
                when GPIO_W1B_DIR =>
                    gpio_w1b_port_out_en     <= io_data_w(15 downto 0);     
                    
                when GPIO_W2C_OUT =>
                    gpio_w2c_port_out        <= io_data_w(15 downto 0);
                    
                when GPIO_W2C_DIR =>
                    gpio_w2c_port_out_en     <= io_data_w(15 downto 0);                                   
                    
                when others => 
                
            end case;
        
        end if;        
        
    end if;
end process;

-----------------------------------------------
-- IO memory space READ handler
----------------------------------------------- 
process (reset,cpu_clk)

begin
    if (reset = '1') then 
        
        io_data_r           <= X"00000000";
        gpio_w1a_port_in    <= X"0000";
        gpio_w1b_port_in    <= X"0000";
        gpio_w2c_port_in    <= X"0000";
        
    elsif (rising_edge(cpu_clk)) then
    
        gpio_w1a_port_in <= gpio_w1a_port_raw;
        gpio_w1b_port_in <= gpio_w1b_port_raw;
        gpio_w2c_port_in <= gpio_w2c_port_raw;
    
        -- Read cycle?
        if (io_rd = '1') then         
                                
            case io_address(7 downto 0) is
                
                when GPIO_W1A_OUT =>
                    io_data_r        <= X"0000" & gpio_w1a_port_out; 
                            
                when GPIO_W1A_DIR =>
                    io_data_r        <= X"0000" & gpio_w1a_port_out_en; 
                
                when GPIO_W1A_IN  =>         
                    io_data_r        <= X"0000" & gpio_w1a_port_in;     
                    
                when GPIO_W1B_OUT =>
                    io_data_r        <= X"0000" & gpio_w1b_port_out; 
                            
                when GPIO_W1B_DIR =>
                    io_data_r        <= X"0000" & gpio_w1b_port_out_en; 
                
                when GPIO_W1B_IN  =>         
                    io_data_r        <= X"0000" & gpio_w1b_port_in;       
                    
                when GPIO_W2C_OUT =>
                    io_data_r        <= X"0000" & gpio_w2c_port_out; 
                            
                when GPIO_W2C_DIR =>
                    io_data_r        <= X"0000" & gpio_w2c_port_out_en; 
                
                when GPIO_W2C_IN  =>         
                    io_data_r        <= X"0000" & gpio_w2c_port_in;                                       
                    
                when others => 
                    io_data_r        <= X"00000000";
            end case;
            
        end if;
    
  end if;    
  
end process;

-----------------------------------------------
-- External Interface
----------------------------------------------- 

-- GPIO port is connected to W1A
gpio_loop: for n in 15 downto 0 generate
    W1A(n)              <= gpio_w1a_port_out(n)  when gpio_w1a_port_out_en(n)  = '1' else 'Z';
    gpio_w1a_port_raw(n)<= W1A(n);
    
    W1B(n)              <= gpio_w1b_port_out(n)  when gpio_w1b_port_out_en(n)  = '1' else 'Z';
    gpio_w1b_port_raw(n)<= W1B(n);
    
    W2C(n)              <= gpio_w2c_port_out(n)  when gpio_w2c_port_out_en(n)  = '1' else 'Z';
    gpio_w2c_port_raw(n)<= W2C(n);        
end generate gpio_loop;

end Behavioral;
