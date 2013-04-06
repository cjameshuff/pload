
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

package DFlash_Controller_pkg is
    component DFlash_Controller is
        generic(
            CLOCK_FREQ:    integer; -- Hz
    --         BAUD_RATE:     integer; -- Hz
            STARTUP_DELAY: integer  -- microseconds
        );
        port(
            RESET:   in std_logic;-- asynchronous reset
            SYS_CLK: in std_logic;
            
            CONTROL:    in  std_logic_vector(7 downto 0);
            
            ADDRESS:    in std_logic_vector(23 downto 0);
            DATA_IN:    in  std_logic_vector(7 downto 0);
            DATA_OUT:   out std_logic_vector(7 downto 0);
            BUSY:       out std_logic;
            
            MISO: in  std_logic;
            MOSI: out std_logic;
            SCK:  out std_logic;
            SS:   out std_logic
        );
    end component;
    
    constant DFCTL_NOP:         std_logic_vector(7 downto 0) := X"00";
    constant DFCTL_CHIP_ERASE:  std_logic_vector(7 downto 0) := X"01";
    constant DFCTL_START_READ:  std_logic_vector(7 downto 0) := X"02";
    constant DFCTL_START_WRITE: std_logic_vector(7 downto 0) := X"03";
    constant DFCTL_RW_NEXT:     std_logic_vector(7 downto 0) := X"04";
    
end package DFlash_Controller_pkg;

