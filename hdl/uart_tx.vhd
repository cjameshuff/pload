
-- No-frills UART transmitter
-- Mode is fixed at 8N1: 8 bit words, no parity, one stop bit.
-- Line idles high, goes low for start bit, high for 1's and low for 0's, then goes high for stop bit.
-- Takes input clock at baud rate*DIV


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity UART_TRANSMITTER is
    generic(
        BAUD_DIV: integer -- BAUD = SYS_CLK/DIV
    );
    port(
        SYS_CLK: in std_logic;
        RESET:   in std_logic;
        XMIT:    in std_logic;
        TX_BYTE: in std_logic_vector(7 downto 0);
        
        TX_BUSY: out std_logic;
        TX_OUT:  out std_logic
    );
end UART_TRANSMITTER;

architecture Behavioral of UART_TRANSMITTER is
    type XMIT_STATE is (ST_WAITING, ST_START_BIT, ST_DATA_BIT, ST_STOP_BIT);
    signal STATE: XMIT_STATE := ST_WAITING;
    signal TX_BUF: std_logic_vector(7 downto 0) := (others => '0');
    
    signal BIT_COUNT: unsigned(3 downto 0);-- 0: start bit, 1-8: data bits, 9: stop bits
    
    -- counts down to next bit
    signal BAUD_COUNT: unsigned(9 downto 0);
    
begin
    XmitProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            TX_OUT <= '1';
            STATE <= ST_WAITING;
        elsif(rising_edge(SYS_CLK)) then
            TX_BUSY <= '0';
            case STATE is
                when ST_WAITING =>
                    TX_OUT <= '1';
                    if(XMIT = '1') then
                        TX_BUSY <= '1';
                        BIT_COUNT <= X"7";
                        BAUD_COUNT <= to_unsigned(BAUD_DIV, 10);
                        TX_BUF <= TX_BYTE;
                        STATE <= ST_START_BIT;
                    end if;
                -- end state ST_WAITING
                
                when ST_START_BIT =>
                    TX_BUSY <= '1';
                    TX_OUT <= '0';
                    BAUD_COUNT <= BAUD_COUNT - 1;
                    if(BAUD_COUNT = X"1") then
                        BAUD_COUNT <= to_unsigned(BAUD_DIV, 10);
                        STATE <= ST_DATA_BIT;
                    end if;
                -- end state ST_START_BIT
                
                when ST_DATA_BIT =>
                    TX_BUSY <= '1';
                    BAUD_COUNT <= BAUD_COUNT - 1;
                    TX_OUT <= TX_BUF(0);
                    if(BAUD_COUNT = X"1") then
                        TX_BUF <= '0' & TX_BUF(7 downto 1); -- shift data
                        BAUD_COUNT <= to_unsigned(BAUD_DIV, 10);
                        BIT_COUNT <= BIT_COUNT - 1;
                        if(BIT_COUNT = 0) then
                            STATE <= ST_STOP_BIT;
                        end if;
                    end if;
                -- end state ST_DATA_BIT
                
                when ST_STOP_BIT =>
                    TX_BUSY <= '1';
                    TX_OUT <= '1';
                    BAUD_COUNT <= BAUD_COUNT - 1;
                    if(BAUD_COUNT = X"1") then
                        STATE <= ST_WAITING;
                    end if;
                -- end state ST_STOP_BIT
            end case; -- STATE
        end if; -- rising_edge(SYS_CLK)
    end process;
end Behavioral;

