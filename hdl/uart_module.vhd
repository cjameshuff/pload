
-- No-frills UART transceiver
-- Mode is fixed at 8N1: 8 bit words, no parity, one stop bit.
-- Line idles high, goes low for start bit, high for 1's and low for 0's, then goes high for stop bit.
-- BAUD = SYS_CLK/DIV
-- DIV = SYS_CLK/BAUD
--
-- For 64 MHz clock:
-- DIV = 128: 500 kbaud (exact)
-- DIV = 64: 1 Mbaud (exact)
-- DIV = 32: 2 Mbaud (exact)
-- DIV = 22: 3 Mbaud (-3% error, actual 2909090.9 baud)

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity UART is
    generic(
        BAUD_DIV: integer
    );
    port (
        SYS_CLK:  in std_logic;
        RESET:    in std_logic;
        
        RX_VALID: out std_logic;
        RX_BYTE:  out std_logic_vector(7 downto 0);
        
        TX_BYTE:  in std_logic_vector(7 downto 0);
        XMIT:     in std_logic;
        TX_BUSY:  out std_logic;
        
        RX_IN:    in std_logic;
        TX_OUT:   out std_logic
    );
end UART;

architecture Behavioral of UART is
    component UART_TRANSMITTER
        generic(
            BAUD_DIV: integer
        );
        port(
            SYS_CLK: in std_logic;
            RESET:   in std_logic;
            XMIT:    in std_logic;
            TX_BYTE: in std_logic_vector(7 downto 0);
            
            TX_BUSY: out std_logic;
            TX_OUT:  out std_logic
        );
    end component;
    
    component UART_RECEIVER
        generic (
            BAUD_DIV: integer
        );
        port(
            SYS_CLK:  in std_logic;
            RESET:    in std_logic;
            RX_IN:    in std_logic;
            
            RX_VALID: out std_logic;
            RX_BYTE:  out std_logic_vector(7 downto 0)
        );
    end component;
    
begin
    UART_TRANSMITTER_0: UART_TRANSMITTER
        generic map(
            BAUD_DIV => BAUD_DIV
        )
        port map(
            SYS_CLK  => SYS_CLK,
            RESET    => RESET,
            XMIT     => XMIT,
            TX_BYTE  => TX_BYTE,
            TX_BUSY  => TX_BUSY,
            TX_OUT   => TX_OUT
        );
    
    UART_RECEIVER_0: UART_RECEIVER
        generic map(
            BAUD_DIV => BAUD_DIV
        )
        port map(
            SYS_CLK  => SYS_CLK,
            RESET    => RESET,
            RX_IN    => RX_IN,
            RX_VALID => RX_VALID,
            RX_BYTE  => RX_BYTE
        );
end Behavioral;
