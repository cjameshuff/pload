
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.CRC_Engine_pkg.all;

entity CRC_Engine_TB is
end CRC_Engine_TB;

architecture Behavioral of CRC_Engine_TB is
    signal RESET:   std_logic := '0';
    signal SYS_CLK: std_logic := '0';
    
    signal DATA:    std_logic_vector(7 downto 0);
    signal WRITE:   std_logic;
    signal CLEAR:   std_logic;
    
    signal CRC_OUT: std_logic_vector(15 downto 0);
    signal READY:   std_logic;
    
begin
    CRC_Engine_0: CRC_Engine
    port map(
        RESET   => RESET,
        SYS_CLK => SYS_CLK,
        DATA    => DATA,
        WRITE   => WRITE,
        CLEAR   => CLEAR,
        CRC_OUT => CRC_OUT,
        READY   => READY
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
            OUT_CHAR: std_logic_vector(7 downto 0);
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
        WRITE <= '0';
        CLEAR <= '0';
        DATA <= X"00";
        RESET <= '1';
        wait for 2 ns;
        RESET <= '0';
        wait for 32 ns;
        for i in test_patterns'range loop
            DATA <= test_patterns(i).OUT_CHAR;
            WRITE <= '1';
            wait for 2 ns;
            WRITE <= '0';
            wait for 20 ns;
        end loop;
        
        CLEAR <= '1';
        wait for 2 ns;
        CLEAR <= '0';
        wait for 64 ns;
        
        assert false report "end of test" severity note;
        wait;
    end process;
end Behavioral;

