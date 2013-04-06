
-- No-frills UART receiver
-- Mode is fixed at 8N1: 8 bit words, no parity, one stop bit.
-- Line idles high, goes low for start bit, high for 1's and low for 0's, then goes high for stop bit.
-- Takes input clock at baud rate*DIV
-- Takes single sample near the center of each bit.


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity UART_RECEIVER is
    generic (
        BAUD_DIV: integer
    );
    port (
        SYS_CLK:    in std_logic;
        RESET:      in std_logic;
        RX_IN:      in std_logic;
        
        RX_VALID:   out std_logic;
        RX_BYTE:    out std_logic_vector(7 downto 0)
    );
end UART_RECEIVER;

architecture Behavioral of UART_RECEIVER is
    type RX_STATE is (ST_WAITING, ST_START_BIT, ST_DATA_BIT, ST_STOP_BIT);
    signal STATE: RX_STATE := ST_WAITING;
    
    -- counts down from 7 to 0
    signal BIT_COUNT: unsigned(3 downto 0);-- 0: start bit, 1-8: data bits, 9: stop bit
    
    -- counts down over bit period
    signal BAUD_COUNT: unsigned(9 downto 0);
    signal BIT_VOTE: unsigned(9 downto 0);
    
    signal IN_BYTE: std_logic_vector(7 downto 0) := (others => '0');
    
begin
    RecvProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            STATE <= ST_WAITING;
            RX_VALID <= '0';
        elsif(rising_edge(SYS_CLK)) then
            RX_VALID <= '0';
            
            case STATE is
                when ST_WAITING =>
                    BIT_VOTE <= to_unsigned(0, 10);
                    BIT_COUNT <= X"7";
                    if(RX_IN = '0') then
                        BIT_VOTE <= BIT_VOTE + 1;
                        if(BIT_VOTE >= 4) then
                            BAUD_COUNT <= to_unsigned(BAUD_DIV, 10);
                            STATE <= ST_START_BIT;
                        end if;
                    end if;
                -- end state ST_WAITING
                
                when ST_START_BIT =>
                    BAUD_COUNT <= BAUD_COUNT - 1;
                    if(RX_IN = '0') then
                        BIT_VOTE <= BIT_VOTE + 1;
                    end if;
                    
                    if(BAUD_COUNT = X"1") then
                        BAUD_COUNT <= to_unsigned(BAUD_DIV, 10);
                        BIT_VOTE <= to_unsigned(0, 10);
                        if(BIT_VOTE >= to_unsigned(BAUD_DIV/2, 10)) then
                            STATE <= ST_DATA_BIT;
                        else
                            STATE <= ST_WAITING;-- Bad start bit, retry
                        end if;
                    end if;
                -- end state ST_START_BIT
                
                -- Wait for bit period and sample
                when ST_DATA_BIT =>
                    BAUD_COUNT <= BAUD_COUNT - 1;
                    if(RX_IN = '1') then
                        BIT_VOTE <= BIT_VOTE + 1;
                    end if;
                    
                    if(BAUD_COUNT = X"1") then
                        BIT_COUNT <= BIT_COUNT - 1;
                        
                        if(BIT_VOTE >= to_unsigned(BAUD_DIV/2, 10)) then
                            IN_BYTE <= '1' & IN_BYTE(7 downto 1);
                        else
                            IN_BYTE <= '0' & IN_BYTE(7 downto 1);
                        end if;
                        BIT_VOTE <= to_unsigned(0, 10);
                        
                        if(BIT_COUNT = 0) then
                            BAUD_COUNT <= to_unsigned(BAUD_DIV/2, 10);-- only wait half bit period for stop bit
                            STATE <= ST_STOP_BIT;
                        else
                            BAUD_COUNT <= to_unsigned(BAUD_DIV, 10);
                        end if;
                    end if;
                -- end state ST_DATA_BIT
                
                -- Wait for half period of stop bit, to make sure we're don't mistake the last data bit for a start bit.
                when ST_STOP_BIT =>
                    BAUD_COUNT <= BAUD_COUNT - 1;
                    if(BAUD_COUNT = X"1") then
                        RX_VALID <= '1';
                        RX_BYTE <= IN_BYTE;
                        STATE <= ST_WAITING;
                    end if;
                -- end state ST_STOP_BIT
            end case; -- STATE
        end if; -- rising_edge(SYS_CLK)
    end process; -- RecvProc
end Behavioral;

