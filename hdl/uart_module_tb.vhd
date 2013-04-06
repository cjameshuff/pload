
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.UART_pkg.all;

entity UART_TB is
end UART_TB;

architecture Behavioral of UART_TB is
    signal SYS_CLK:  std_logic := '0';
    signal RESET:    std_logic := '1';
    
    signal RX_VALID: std_logic;
    signal RX_BYTE:  std_logic_vector(7 downto 0);
    
    signal TX_BYTE:  std_logic_vector(7 downto 0);
    signal XMIT:     std_logic;
    signal BUSY:     std_logic;
    
    signal RX_IN:    std_logic;
    signal TX_OUT:   std_logic;
    
begin
    UART_0: UART
    generic map(
        BAUD_DIV => 16
    )
    port map(
        SYS_CLK => SYS_CLK,
        RESET => RESET,
        
        RX_VALID => RX_VALID,
        RX_BYTE => RX_BYTE,
        
        TX_BYTE => TX_BYTE,
        XMIT => XMIT,
        BUSY => BUSY,
        
        RX_IN => RX_IN,
        TX_OUT => TX_OUT
    );
    
    process
    begin
        for i in 0 to 10240 loop
            SYS_CLK <= '1';
            wait for 1 ns;
            SYS_CLK <= '0';
            wait for 1 ns;
        end loop;
        wait; -- Wait forever; this will finish the simulation.
    end process;
    
end Behavioral;
