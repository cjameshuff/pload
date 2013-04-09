
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

package DFlash_Controller_pkg is
    component DFlash_Controller is
        generic(
            CLOCK_FREQ:    real; -- Hz
    --         BAUD_RATE:     integer; -- Hz
            STARTUP_DELAY: real  -- microseconds
        );
        port(
            RESET:   in std_logic;-- asynchronous reset
            SYS_CLK: in std_logic;
            
            CONTROL:    in  std_logic_vector(3 downto 0);
            
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
    
    constant DFCTL_NOP:         std_logic_vector(3 downto 0) := X"0";
    constant DFCTL_CHIP_ERASE:  std_logic_vector(3 downto 0) := X"1";
    constant DFCTL_START_READ:  std_logic_vector(3 downto 0) := X"2";
    constant DFCTL_START_WRITE: std_logic_vector(3 downto 0) := X"4";
    constant DFCTL_RW_NEXT:     std_logic_vector(3 downto 0) := X"8";
    
end package DFlash_Controller_pkg;

