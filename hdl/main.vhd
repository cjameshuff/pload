----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:46:42 09/24/2012 
-- Design Name: 
-- Module Name:    main - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------


-- System outline:
-- 
-- Main {
--     Comm_Engine {
--         UART_Module
--         CRC_Engine
--     }
--     DFlash_Controller {
--         SPI_Master
--     }
-- }



library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.CommEngine_pkg.all;
    use work.DFlash_Controller_pkg.all;


entity Main is
    port(
        UART_RX:  in  std_logic;
        UART_TX:  out std_logic;
        
        XTAL_CLK: in  std_logic;
        
        DF_MISO: in  std_logic;
        DF_MOSI: out std_logic;
        DF_SCK:  out std_logic;
        DF_SS:   out std_logic
    );
end Main;

architecture Behavioral of Main is
    component MainClk
        port(
            CLKIN_32MHZ: in  std_logic;
            RESET_IN:    in  std_logic;
            
            CLK_8MHZ:    out std_logic;
            CLK_64MHZ:   out std_logic;
            CLK_256MHZ:  out std_logic;
            
            RESET_OUT:   out std_logic
        );
    end component;
    
    type sys_state_t is (
        ST_START_FLASH_WRITE,
        ST_FLASH_WRITE_DATA,
        
        ST_START_FLASH_READ,
        ST_FLASH_READ_DATA,
        ST_FLASH_READ_DATA2,
        
        ST_FLASH_WAIT_BUSY,
        
        ST_WAITING
    );
    signal SYS_STATE: sys_state_t := ST_WAITING;
    
    signal SYS_CLK: std_logic;
    
    signal RESET:   std_logic;
    
    -- Comm engine signals
    signal RX_PKT:        pkt_bfr_t;
    signal PKT_RECEIVED:  std_logic;
        
    signal TX_PKT:    pkt_bfr_t;
    signal SEND_PKT:  std_logic;
        
    signal CE_STATUS: std_logic_vector(31 downto 0);
    
    
    -- RAM buffer signals
    -- CommEngine side
    signal CE_RAMBUF_DO:     std_logic_vector(7 downto 0);
    signal CE_RAMBUF_DI:     std_logic_vector(7 downto 0);
    signal CE_RAMBUF_ADDR:   std_logic_vector(15 downto 0);
    signal CE_RAMBUF_WE:     std_logic := '0';
    
    -- System side
    signal SYS_RAMBUF_DO:     std_logic_vector(7 downto 0);
    signal SYS_RAMBUF_DI:     std_logic_vector(7 downto 0);
    signal SYS_RAMBUF_ADDR:   std_logic_vector(15 downto 0);
    signal SYS_RAMBUF_WE:     std_logic := '0';
    
    signal LAST_BYTE_ADDR:  std_logic_vector(15 downto 0);
    
    -- SPI flash controller signals
    signal DF_CONTROL:  std_logic_vector(3 downto 0);
    signal DF_ADDRESS:  std_logic_vector(23 downto 0);
    signal DF_DATA_IN:  std_logic_vector(7 downto 0);
    signal DF_DATA_OUT: std_logic_vector(7 downto 0);
    signal DF_BUSY:     std_logic;
    
    
begin
    MainClk_0: MainClk
        port map(
            CLKIN_32MHZ    => XTAL_CLK,
            RESET_IN       => '0',
            CLK_8MHZ       => open,
            CLK_256MHZ     => open,
            CLK_64MHZ      => SYS_CLK,
            RESET_OUT      => RESET
        );
    
    DFlash_Controller_0: DFlash_Controller
        generic map(
            CLOCK_FREQ => 64000000.0, -- Hz
    --         BAUD_RATE:     integer; -- Hz
            STARTUP_DELAY => 100.0 -- microseconds
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
    
    
    rxtx_buffer: RAMB16_S9_S9
        generic map(
            INIT_A => "0",
            SRVAL_A => X"0",
            WRITE_MODE_A => "WRITE_FIRST",
            INIT_B => "0",
            SRVAL_B => X"0",
            WRITE_MODE_B => "WRITE_FIRST"
        )
        port map(
            DOA   => CE_RAMBUF_DO,
            DOPA  => open,
            ADDRA => CE_RAMBUF_ADDR(10 downto 0),
            CLKA  => SYS_CLK,
            DIA   => CE_RAMBUF_DI,
            DIPA  => "1",
            ENA   => '1',
            SSRA  => '0',
            WEA   => CE_RAMBUF_WE,
            
            DOB   => SYS_RAMBUF_DO,
            DOPB  => open,
            ADDRB => SYS_RAMBUF_ADDR(10 downto 0),
            CLKB  => SYS_CLK,
            DIB   => SYS_RAMBUF_DI,
            DIPB  => "1",
            ENB   => '1',
            SSRB  => '0',
            WEB   => SYS_RAMBUF_WE
        );
    
    CommEngine_0: CommEngine
        port map(
            RESET   => RESET,
            SYS_CLK => SYS_CLK,
            
            UART_RX  => UART_RX,
            UART_TX  => UART_TX,
            
            RAMBUF_DO    => CE_RAMBUF_DO,
            RAMBUF_DI    => CE_RAMBUF_DI,
            RAMBUF_ADDR  => CE_RAMBUF_ADDR,
            RAMBUF_WE    => CE_RAMBUF_WE,
        
            STATUS => CE_STATUS,
            
            RX_PKT       => RX_PKT,
            PKT_RECEIVED => PKT_RECEIVED,
            
            TX_PKT       => TX_PKT,
            SEND_PKT     => SEND_PKT
        );
    
    -- Status report format:
    -- CURR_CMD:8 UNUSED1:8 UNUSED2:8 UNUSED3:7 BUSY:1
    
    MainProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            SYS_STATE <= ST_WAITING;
            
            CE_STATUS <= X"00_00_00_01";
            
        elsif(rising_edge(SYS_CLK)) then
            SEND_PKT <= '0';
            SYS_RAMBUF_WE <= '0';
            DF_CONTROL <= DFCTL_NOP;
            
            -- Busy if not waiting
            CE_STATUS(CE_Status_BusyBit) <= '1';
            
            case SYS_STATE is
                -- ================================================================
                -- Entry point: ST_START_FLASH_WRITE
                -- Write data from buffer to flash
                -- ================================================================
                when ST_START_FLASH_WRITE =>
                    SYS_STATE <= ST_FLASH_WRITE_DATA;
                -- end state ST_START_FLASH_WRITE
                
                when ST_FLASH_WRITE_DATA =>
                    if(DF_BUSY = '0' and DF_CONTROL = DFCTL_NOP) then
                        DF_CONTROL <= DFCTL_RW_NEXT;
                        DF_DATA_IN <= SYS_RAMBUF_DO;
                        SYS_RAMBUF_ADDR <= std_logic_vector(unsigned(SYS_RAMBUF_ADDR) + 1);
                        if(SYS_RAMBUF_ADDR = LAST_BYTE_ADDR) then
                            SYS_STATE <= ST_FLASH_WAIT_BUSY;
                        end if;
                    end if;
                -- end state ST_FLASH_WRITE_DATA
                
                
                -- ================================================================
                -- Entry point: ST_START_FLASH_READ
                -- ================================================================
                when ST_START_FLASH_READ =>
                    DF_CONTROL <= DFCTL_RW_NEXT;-- start read of first byte
                    SYS_STATE <= ST_FLASH_READ_DATA;
                -- end state ST_START_FLASH_READ
                
                when ST_FLASH_READ_DATA =>
                    if(DF_BUSY = '0' and DF_CONTROL = DFCTL_NOP) then
                        SYS_RAMBUF_DI <= DF_DATA_OUT;
                        SYS_RAMBUF_WE <= '1';
                        
                        if(SYS_RAMBUF_ADDR = LAST_BYTE_ADDR) then
                            SYS_STATE <= ST_WAITING;
                        else
                            SYS_STATE <= ST_FLASH_READ_DATA2;
                        end if;
                    end if;
                -- end state ST_FLASH_READ_DATA
                
                when ST_FLASH_READ_DATA2 => -- start read of new byte, increment counter
                    SYS_RAMBUF_ADDR <= std_logic_vector(unsigned(SYS_RAMBUF_ADDR) + 1);
                    DF_CONTROL <= DFCTL_RW_NEXT;
                    SYS_STATE <= ST_FLASH_READ_DATA;
                -- end state ST_FLASH_READ_DATA2
                
                
                
                -- Wait for operation to complete and go back to waiting state
                when ST_FLASH_WAIT_BUSY =>
                    if(DF_BUSY = '0' and DF_CONTROL = DFCTL_NOP) then
                        SYS_STATE <= ST_WAITING;
                    end if;
                -- end state ST_FLASH_READ_DATA
                
                
                -- ================================================================
                -- Wait for commands
                -- ================================================================
                when ST_WAITING =>
                    if(PKT_RECEIVED = '1') then
                        CE_STATUS(31 downto 24) <= RX_PKT(0);-- high byte of status is last command executed
                        
                        TX_PKT <= RX_PKT;-- default response is simple ack
                        SEND_PKT <= '1';-- immediate response for all commands
                        
                        case RX_PKT(0) is
--                             when OpCode_DFlash_Cmd =>
        --                         BYTE_CTR <= unsigned(PKT_BFR(1) & PKT_BFR(2));
--                             -- end OpCode_DFlash_Cmd
                            
                            when OpCode_DFlash_ChipErase =>
                                DF_CONTROL <= DFCTL_CHIP_ERASE;
                                SYS_STATE <= ST_FLASH_WAIT_BUSY;
                            -- end OpCode_DFlash_ChipErase
                            
                            
                            when OpCode_DFlash_WriteAddr =>
                                DF_CONTROL <= DFCTL_START_WRITE;
                                DF_ADDRESS <= RX_PKT(2) & RX_PKT(3) & RX_PKT(4);
                                SYS_STATE <= ST_FLASH_WAIT_BUSY;
                            -- end OpCode_DFlash_WriteAddr
                            
                            when OpCode_DFlash_WriteData =>
                                SYS_RAMBUF_ADDR <= RX_PKT(1) & RX_PKT(2);
                                LAST_BYTE_ADDR <= RX_PKT(3) & RX_PKT(4);
                                SYS_STATE <= ST_START_FLASH_WRITE;
                            -- end OpCode_DFlash_WriteData
                            
                            
                            when OpCode_DFlash_ReadAddr =>
                                DF_CONTROL <= DFCTL_START_READ;
                                DF_ADDRESS <= RX_PKT(2) & RX_PKT(3) & RX_PKT(4);
                                SYS_STATE <= ST_FLASH_WAIT_BUSY;
                            -- end OpCode_DFlash_ReadAddr
                            
                            when OpCode_DFlash_ReadData =>
                                SYS_RAMBUF_ADDR <= RX_PKT(1) & RX_PKT(2);
                                LAST_BYTE_ADDR <= RX_PKT(3) & RX_PKT(4);
                                SYS_STATE <= ST_START_FLASH_READ;
                            -- end OpCode_DFlash_ReadData
                            
                            
                            when others => -- send NACK
                                TX_PKT(0) <= X"FF";
                            -- end OpCode_Ack
                        end case; -- OP_CMD
                    else
--                         CE_STATUS(31 downto 24) <= X"00";-- high byte of status is 0 if no command is being executed
                        CE_STATUS(CE_Status_BusyBit) <= '0';-- Waiting for commands? Not busy.
                    end if; -- PKT_RECEIVED = '1'
                -- end state ST_WAITING
            end case; -- SYS_STATE
        end if; -- rising_edge(SYS_CLK)
    end process;
    
    
end Behavioral;

