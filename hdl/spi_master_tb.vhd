
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.SPI_Master_pkg.all;

entity SPI_Master_TB is
end SPI_Master_TB;

architecture Behavioral of SPI_Master_TB is
    signal RESET:   std_logic := '0';
    signal SYS_CLK: std_logic := '0';
    
    signal RX_BYTE:  std_logic_vector(7 downto 0);
    signal TX_BYTE:  std_logic_vector(7 downto 0);
    signal XMIT:     std_logic := '0';
    signal BUSY:     std_logic := '0';
    
    signal MISO: std_logic := '0';
    signal MOSI: std_logic := '0';
    signal SCK:  std_logic := '0';
    
begin
    SPI_Master_0: SPI_Master
        generic map(
            BAUD_DIV => 2,
            CPOL => '1',
            CPHA => '0'
        )
        port map(
            RESET => RESET,
            SYS_CLK => SYS_CLK,
            
            RX_BYTE => RX_BYTE,
            TX_BYTE => TX_BYTE,
            XMIT => XMIT,
            BUSY => BUSY,
            
            MISO => MISO,
            MOSI => MOSI,
            SCK  => SCK
        );
    
    process
    begin
        for i in 0 to 1000000 loop
            SYS_CLK <= '1';
            wait for 1 ns;
            SYS_CLK <= '0';
            wait for 1 ns;
        end loop;
        wait; -- Wait forever; this will finish the simulation.
    end process;
    
    
    MISO <= MOSI;
    process
        type cmd_array is array (0 to 4) of std_logic_vector(7 downto 0);
        
        type pattern_type is record
            FLAG: std_logic;
            CMD: cmd_array;
        end record;
        type pattern_array is array (natural range <>) of pattern_type;
        
        constant test_patterns: pattern_array := (
            0 => (
                '0', (x"A5", x"81", x"FF", x"55", x"AA")
            )
        ); -- test_patterns
        
    begin
        RESET <= '1';
--         MISO <= '0';
        wait for 4 ns;
        RESET <= '0';
        wait for 4 ns;
        
        for tpat_idx in test_patterns'range loop
            for byte_idx in test_patterns(tpat_idx).CMD'range loop
                TX_BYTE <= test_patterns(tpat_idx).CMD(byte_idx);
                XMIT <= '1';
                wait for 2 ns;
                XMIT <= '0';
                wait for 128 ns;
            end loop;
            wait for 256 ns;
        end loop;
        
        assert false report "end of test" severity note;
        wait; -- Wait forever; this will finish the simulation.
    end process;
end Behavioral;

