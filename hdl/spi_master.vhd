-- BAUD_DIV must be 2 or greater, preferably even (odd values will give an asymmetrical SCK)

-- CPOL determines idle clock polarity.
-- CPHA = 0: capture on leading edge, assert on trailing edge
-- CPHA = 1: capture on trailing edge, assert on leading edge


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

entity SPI_Master is
    generic(
        BAUD_DIV: integer;
        CPOL:     std_logic;
        CPHA:     std_logic
    );
    port(
        RESET:    in std_logic;-- asynchronous reset
        SYS_CLK:  in std_logic;
        
        RX_VALID: out std_logic;
        RX_BYTE:  out std_logic_vector(7 downto 0);
        
        TX_BYTE:  in std_logic_vector(7 downto 0);
        XMIT:     in std_logic;
        BUSY:     out std_logic;
        
        MISO: in  std_logic;
        MOSI: out std_logic;
        SCK:  out std_logic
    );
end SPI_Master;

architecture Behavioral of SPI_Master is
    signal BIT_CTR:  integer range 0 to 9;
    signal BAUD_CTR: integer range 0 to BAUD_DIV - 1;
    signal RXTX_BUF: std_logic_vector(7 downto 0);
    
begin
    MainProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            SCK <= CPOL;
            MOSI <= '0';
            
        elsif(rising_edge(SYS_CLK)) then
            BUSY <= '0';
            RX_VALID <= '0';
            
            if(BIT_CTR = 0) then
                if(XMIT = '1') then
                    BUSY <= '1';
                    
                    if(CPHA = '1') then
                        -- sample on trailing edge, assert on leading edge
                        -- do first edge immediately
                        RXTX_BUF <= TX_BYTE(6 downto 0) & '0';
                        MOSI <= TX_BYTE(7);
                        SCK <= not CPOL;
                        BIT_CTR <= 8;
                        BAUD_CTR <= BAUD_DIV/2 - 1;
                    else
                        -- sample on leading edge, assert on trailing
                        -- Hold first bit stable for half a clock period before first edge
                        RXTX_BUF <= TX_BYTE(6 downto 0) & '0';
                        MOSI <= TX_BYTE(7);
                        BIT_CTR <= 8;
                        BAUD_CTR <= BAUD_DIV - 1;
                    end if;
                else
                    RX_BYTE <= RXTX_BUF;
                    RX_VALID <= '1';
                end if;
            else
                BUSY <= '1';
                BAUD_CTR <= BAUD_CTR - 1;
                
                -- leading edge
                if(BAUD_CTR = BAUD_DIV/2) then
                    if(CPHA = '1') then
                        -- assert
                        MOSI <= RXTX_BUF(7);
                        RXTX_BUF <= RXTX_BUF(6 downto 0) & '0';
                    else
                        -- capture
                        RXTX_BUF(0) <= MISO;
                    end if;
                    SCK <= not CPOL;
                end if;
                
                -- trailing edge
                if(BAUD_CTR = 0) then
                    if(CPHA = '0') then
                        -- assert
                        if(BIT_CTR /= 1) then
                            MOSI <= RXTX_BUF(7);
                            RXTX_BUF <= RXTX_BUF(6 downto 0) & '0';
                        end if;
                    else
                        -- capture
                        RXTX_BUF(0) <= MISO;
                    end if;
                    
                    SCK <= CPOL;
                    BAUD_CTR <= BAUD_DIV - 1;
                    BIT_CTR <= BIT_CTR - 1;
                end if;
            end if; -- (BIT_CTR = 0)
        end if; -- (rising_edge(SYS_CLK))
    end process; -- MainProc
end Behavioral;

