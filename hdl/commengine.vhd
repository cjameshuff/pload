
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.CommEngine_pkg.all;
    use work.CRC_Engine_pkg.all;
    use work.UART_pkg.all;

entity CommEngine is
    port(
        RESET:   in std_logic;-- asynchronous reset
        SYS_CLK: in std_logic;
        
        UART_RX: in std_logic;
        UART_TX: out std_logic;
        
        RAMBUF_DO:   in std_logic_vector(7 downto 0);
        RAMBUF_DI:   out std_logic_vector(7 downto 0);
        RAMBUF_ADDR: out std_logic_vector(15 downto 0);
        RAMBUF_WE:   out std_logic;
        
        STATUS:   in std_logic_vector(31 downto 0);
        
        RX_PKT:       out pkt_bfr_t;
        PKT_RECEIVED: out std_logic;
        
        TX_PKT:   in pkt_bfr_t;
        SEND_PKT: in  std_logic
    );
end CommEngine;

architecture Behavioral of CommEngine is
    type comm_state_t is (
        ST_RX_CMD,
        ST_RX_ARGS,
        ST_RX_CRC_H,
        ST_RX_CRC_L,
        
        ST_TX_CMD,
        ST_TX_ARGS,
        ST_TX_CRC_H,
        ST_TX_CRC_L,
        
        ST_WRITE_BUFFER,
        ST_WRITE_BUFFER2,
        ST_WRITE_BUFFER3,
        
        ST_READ_BUFFER,
        ST_READ_BUFFER2,
        
        ST_CRC_BUFFER,
        ST_CRC_BUFFER2,
        
        ST_ACK_BUFFER_CRC,
        
        ST_CHECK_CRC,
        ST_WAIT_RESPONSE,
        ST_ERROR,
        ST_EXECUTE
    );
    signal COMM_STATE: comm_state_t := ST_RX_CMD;
    
    -- UART signals
    signal UART_RX_VALID: std_logic := '0';
    signal UART_RX_BYTE:  std_logic_vector(7 downto 0);
    
    signal UART_TX_BYTE:  std_logic_vector(7 downto 0);
    signal UART_XMIT:     std_logic := '0';
    signal UART_TX_BUSY:  std_logic;
    
    -- CRC engine signals
    signal CRC_DATA:   std_logic_vector(7 downto 0);
    signal CRC_WRITE:  std_logic;
    signal CRC_CLEAR:  std_logic;
    signal CRC_READY:  std_logic;
    signal CRC_OUT:    std_logic_vector(15 downto 0);
    
    -- Message/command state
    signal RECEIVED_CRC:  std_logic_vector(15 downto 0);
    
    signal PKT_BFR:  pkt_bfr_t;
    
    signal BUF_CTR:  std_logic_vector(15 downto 0);
    signal PKT_BYTE_CTR:  integer range 0 to 4;
    
begin
    UART_0: UART
        generic map(
            BAUD_DIV => 32 -- 2 Mbaud
        )
        port map(
            RESET    => RESET,
            SYS_CLK  => SYS_CLK,
            
            RX_VALID => UART_RX_VALID,
            RX_BYTE  => UART_RX_BYTE,
            
            TX_BYTE  => UART_TX_BYTE,
            XMIT     => UART_XMIT,
            TX_BUSY  => UART_TX_BUSY,
            
            RX_IN    => UART_RX,
            TX_OUT   => UART_TX
        );
    
    CRC_Engine_0: CRC_Engine
        port map(
            RESET   => RESET,
            SYS_CLK => SYS_CLK,
            DATA    => CRC_DATA,
            WRITE   => CRC_WRITE,
            CLEAR   => CRC_CLEAR,
            CRC_OUT => CRC_OUT,
            READY   => CRC_READY -- ignored in most states...byte rate is far lower than max CRC calculation rate.
        );
    
    RAMBUF_ADDR <= BUF_CTR;
    
    MainProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            COMM_STATE <= ST_RX_CMD;
            BUF_CTR <= X"0000";
            PKT_BYTE_CTR <= 0;
            
        elsif(rising_edge(SYS_CLK)) then
            RAMBUF_WE <= '0';
            UART_XMIT <= '0';
            CRC_CLEAR <= '0';
            CRC_WRITE <= '0';
            PKT_RECEIVED <= '0';
            
            case COMM_STATE is
                -- ================================================================
                -- Entry point/idle state: ST_RX_CMD
                -- Listen and start receiving commands.
                -- ================================================================
                when ST_RX_CMD =>
                    if(UART_RX_VALID = '1' and UART_RX_BYTE /= X"00") then
                        PKT_BFR(0) <= UART_RX_BYTE;
                        
                        CRC_DATA <= UART_RX_BYTE;
                        CRC_WRITE <= '1';
                        
                        PKT_BYTE_CTR <= 1;
                        COMM_STATE <= ST_RX_ARGS;
                    end if;
                -- end state ST_RX_CMD
                
                when ST_RX_ARGS =>
                    if(UART_RX_VALID = '1') then
                        PKT_BFR(PKT_BYTE_CTR) <= UART_RX_BYTE;
                        PKT_BYTE_CTR <= PKT_BYTE_CTR + 1;
                        
                        CRC_DATA <= UART_RX_BYTE;
                        CRC_WRITE <= '1';
                        
                        if(PKT_BYTE_CTR = 4) then
                            PKT_BYTE_CTR <= 0;
                            COMM_STATE <= ST_RX_CRC_H;
                        end if;
                    end if;
                -- end state ST_RX_ARGS
                
                when ST_RX_CRC_H =>
                    if(UART_RX_VALID = '1') then
                        RECEIVED_CRC(15 downto 8) <= UART_RX_BYTE;
                        COMM_STATE <= ST_RX_CRC_L;
                    end if;
                -- end state ST_RX_CRC_H
                
                when ST_RX_CRC_L =>
                    if(UART_RX_VALID = '1') then
                        RECEIVED_CRC(7 downto 0) <= UART_RX_BYTE;
                        COMM_STATE <= ST_CHECK_CRC;
                    end if;
                -- end state ST_RX_CRC_L
                
                -- CRC computation and package reception complete, check computed against received value
                when ST_CHECK_CRC =>
                    if(CRC_READY = '1') then
                        if(RECEIVED_CRC = CRC_OUT) then
                            COMM_STATE <= ST_EXECUTE;
                        else
                            COMM_STATE <= ST_ERROR;
                        end if;
                    end if;
                -- end state ST_CHECK_CRC
                
                
                -- ================================================================
                -- Send ACK packet with CRC
                -- returns to ST_RX_CMD via ST_TX_CMD
                -- ================================================================
                when ST_ACK_BUFFER_CRC =>
                    if(CRC_WRITE = '0' and CRC_READY = '1') then
                        PKT_BFR(1) <= X"00";
                        PKT_BFR(2) <= X"00";
                        PKT_BFR(3) <= CRC_OUT(15 downto 8);
                        PKT_BFR(4) <= CRC_OUT(7 downto 0);
                        CRC_CLEAR <= '1';
                        COMM_STATE <= ST_TX_CMD;
                    end if;
                -- end state ST_ACK_BUFFER_CRC
                
                
                -- ================================================================
                -- Entry point: ST_WRITE_BUFFER
                -- Receive buffer, ack with CRC of received data.
                -- Returns to ST_RX_CMD via ST_ACK_BUFFER_CRC
                -- ================================================================
                when ST_WRITE_BUFFER =>
                    COMM_STATE <= ST_WRITE_BUFFER2;
                -- end state ST_WRITE_BUFFER
                
                when ST_WRITE_BUFFER2 =>
                    if(UART_RX_VALID = '1') then
                        RAMBUF_DI <= UART_RX_BYTE;
                        RAMBUF_WE <= '1';
                        
                        CRC_DATA <= UART_RX_BYTE;
                        CRC_WRITE <= '1';
                        
                        COMM_STATE <= ST_WRITE_BUFFER3;
                    end if;
                -- end state ST_WRITE_BUFFER2
                    
                when ST_WRITE_BUFFER3 =>
                    BUF_CTR <= std_logic_vector(unsigned(BUF_CTR) + 1);
                    if(BUF_CTR = PKT_BFR(3) & PKT_BFR(4)) then
                        BUF_CTR <= X"0000";
                        COMM_STATE <= ST_ACK_BUFFER_CRC;
                    else
                        COMM_STATE <= ST_WRITE_BUFFER2;
                    end if;
                -- end state ST_WRITE_BUFFER3
                
                
                
                -- ================================================================
                -- Entry point: ST_TX_CMD
                -- Transmit command/response
                -- Returns to ST_RX_CMD
                -- ================================================================
                when ST_TX_CMD =>
                    if(UART_TX_BUSY = '0') then
                        UART_TX_BYTE <= PKT_BFR(0);
                        UART_XMIT <= '1';
                        
                        CRC_DATA <= PKT_BFR(0);
                        CRC_WRITE <= '1';
                        
                        PKT_BYTE_CTR <= 1;
                        COMM_STATE <= ST_TX_ARGS;
                    end if;
                -- end state ST_TX_CMD
                
                when ST_TX_ARGS =>
                    -- FIXME: the UART BUSY signal may need work
                    if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                        UART_TX_BYTE <= PKT_BFR(PKT_BYTE_CTR);
                        UART_XMIT <= '1';
                        
                        CRC_DATA <= PKT_BFR(PKT_BYTE_CTR);
                        CRC_WRITE <= '1';
                        
                        PKT_BYTE_CTR <= PKT_BYTE_CTR + 1;
                        if(PKT_BYTE_CTR = 4) then
                            PKT_BYTE_CTR <= 0;
                            COMM_STATE <= ST_TX_CRC_H;
                        end if;
                    end if;
                -- end state ST_TX_ARGS
                
                when ST_TX_CRC_H =>
                    if(CRC_READY = '1') then
                        if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                            UART_TX_BYTE <= CRC_OUT(15 downto 8);
                            UART_XMIT <= '1';
                            COMM_STATE <= ST_TX_CRC_L;
                        end if;
                    end if;
                -- end state ST_TX_CRC_H
                
                when ST_TX_CRC_L =>
                    if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                        UART_TX_BYTE <= CRC_OUT(7 downto 0);
                        UART_XMIT <= '1';
                        CRC_CLEAR <= '1';
                        COMM_STATE <= ST_RX_CMD;
                    end if;
                -- end state ST_TX_CRC_L
                
                
                -- ================================================================
                -- Entry point: ST_READ_BUFFER
                -- Transmit range of buffer followed by CRC ack packet.
                -- Returns to ST_RX_CMD via ST_ACK_BUFFER_CRC
                -- ================================================================
                when ST_READ_BUFFER =>
                    COMM_STATE <= ST_READ_BUFFER2;-- need a delay for SRAM
                -- end state ST_READ_BUFFER
                
                when ST_READ_BUFFER2 =>
                    if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                        UART_TX_BYTE <= RAMBUF_DO;
                        UART_XMIT <= '1';
                        
                        CRC_DATA <= RAMBUF_DO;
                        CRC_WRITE <= '1';
                        
                        BUF_CTR <= std_logic_vector(unsigned(BUF_CTR) + 1);
                        if(BUF_CTR = PKT_BFR(3) & PKT_BFR(4)) then
                            BUF_CTR <= X"0000";
                            COMM_STATE <= ST_ACK_BUFFER_CRC;
                        end if;
                    end if;
                -- end state ST_READ_BUFFER2
                
                
                -- ================================================================
                -- Entry point: ST_CRC_BUFFER
                -- Similar to ST_READ_BUFFER, but only transmit CRC of buffer range.
                -- Returns to ST_RX_CMD via ST_ACK_BUFFER_CRC
                -- ================================================================
                when ST_CRC_BUFFER =>
                    COMM_STATE <= ST_CRC_BUFFER2;-- need a delay for SRAM
                -- end state ST_READ_BUFFER
                
                when ST_CRC_BUFFER2 =>
                    if(CRC_WRITE = '0' and CRC_READY = '1') then
                        CRC_DATA <= RAMBUF_DO;
                        CRC_WRITE <= '1';
                        
                        BUF_CTR <= std_logic_vector(unsigned(BUF_CTR) + 1);
                        if(BUF_CTR = PKT_BFR(3) & PKT_BFR(4)) then
                            BUF_CTR <= X"0000";
                            COMM_STATE <= ST_ACK_BUFFER_CRC;
                        end if;
                    end if;
                -- end state ST_CRC_BUFFER2
                
                
                -- ================================================================
                -- Entry point: ST_WAIT_RESPONSE
                -- Wait for external module to compose a response packet.
                -- If 
                -- ================================================================
                when ST_WAIT_RESPONSE =>
                    if(UART_RX_VALID = '1') then
                        COMM_STATE <= ST_RX_CMD;-- State machine reset
                    elsif(SEND_PKT = '1') then
                        if(TX_PKT(0) = X"FF") then
                            -- NACK
                            COMM_STATE <= ST_ERROR;
                        else
                            -- Normal response
                            PKT_BFR <= TX_PKT;
                            COMM_STATE <= ST_TX_CMD;
                        end if;
                    end if;
                -- end state ST_WAIT_RESPONSE
                
                -- ================================================================
                -- Send NACK, go back to ST_RX_CMD
                -- ================================================================
                when ST_ERROR =>
                    if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                        UART_TX_BYTE <= Resp_Error;
                        UART_XMIT <= '1';
                        CRC_CLEAR <= '1';
                        COMM_STATE <= ST_RX_CMD;
                    end if;
                -- end state ST_ERROR
                
                
                -- ================================================================
                -- Command received and passed error check.
                -- ================================================================
                when ST_EXECUTE =>
                    CRC_CLEAR <= '1';
                    case PKT_BFR(0) is
                        when OpCode_Sync =>
                            COMM_STATE <= ST_TX_CMD;
                        -- end OpCode_Sync
                        
                        when OpCode_Ack => -- send ack after buffer or sync
                            COMM_STATE <= ST_TX_CMD;
                        -- end OpCode_Ack
                        
                        
                        when OpCode_PollStatus =>
                            PKT_BFR(1) <= STATUS(31 downto 24);
                            PKT_BFR(2) <= STATUS(23 downto 16);
                            PKT_BFR(3) <= STATUS(15 downto 8);
                            PKT_BFR(4) <= STATUS(7 downto 0);
                            COMM_STATE <= ST_TX_CMD;
                        -- end OpCode_Ack
                        
                        when OpCode_Version => -- send ack after buffer or sync
                            PKT_BFR(1) <= CommEngine_ProtocolVersion(31 downto 24);
                            PKT_BFR(2) <= CommEngine_ProtocolVersion(23 downto 16);
                            PKT_BFR(3) <= CommEngine_ProtocolVersion(15 downto 8);
                            PKT_BFR(4) <= CommEngine_ProtocolVersion(7 downto 0);
                            COMM_STATE <= ST_TX_CMD;
                        -- end OpCode_Ack
                        
                        
                        when OpCode_ReadBuffer =>
                            BUF_CTR <= PKT_BFR(1) & PKT_BFR(2);
                            COMM_STATE <= ST_READ_BUFFER;
                        -- end OpCode_WriteBuffer
                        
                        when OpCode_WriteBuffer =>
                            BUF_CTR <= PKT_BFR(1) & PKT_BFR(2);
                            COMM_STATE <= ST_WRITE_BUFFER;
                        -- end OpCode_WriteBuffer
                        
                        when OpCode_CRC_Buffer =>
                            BUF_CTR <= PKT_BFR(1) & PKT_BFR(2);
                            COMM_STATE <= ST_CRC_BUFFER;
                        -- end OpCode_CRC_Buffer
                        
                        
                        when others => -- send ack
                            RX_PKT <= PKT_BFR;
                            PKT_RECEIVED <= '1';
                            COMM_STATE <= ST_WAIT_RESPONSE;
                        -- end OpCode_Ack
                    end case; -- OP_CMD
                -- end state ST_EXECUTE
            end case; -- COMM_STATE
        end if; -- rising_edge(SYS_CLK)
    end process;
end Behavioral;

