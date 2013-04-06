-- Input clock is 32 MHz (Papilio)
-- DCM_SP_1 provides the following clocks:
-- 8 MHz
-- 64 MHz
-- 256 MHz

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.Vcomponents.ALL;

entity MainClk is
    port(
        CLKIN_32MHZ:       in     std_logic;
        RESET_IN:          in     std_logic;
        
        CLK_8MHZ:          out    std_logic;
        CLK_64MHZ:         out    std_logic;
        CLK_256MHZ:        out    std_logic;
        
        RESET_OUT:         out    std_logic
    );
end MainClk;

architecture Behavioral of MainClk is
    signal DCM1_CLKDV_BUF:   std_logic;-- slow clock buffer input
    signal DCM1_CLKFX_BUF:   std_logic;-- fast clock buffer input
    signal DCM1_CLK2X_BUF:   std_logic;-- 64 MHz clock buffer input
    
    signal DCM1_CLKFB_IN:    std_logic;-- 64 MHz clock buffer ouput
    
    signal DCM1_CLKIN_IBUFG: std_logic;-- clock input buffer output
    
    signal DCM1_LOCKED_OUT:  std_logic;-- clock input buffer output
    
    signal DCM1_STATUS: std_logic_vector(7 downto 0);
    
    -- Reset delay string
    signal rst_delay_0: std_logic;
    signal rst_delay_1: std_logic;
    
begin
    CLK_64MHZ <= DCM1_CLKFB_IN;
    RESET_OUT <= rst_delay_0;
    
    -- Synchronous to 64 MHz clock
    process(RESET_IN, DCM1_CLKFB_IN, DCM1_LOCKED_OUT)
    begin
        if(RESET_IN = '1' or DCM1_LOCKED_OUT = '0') then
            rst_delay_0 <= '1';
            rst_delay_1 <= '1';
        else
            if(rising_edge(DCM1_CLKFB_IN)) then
                rst_delay_0 <= rst_delay_1;
                rst_delay_1 <= '0';
            end if;
        end if;
    end process;
    
    
    -- Input buffer
    DCM1_CLKIN_IBUFG_INST: IBUFG port map(I => CLKIN_32MHZ, O => DCM1_CLKIN_IBUFG);
    
    -- Output buffers
    DCM1_CLKDV_BUFG_INST:  BUFG port map(I => DCM1_CLKDV_BUF, O => CLK_8MHZ);
    DCM1_CLKFX_BUFG_INST:  BUFG port map(I => DCM1_CLKFX_BUF, O => CLK_256MHZ);
    DCM1_CLK2X_BUFG_INST:  BUFG port map(I => DCM1_CLK2X_BUF, O => DCM1_CLKFB_IN);
    
    -- DCM instance 1: 32 MHz to 8 MHz, 64 MHz, and 256 MHz
    DCM_SP_1: DCM_SP
        generic map(
            CLK_FEEDBACK => "2X",
            CLKDV_DIVIDE => 4.0,
            CLKFX_DIVIDE => 2,
            CLKFX_MULTIPLY => 16,
            CLKIN_DIVIDE_BY_2 => FALSE,
            CLKIN_PERIOD => 31.250,
            CLKOUT_PHASE_SHIFT => "NONE",
            DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS",
            DFS_FREQUENCY_MODE => "LOW",
            DLL_FREQUENCY_MODE => "LOW",
            DUTY_CYCLE_CORRECTION => TRUE,
            FACTORY_JF => x"C080",
            PHASE_SHIFT => 0,
            STARTUP_WAIT => FALSE)
        port map(
            CLKFB => DCM1_CLKFB_IN,
            CLKIN => DCM1_CLKIN_IBUFG,
            DSSEN => '0',
            PSCLK => '0',
            PSEN => '0',
            PSINCDEC => '0',
            RST => RESET_IN,
            CLKDV => DCM1_CLKDV_BUF,
            CLKFX => DCM1_CLKFX_BUF,
            CLKFX180 => open,
            CLK0 => open,
            CLK2X => DCM1_CLK2X_BUF,
            CLK2X180 => open,
            CLK90 => open,
            CLK180 => open,
            CLK270 => open,
            LOCKED => DCM1_LOCKED_OUT,
            PSDONE => open,
            STATUS(7 downto 0) => DCM1_STATUS
        );
    
end Behavioral;


