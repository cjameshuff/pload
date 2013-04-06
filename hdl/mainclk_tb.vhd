
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity MainClk_TB is
end MainClk_TB;

architecture Behavioral of MainClk_TB is
    component MainClk
        port (
            CLKIN_32MHZ: in     std_logic;
            RESET_IN:    in     std_logic;
            
            CLK_8MHZ:  out    std_logic;
            CLK_64MHZ: out    std_logic;
            FASTCLK:   out    std_logic;
            
            RESET_OUT: out    std_logic
        );
    end component;
    
    signal CLKIN_32MHZ:  std_logic;
    signal RESET:        std_logic;
    
    signal CLK_8MHZ:     std_logic;
    signal CLK_64MHZ:    std_logic;
    signal FASTCLK:      std_logic;
    
    signal RESET_OUT:    std_logic;
    
    for MainClk_0: MainClk use entity work.MainClk;
    
begin
    MainClk_0: MainClk port map(
        CLKIN_32MHZ => CLKIN_32MHZ,
        RESET_IN => RESET,
        CLK_8MHZ => CLK_8MHZ,
        FASTCLK => FASTCLK,
        CLK_64MHZ => CLK_64MHZ,
        RESET_OUT => RESET_OUT
    );
    
    process
    begin
        RESET <= '0';
        for i in 0 to 10240 loop
            CLKIN_32MHZ <= '0';
            wait for 15625 ps;
            CLKIN_32MHZ <= '1';
            wait for 15625 ps;
        end loop;
        wait;
    end process;
    
    process
    begin
        wait for 1000 ns;
        assert false report "end of test" severity note;
        wait;
    end process;
end Behavioral;
