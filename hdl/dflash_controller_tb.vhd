
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.DFlash_Controller_pkg.all;

entity DFlash_Controller_TB is
end DFlash_Controller_TB;

architecture Behavioral of DFlash_Controller_TB is
    signal RESET: std_logic := '1';
    signal SYS_CLK: std_logic := '0';
    
    signal CONTROL:     std_logic_vector(7 downto 0);
    signal ADDRESS:     std_logic_vector(23 downto 0);
    signal DATA_IN:  std_logic_vector(7 downto 0);
    signal DATA_OUT:   std_logic_vector(7 downto 0);
    signal BUSY:        std_logic;
    
    signal MISO:  std_logic;
    signal MOSI:  std_logic;
    signal SCK:   std_logic;
    signal SS:    std_logic;
    
begin
    DFlash_Controller_0: DFlash_Controller
        generic map(
            CLOCK_FREQ => 64000000, -- Hz
    --         BAUD_RATE:     integer; -- Hz
            STARTUP_DELAY => 1 -- microseconds...actual requirement is 100 us, shortened for convenience in testing.
        )
        port map(
            RESET    => RESET,
            SYS_CLK  => SYS_CLK,
            CONTROL  => CONTROL,
            ADDRESS  => ADDRESS,
            DATA_IN  => DATA_IN,
            DATA_OUT => DATA_OUT,
            BUSY     => BUSY,
            MISO     => MISO,
            MOSI     => MOSI,
            SCK      => SCK,
            SS       => SS
        );
    
    process
    begin
        for i in 0 to 10240 loop
            SYS_CLK <= '1';
            wait for (0.5 us/64);
            SYS_CLK <= '0';
            wait for (0.5 us/64);
        end loop;
        wait;
    end process;
    
    
    process
        
    begin
        RESET <= '1';
        CONTROL <= DFCTL_NOP;
--         MISO <= '0';
        wait for (1 us/64)*10;
        RESET <= '0';
        wait for 4 ns;
        
--         for tpat_idx in test_patterns'range loop
--             for byte_idx in test_patterns(tpat_idx).CMD'range loop
--                 TX_BYTE <= test_patterns(tpat_idx).CMD(byte_idx);
--                 XMIT <= '1';
--                 wait for 2 ns;
--                 XMIT <= '0';
--                 wait for 128 ns;
--             end loop;
--             wait for 256 ns;
--         end loop;
        
--         assert false report "end of test" severity note;
        wait; -- Wait forever; this will finish the simulation.
    end process;
end Behavioral;

