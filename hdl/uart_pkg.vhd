
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package UART_pkg is
    component UART is
        generic(
            BAUD_DIV: integer
        );
        port (
            SYS_CLK:  in std_logic;
            RESET:    in std_logic;
            
            RX_VALID: out std_logic;
            RX_BYTE:  out std_logic_vector(7 downto 0);
            
            TX_BYTE:  in std_logic_vector(7 downto 0);
            XMIT:     in std_logic;
            TX_BUSY:  out std_logic;
            
            RX_IN:    in std_logic;
            TX_OUT:   out std_logic
        );
    end component;
end package UART_pkg;
