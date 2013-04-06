
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

package CRC_Engine_pkg is
    component CRC_Engine is
        port(
            RESET:   in std_logic;-- asynchronous reset
            SYS_CLK: in std_logic;
            
            DATA:    in std_logic_vector(7 downto 0);
            WRITE:   in std_logic;
            CLEAR:   in std_logic;
            
            CRC_OUT: out std_logic_vector(15 downto 0);
            READY:   out std_logic
        );
    end component;
end package CRC_Engine_pkg;

