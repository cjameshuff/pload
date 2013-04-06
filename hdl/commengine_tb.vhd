
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.CommEngine_pkg.all;

entity CommEngine_TB is
end CommEngine_TB;

architecture Behavioral of CommEngine_TB is
    signal RESET: std_logic := '0';
    signal SYS_CLK: std_logic := '0';
    signal UART_RX: std_logic := '0';
    signal UART_TX: std_logic := '0';
    
    
    signal DF_MISO:  std_logic;
    signal DF_MOSI:  std_logic;
    signal DF_SCK:   std_logic;
    signal DF_SS:    std_logic;
    
begin
    CommEngine_0: CommEngine
        port map(
            RESET => RESET,
            SYS_CLK => SYS_CLK,
            
            UART_RX => UART_RX,
            UART_TX => UART_TX,
            
            DF_MISO => DF_MISO,
            DF_MOSI => DF_MOSI,
            DF_SCK  => DF_SCK,
            DF_SS   => DF_SS
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
    
    process
--         type cmd_array is array (0 to 4) of std_logic_vector(7 downto 0);
        type cmd_array is array (0 to 8) of std_logic_vector(7 downto 0);
        
        type pattern_type is record
            FLAG: std_logic;
            CMD: cmd_array;
        end record;
        type pattern_array is array (natural range <>) of pattern_type;
        
        constant test_patterns: pattern_array := (
            0 => (
--                 '0', (x"01", x"FF", x"FF", x"FF", x"FF")
--                 '0', (x"20", x"FF", x"FF", x"FF", x"FF")
                '0', (x"21", x"22", x"22", x"22", x"22", x"01", x"02", x"03", x"04")
            )
        ); -- test_patterns
        
    begin
        UART_RX <= '1';
        wait for 4 ns;
        RESET <= '0';
        wait for 512 ns;
        
        for tpat_idx in test_patterns'range loop
            for byte_idx in test_patterns(tpat_idx).CMD'range loop
                UART_RX <= '0';
                wait for 64 ns;
                for bit_idx in test_patterns(tpat_idx).CMD(byte_idx)'range loop
                    UART_RX <= test_patterns(tpat_idx).CMD(byte_idx)(7 - bit_idx);
                    wait for 64 ns;
                end loop;
                UART_RX <= '1';
                wait for 128 ns;
            end loop;
            wait for 256 ns;
        end loop;
        
        assert false report "end of test" severity note;
        wait; -- Wait forever; this will finish the simulation.
    end process;
end Behavioral;

