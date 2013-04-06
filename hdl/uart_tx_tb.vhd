
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity UART_TRANSMITTER_TB is
end UART_TRANSMITTER_TB;

architecture Behavioral of UART_TRANSMITTER_TB is
    component UART_TRANSMITTER
        generic (
            BAUD_DIV: integer -- BAUD = SYS_CLK/DIV/2
        );
        port (
            SYS_CLK: in std_logic;
            RESET:   in std_logic;
            XMIT:    in std_logic;
            TX_BYTE: in std_logic_vector(7 downto 0);
            
            TX_BUSY: out std_logic;
            TX_OUT:  out std_logic
        );
    end component;
    
--     for UART_TRANSMITTER_0: UART_TRANSMITTER use entity work.UART_TRANSMITTER;
    
    signal SYS_CLK: std_logic := '1';
    signal RESET:   std_logic := '1';
    signal XMIT:    std_logic;
    signal TX_BYTE: std_logic_vector(7 downto 0);
    signal TX_BUSY: std_logic;
    signal TX_OUT:  std_logic;
    
begin
    UART_TRANSMITTER_0: UART_TRANSMITTER
        generic map(
            BAUD_DIV => 16
        )
        port map(
            SYS_CLK => SYS_CLK,
            RESET => RESET,
            XMIT => XMIT,
            TX_BYTE => TX_BYTE,
            TX_BUSY => TX_BUSY,
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
    
    process
        type pattern_type is record
            FLAG : std_logic;
            OUT_CHAR : std_logic_vector(7 downto 0);
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
        XMIT <= '0';
        RESET <= '0';
        wait for 64 ns;
        for i in test_patterns'range loop
            TX_BYTE <= test_patterns(i).OUT_CHAR;
            wait for 1 ns;
            XMIT <= '1';
            wait for 2 ns;
            XMIT <= '0';
            wait for 700 ns;
        end loop;
        
        assert false report "end of test" severity note;
        wait; -- Wait forever; this will finish the simulation.
    end process;
end Behavioral;
