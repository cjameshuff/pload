
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity UART_RECEIVER_TB is
end UART_RECEIVER_TB;

architecture Behavioral of UART_RECEIVER_TB is
    component UART_RECEIVER
        generic (
            BAUD_DIV: integer -- BAUD = SYS_CLK/DIV/2
        );
        port(
            SYS_CLK:    in std_logic;
            RESET:      in std_logic;
            RX_IN:      in std_logic;
            
            RX_VALID:   out std_logic;
            RX_BYTE:    out std_logic_vector(7 downto 0)
        );
    end component;
    
    for UART_RECEIVER_0: UART_RECEIVER use entity work.UART_RECEIVER;
    
    signal SYS_CLK: std_logic := '1';
    signal RESET: std_logic := '1';
    signal RX_IN: std_logic;
    
    signal RX_VALID: std_logic;
    signal RX_BYTE: std_logic_vector(7 downto 0);
    
begin
    UART_RECEIVER_0: UART_RECEIVER
        generic map(
            BAUD_DIV => 32
        )
        port map(
            SYS_CLK => SYS_CLK,
            RESET => RESET,
            RX_IN => RX_IN,
            RX_VALID => RX_VALID,
            RX_BYTE => RX_BYTE
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
    
    process
        type pattern_type is record
            FLAG: std_logic;
            IN_CHAR: std_logic_vector(7 downto 0);
        end record;
        type pattern_array is array (natural range <>) of pattern_type;
        
        constant test_patterns: pattern_array := (
            ('1', x"55"),
            ('1', x"AA"),
            ('0', x"11"),
            ('0', x"22"),
            ('0', x"44"),
            ('0', x"88"),
            ('0', x"FF"),
            ('0', x"00"),
            ('0', x"DD")
        ); -- test_patterns
        
    begin
        RX_IN <= '1';
        wait for 4 ns;
        RESET <= '0';
        wait for 256 ns;
        for i in test_patterns'range loop
            RX_IN <= '0';
            wait for 64 ns;
            for j in test_patterns(i).IN_CHAR'range loop
                RX_IN <= test_patterns(i).IN_CHAR(7 - j);
                wait for 64 ns;
            end loop;
            RX_IN <= '1';
--             wait for 64 ns;
            wait for 256 ns;
        end loop;
        
        assert false report "end of test" severity note;
        wait; -- Wait forever; this will finish the simulation.
    end process;
end Behavioral;
