
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
 
entity Main_TB is
end Main_TB;
 
architecture Behavioral of Main_TB is
    component Main
        port(
            XTAL_CLK: in std_logic;
            
            UART_RX:  in  std_logic;
            UART_TX:  out std_logic;
        
            DF_MISO: in  std_logic;
            DF_MOSI: out std_logic;
            DF_SCK:  out std_logic;
            DF_SS:   out std_logic
        );
    end component;
    
    constant SYS_CLK_period: time := 31.25 ns;
    
    
    signal XTAL_CLK: std_logic := '0';
    
    signal UART_RX: std_logic := '0';
    signal UART_TX: std_logic;
    
    signal DF_MISO: std_logic;
    signal DF_MOSI: std_logic;
    signal DF_SCK:  std_logic;
    signal DF_SS:   std_logic;
    
begin
    uut: Main
    port map(
        UART_RX  => UART_RX,
        UART_TX  => UART_TX,
        XTAL_CLK => XTAL_CLK,
        DF_MISO  => DF_MISO,
        DF_MOSI  => DF_MOSI,
        DF_SCK   => DF_SCK,
        DF_SS    => DF_SS
    );
    
    SYS_CLK_process: process
    begin
        XTAL_CLK <= '0';
        wait for SYS_CLK_period/2;
        XTAL_CLK <= '1';
        wait for SYS_CLK_period/2;
    end process;
    
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
--         wait for 100 ns;
        
        wait for SYS_CLK_period*1000000;
        
        wait;
    end process; -- stim_proc
    
end Behavioral;
