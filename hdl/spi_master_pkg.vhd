
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

package SPI_Master_pkg is
    component SPI_Master is
        generic(
            BAUD_DIV: integer;
            CPOL:     std_logic;
            CPHA:     std_logic
        );
        port(
            RESET:   in std_logic;-- asynchronous reset
            SYS_CLK: in std_logic;
            
            RX_VALID: out std_logic;
            RX_BYTE:  out std_logic_vector(7 downto 0);
            
            TX_BYTE:  in std_logic_vector(7 downto 0);
            XMIT:     in std_logic;
            BUSY:     out std_logic;
            
            MISO:  in  std_logic;
            MOSI:  out std_logic;
            SCK:   out std_logic
        );
    end component;
end package SPI_Master_pkg;

