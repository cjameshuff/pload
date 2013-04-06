----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:46:42 09/24/2012 
-- Design Name: 
-- Module Name:    main - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------


-- System outline:
-- 
-- Main {
--   System_Controller {
--     Comm_Engine {
--       UART_Module
--       CRC_Engine
--     }
--     DFlash_Controller {SPI_Master}
--   }
-- }



library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.CommEngine_pkg.all;


entity Main is
    port(
        UART_RX:  in std_logic;
        UART_TX:  out std_logic;
        
        XTAL_CLK:  in std_logic;
        
        DF_MISO: in  std_logic;
        DF_MOSI: out std_logic;
        DF_SCK:  out std_logic;
        DF_SS:   out std_logic
    );
end Main;

architecture Behavioral of Main is
    component MainClk
        port(
            CLKIN_32MHZ: in  std_logic;
            RESET_IN:    in  std_logic;
            
            CLK_8MHZ:    out std_logic;
            CLK_64MHZ:   out std_logic;
            CLK_256MHZ:  out std_logic;
            
            RESET_OUT:   out std_logic
        );
    end component;
    
    
    signal CLK_8MHZ: std_logic;
    signal CLK_64MHZ: std_logic;
    
    signal CLOCK_RESET: std_logic := '0';
    signal SYS_RESET: std_logic;
    
begin
    MainClk_0: MainClk
        port map(
            CLKIN_32MHZ    => XTAL_CLK,
            RESET_IN       => CLOCK_RESET,
            CLK_8MHZ       => CLK_8MHZ,
            CLK_256MHZ     => open,
            CLK_64MHZ      => CLK_64MHZ,
            RESET_OUT      => SYS_RESET
        );
    
    CommEngine_0: CommEngine
        port map(
            RESET => SYS_RESET,
            SYS_CLK => CLK_64MHZ,
            
            UART_RX  => UART_RX,
            UART_TX => UART_TX,
            
            DF_MISO => DF_MISO,
            DF_MOSI => DF_MOSI,
            DF_SCK  => DF_SCK,
            DF_SS   => DF_SS
        );
    
end Behavioral;

