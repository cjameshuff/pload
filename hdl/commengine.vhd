
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.CommEngine_pkg.all;
    use work.CRC_Engine_pkg.all;
    use work.UART_pkg.all;
    use work.DFlash_Controller_pkg.all;

entity CommEngine is
    port(
        RESET:   in std_logic;-- asynchronous reset
        SYS_CLK: in std_logic;
        
        UART_RX: in std_logic;
        UART_TX: out std_logic;
        
        DF_MISO: in  std_logic;
        DF_MOSI: out std_logic;
        DF_SCK:  out std_logic;
        DF_SS:   out std_logic
    );
end CommEngine;

-- Command format:
-- OPCODE:8 ARGS:32 CRC:16 [PAYLOAD] CRC:16
-- Flags: unused:7 HAS_PAYLOAD:1
-- No-payload packets are of fixed size: 8 bytes.
-- Packets with a payload have 2048 additional bytes and a second CRC.
-- At present, the "CRC" is a simple checksum. A real CRC will be implemented eventually.
--
-- State machine has a 2048 byte RAM buffer and several control registers.

architecture Behavioral of CommEngine is
    type comm_state_t is (
        ST_RX_CMD,
        ST_RX_ARGS,
        ST_RX_CRC,
        
        ST_TX_CMD,
        ST_TX_ARGS,
        ST_TX_CRC_H,
        ST_TX_CRC_L,
        
        ST_WRITE_BUFFER,
        ST_WRITE_BUFFER2,
        
        ST_READ_BUFFER,
        ST_READ_BUFFER2,
        
        ST_ACK_BUFFER_CRC,
        
        ST_CHECK_CRC,
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
    signal CRC_DATA:    std_logic_vector(7 downto 0);
    signal CRC_WRITE:   std_logic;
    signal CRC_CLEAR:   std_logic;
    signal CRC_READY:   std_logic;
    signal CRC_OUT:     std_logic_vector(15 downto 0);
    
    -- SPI flash controller signals
    signal DF_CONTROL:  std_logic_vector(7 downto 0);
    signal DF_ADDRESS:  std_logic_vector(23 downto 0);
    signal DF_DATA_IN:  std_logic_vector(7 downto 0);
    signal DF_DATA_OUT: std_logic_vector(7 downto 0);
    signal DF_BUSY:     std_logic;
    
    -- RAM buffer signals
    signal RAMBUF_DO:     std_logic_vector(7 downto 0);
    signal RAMBUF_DI:     std_logic_vector(7 downto 0);
    signal RAMBUF_ADDR:   std_logic_vector(10 downto 0);
    signal RAMBUF_WE:     std_logic := '0';
    
    -- Message/command state
    signal OP_CMD:        std_logic_vector(7 downto 0);
    signal OP_ARGS:       std_logic_vector(31 downto 0);
    signal RECEIVED_CRC:  std_logic_vector(15 downto 0);
    
    signal BYTE_COUNTER:  unsigned(11 downto 0);
    
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
    
    DFlash_Controller_0: DFlash_Controller
        generic map(
            CLOCK_FREQ => 64000000, -- Hz
    --         BAUD_RATE:     integer; -- Hz
            STARTUP_DELAY => 100 -- microseconds
        )
        port map(
            RESET    => RESET,
            SYS_CLK  => SYS_CLK,
            CONTROL  => DF_CONTROL,
            ADDRESS  => DF_ADDRESS,
            DATA_IN  => DF_DATA_IN,
            DATA_OUT => DF_DATA_OUT,
            BUSY     => DF_BUSY,
            MISO     => DF_MISO,
            MOSI     => DF_MOSI,
            SCK      => DF_SCK,
            SS       => DF_SS
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
    
    rxtx_buffer: RAMB16_S9
        generic map(
            INIT => "0",
            SRVAL => X"0",
            WRITE_MODE => "WRITE_FIRST"
        )
        port map(
            DO   => RAMBUF_DO,
            DOP  => open,
            ADDR => RAMBUF_ADDR,
            CLK  => SYS_CLK,
            DI   => RAMBUF_DI,
            DIP  => "1",
            EN   => '1',
            SSR  => '0',
            WE   => RAMBUF_WE
        );
    
    RAMBUF_ADDR <= std_logic_vector(BYTE_COUNTER(10 downto 0));
    
    MainProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            COMM_STATE <= ST_RX_CMD;
        elsif(rising_edge(SYS_CLK)) then
            RAMBUF_WE <= '0';
            UART_XMIT <= '0';
            CRC_CLEAR <= '0';
            CRC_WRITE <= '0';
            
            case COMM_STATE is
                -- ================================================================
                -- Entry/idle state: listen/start receiving commands
                -- ================================================================
                when ST_RX_CMD =>
                    if(UART_RX_VALID = '1' and UART_RX_BYTE /= X"00") then
                        OP_CMD <= UART_RX_BYTE;
                        CRC_DATA <= UART_RX_BYTE;
                        CRC_WRITE <= '1';
                        BYTE_COUNTER <= to_unsigned(0, 12);
                        COMM_STATE <= ST_RX_ARGS;
                    end if;
                -- end state ST_RX_CMD
                
                when ST_RX_ARGS =>
                    if(UART_RX_VALID = '1') then
                        OP_ARGS <= OP_ARGS(23 downto 0) & UART_RX_BYTE;
                        CRC_DATA <= UART_RX_BYTE;
                        CRC_WRITE <= '1';
                        BYTE_COUNTER <= BYTE_COUNTER + 1;
                        if(BYTE_COUNTER = 3) then
                            BYTE_COUNTER <= to_unsigned(0, 12);
                            COMM_STATE <= ST_RX_CRC;
                        end if;
                    end if;
                -- end state ST_RX_ARGS
                
                when ST_RX_CRC =>
                    if(UART_RX_VALID = '1') then
                        RECEIVED_CRC <= RECEIVED_CRC(7 downto 0) & UART_RX_BYTE;
                        BYTE_COUNTER <= BYTE_COUNTER + 1;
                        if(BYTE_COUNTER = 1) then
                            BYTE_COUNTER <= to_unsigned(0, 12);
                            COMM_STATE <= ST_CHECK_CRC;
                        end if;
                    end if;
                -- end state ST_RX_CRC
                
                -- CRC computation and package reception complete, check computed against received value
                when ST_CHECK_CRC =>
                    if(RECEIVED_CRC = CRC_OUT) then
                        COMM_STATE <= ST_EXECUTE;
                    else
                        COMM_STATE <= ST_ERROR;
                    end if;
                -- end state ST_CHECK_CRC
                
                
                -- ================================================================
                -- Send ACK packet with CRC
                -- returns to ST_RX_CMD via ST_TX_CMD
                -- ================================================================
                when ST_ACK_BUFFER_CRC =>
                    if(CRC_WRITE = '0' and CRC_READY = '1') then
                        OP_ARGS(31 downto 16) <= X"0000";
                        OP_ARGS(15 downto 0) <= CRC_OUT;
                        CRC_CLEAR <= '1';
                        COMM_STATE <= ST_TX_CMD;
                    end if;
                -- end state ST_ACK_BUFFER_CRC
                
                
                -- ================================================================
                -- Entry: receive buffer, ack with CRC of received data
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
                    end if;
                    
                    if(RAMBUF_WE = '1') then
                        BYTE_COUNTER <= BYTE_COUNTER + 1;
                        if(BYTE_COUNTER = unsigned(OP_ARGS(11 downto 0))) then
                            BYTE_COUNTER <= to_unsigned(0, 12);
                            COMM_STATE <= ST_ACK_BUFFER_CRC;
                        end if;
                    end if;
                -- end state ST_WRITE_BUFFER2
                
                
                -- ================================================================
                -- Entry: Transmit command/response
                -- Returns to ST_RX_CMD
                -- ================================================================
                when ST_TX_CMD =>
                    if(UART_TX_BUSY = '0') then
                        UART_TX_BYTE <= OP_CMD;
                        UART_XMIT <= '1';
                        
                        CRC_DATA <= OP_CMD;
                        CRC_WRITE <= '1';
                        
                        BYTE_COUNTER <= to_unsigned(0, 12);
                        COMM_STATE <= ST_TX_ARGS;
                    end if;
                -- end state ST_TX_CMD
                
                when ST_TX_ARGS =>
                    -- FIXME: the UART BUSY signal may need work
                    if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                        UART_TX_BYTE <= OP_ARGS(31 downto 24);
                        UART_XMIT <= '1';
                        
                        CRC_DATA <= OP_ARGS(31 downto 24);
                        CRC_WRITE <= '1';
                        
                        OP_ARGS <= OP_ARGS(23 downto 0) & X"00";
                        BYTE_COUNTER <= BYTE_COUNTER + 1;
                        
                        if(BYTE_COUNTER = 3) then
                            BYTE_COUNTER <= to_unsigned(0, 12);
                            COMM_STATE <= ST_TX_CRC_H;
                        end if;
                    end if;
                -- end state ST_TX_ARGS
                
                when ST_TX_CRC_H =>
                    if(UART_TX_BUSY = '0' and UART_XMIT = '0') then
                        UART_TX_BYTE <= CRC_OUT(15 downto 8);
                        UART_XMIT <= '1';
                        COMM_STATE <= ST_TX_CRC_L;
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
                -- Entry: Transmit buffer + CRC
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
                        
                        BYTE_COUNTER <= BYTE_COUNTER + 1;
                        if(BYTE_COUNTER = unsigned(OP_ARGS(11 downto 0))) then
                            BYTE_COUNTER <= to_unsigned(0, 12);
                            COMM_STATE <= ST_ACK_BUFFER_CRC;
                        end if;
                    end if;
                -- end state ST_READ_BUFFER2
                
                
                
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
                    case OP_CMD is
                        when OpCode_Sync =>
                            COMM_STATE <= ST_TX_CMD;
                        -- end OpCode_Sync
                        
                        when OpCode_Ack => -- send ack after buffer or sync
                            COMM_STATE <= ST_TX_CMD;
                        -- end OpCode_Ack
                        
                        
                        when OpCode_SetAddress =>
                            -- WORKING_ADDR <= OP_ARGS;
                            COMM_STATE <= ST_RX_CMD;
                        -- end OpCode_SetAddress
                        
                        
                        when OpCode_ReadBuffer =>
                            BYTE_COUNTER <= unsigned(OP_ARGS(27 downto 16));
                            COMM_STATE <= ST_READ_BUFFER;
                        -- end OpCode_WriteBuffer
                        
                        when OpCode_WriteBuffer =>
                            BYTE_COUNTER <= unsigned(OP_ARGS(27 downto 16));
                            COMM_STATE <= ST_WRITE_BUFFER;
                        -- end OpCode_WriteBuffer
                        
                        when OpCode_CRC_Buffer =>
                            BYTE_COUNTER <= unsigned(OP_ARGS(27 downto 16));
--                             COMM_STATE <= ST_WRITE_BUFFER;
                        -- end OpCode_CRC_Buffer
                        
                        
                        when OpCode_DFlash_Cmd =>
                            BYTE_COUNTER <= unsigned(OP_ARGS(27 downto 16));
--                             COMM_STATE <= ST_WRITE_BUFFER;
                        -- end OpCode_DFlash_Cmd
                        
                        when OpCode_DFlash_WriteData =>
                            BYTE_COUNTER <= unsigned(OP_ARGS(27 downto 16));
--                             COMM_STATE <= ST_WRITE_BUFFER;
                        -- end OpCode_DFlash_WriteData
                        
                        when OpCode_DFlash_ReadData =>
                            BYTE_COUNTER <= unsigned(OP_ARGS(27 downto 16));
--                             COMM_STATE <= ST_WRITE_BUFFER;
                        -- end OpCode_DFlash_ReadData
                        
                        
                        when others => -- send ack
                            COMM_STATE <= ST_ERROR;
                        -- end OpCode_Ack
                    end case; -- OP_CMD
                -- end state ST_EXECUTE
            end case; -- COMM_STATE
        end if; -- rising_edge(SYS_CLK)
    end process;
end Behavioral;

