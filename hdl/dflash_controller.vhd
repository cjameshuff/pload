
-- Controller for the 25VF040 dataflash used on the Papilio One.


-- The dataflash controller has 2 states and a BUSY flag that indicates when
-- it can be accessed:
-- READING: reads one byte each time RW_NEXT is asserted. Controller starts up
-- reading from 0x000000.
-- WRITING: writes one byte each time RW_NEXT is asserted. Must write at least
-- 2 bytes, and must finish writing by reverting to READING state.
--
-- Write mode performs a AAI word program operation every 2 bytes written. The
-- total number of bytes written must be even.

-- *****************************************************************************
-- Operations:
-- *****************************************************************************
-- -----------------------------------------------------------------------------
-- DFCTL_NOP
-- Does nothing
--
-- -----------------------------------------------------------------------------
-- DFCTL_CHIP_ERASE
-- Send DF_WREN to enable writes
-- Send DF_CHIP_ERASE
-- Poll STATUS:BUSY
--
-- -----------------------------------------------------------------------------
-- DFCTL_START_READ
-- Send DF_WRDI to disable writes
-- send DF_DBSY to disable status output
-- Send DF_FAST_READ and address bytes
-- Send a dummy byte and return result each time READ asserted
--
-- -----------------------------------------------------------------------------
-- DFCTL_START_WRITE
-- Send DF_EBSY to enable status output
-- Send DF_WREN to enable writes
-- Send DF_AAI_PROG and address bytes
-- Poll MISO: 0 indicates flash is busy
--
-- -----------------------------------------------------------------------------
-- DFCTL_RW_NEXT
--



library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

library work;
    use work.DFlash_Controller_pkg.all;
    use work.SPI_Master_pkg.all;


entity DFlash_Controller is
    generic(
        CLOCK_FREQ:    integer; -- Hz
--         BAUD_RATE:     integer; -- Hz
        STARTUP_DELAY: integer  -- microseconds
    );
    port(
        RESET:   in std_logic;-- asynchronous reset
        SYS_CLK: in std_logic;
        
        CONTROL:    in  std_logic_vector(7 downto 0);
        
        ADDRESS:    in std_logic_vector(23 downto 0);
        DATA_IN:    in  std_logic_vector(7 downto 0);
        DATA_OUT:   out std_logic_vector(7 downto 0);
        BUSY:       out std_logic;
        
        MISO: in  std_logic;
        MOSI: out std_logic;
        SCK:  out std_logic;
        SS:   out std_logic
    );
end DFlash_Controller;

architecture Behavioral of DFlash_Controller is
    constant DF_READ:       std_logic_vector(7 downto 0) := X"03";
    constant DF_FAST_READ:  std_logic_vector(7 downto 0) := X"0B";
    constant DF_ERASE_4K:   std_logic_vector(7 downto 0) := X"20";
    constant DF_ERASE_32K:  std_logic_vector(7 downto 0) := X"52";
    constant DF_ERASE_64K:  std_logic_vector(7 downto 0) := X"D8";
    constant DF_CHIP_ERASE: std_logic_vector(7 downto 0) := X"60";
    constant DF_BYTE_PROG:  std_logic_vector(7 downto 0) := X"02";
    constant DF_AAI_PROG:   std_logic_vector(7 downto 0) := X"AD";
    constant DF_RDSR:       std_logic_vector(7 downto 0) := X"05";-- read status register
    constant DF_ERSR:       std_logic_vector(7 downto 0) := X"50";-- enable write status register
    constant DF_WRSR:       std_logic_vector(7 downto 0) := X"01";-- write status register
    constant DF_WREN:       std_logic_vector(7 downto 0) := X"06";-- flash write enable
    constant DF_WRDI:       std_logic_vector(7 downto 0) := X"04";-- flash write disable
    constant DF_RDID:       std_logic_vector(7 downto 0) := X"90";-- read ID
    constant DF_JEDEC_ID:   std_logic_vector(7 downto 0) := X"9F";-- read ID
    constant DF_EBSY:       std_logic_vector(7 downto 0) := X"70";-- Enable status output on MISO during AAI
    constant DF_DBSY:       std_logic_vector(7 downto 0) := X"80";-- Disable status output on MISO during AAI
    
    type df_state_t is (
        ST_STARTUP,
        
        ST_START_READ,
        ST_START_READ2,
        
        ST_START_WRITE,
        ST_START_WRITE_ERSR,
        ST_START_WRITE_WRSR,
        ST_START_WRITE_WREN,
        
        ST_AAI_PROG,
        ST_AAI_PROG2,
        
        ST_CHIP_ERASE,
        ST_CHIP_ERASE2,
        
        WAIT_BUSY,
        WAIT_BUSY_READSR,
        WAIT_BUSY_CHECKSR,
        
        ST_SEND_CMD,
        ST_FINISH_CMD_BYTE,
        
        ST_READ_BYTE,
--         ST_WRITE_BYTE,
        
        ST_IDLE
    );
    type df_mode_t is (MODE_READING, MODE_WRITING);
    
    signal DF_STATE:        df_state_t := ST_STARTUP;
    signal DF_RETURN_STATE: df_state_t := ST_STARTUP;
    signal DF_RWMODE:        df_mode_t := MODE_READING;
    
    signal SPI_RX_VALID: std_logic := '0';
    signal SPI_RX_BYTE:  std_logic_vector(7 downto 0);
    signal SPI_TX_BYTE:  std_logic_vector(7 downto 0);
    signal SPI_XMIT:     std_logic := '0';
    signal SPI_BUSY:  std_logic := '0';
    
    signal ADDRESS_REG: std_logic_vector(23 downto 0);
    signal DATA_REG:    std_logic_vector(15 downto 0);
    
    -- State used by ST_SEND_CMD
    -- First byte sent is CMD_BFR(CMD_CTR). Response bytes replace command bytes as they are sent.
    -- If CMD_LEAVE_ACTIVE = '1', the SS line is left alone when the command completes.
    type cmd_bfr_t is array (0 to 7) of std_logic_vector(7 downto 0);
    signal CMD_BFR: cmd_bfr_t := (others => (others => '0'));
    signal CMD_CTR: integer range 0 to 7;-- number of bytes - 1
    signal CMD_LEAVE_ACTIVE: std_logic := '0';
    
    signal FIRST_WRITE: std_logic := '0';-- first write after write mode entered
    signal SECOND_BYTE: std_logic := '0';-- is write of second byte
    
    signal DELAY_CTR: integer range 0 to ((CLOCK_FREQ*STARTUP_DELAY)/1000000);
    
begin
    SPI_Master_0: SPI_Master
        generic map(
            BAUD_DIV => 4,
            CPOL => '1',
            CPHA => '0'
        )
        port map(
            RESET => RESET,
            SYS_CLK => SYS_CLK,
            
            RX_VALID => SPI_RX_VALID,
            RX_BYTE  => SPI_RX_BYTE,
            TX_BYTE  => SPI_TX_BYTE,
            XMIT     => SPI_XMIT,
            BUSY     => SPI_BUSY,
            
            MISO => MISO,
            MOSI => MOSI,
            SCK  => SCK
        );
    
    MainProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            DF_STATE <= ST_STARTUP;
            SS <= '1';
            ADDRESS_REG <= X"000000";
            DELAY_CTR <= ((CLOCK_FREQ*STARTUP_DELAY)/1000000);
            CMD_LEAVE_ACTIVE <= '0';
            
        elsif(rising_edge(SYS_CLK)) then
            SPI_XMIT <= '0';
            BUSY <= '1';
            
            case DF_STATE is
                -- ================================================================
                -- Initialization
                -- ================================================================
                when ST_STARTUP =>
                    SS <= '1';
                    -- Need to wait at least 100 microseconds for dataflash to wake up
                    ADDRESS_REG <= X"000000";
                    if(DELAY_CTR = 0) then
                        DF_STATE <= ST_START_READ;
                    else
                        DELAY_CTR <= DELAY_CTR - 1;
                    end if;
                -- end state ST_STARTUP
                
                
                -- ================================================================
                -- Enter read mode
                -- ================================================================
                -- Send DF_WRDI and then DF_FAST_READ, keeping device selected for reads
                -- DF_WRDI
                when ST_START_READ =>
                    DF_RWMODE <= MODE_READING;
                    SS <= '0';
                    CMD_BFR(0) <= DF_WRDI;
                    CMD_CTR <= 0;
                    DF_RETURN_STATE <= ST_START_READ2;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_START_READ
                
                -- DF_FAST_READ
                when ST_START_READ2 =>
                    SS <= '0';
                    CMD_BFR(4) <= DF_FAST_READ;
                    CMD_BFR(3) <= ADDRESS_REG(23 downto 16);
                    CMD_BFR(2) <= ADDRESS_REG(15 downto 8);
                    CMD_BFR(1) <= ADDRESS_REG(7 downto 0);
                    CMD_BFR(0) <= X"00";
                    CMD_CTR <= 4;
                    CMD_LEAVE_ACTIVE <= '1';
                    DF_RETURN_STATE <= ST_IDLE;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_START_READ2
                
                
                
                -- ================================================================
                -- Enter write mode (actually, prepare for DF_AAI_PROG commands)
                -- ================================================================
                -- Send DF_ERSR
                -- Send DF_WRSR 0x00
                -- Send DF_WREN command
                when ST_START_WRITE =>
                    FIRST_WRITE <= '1';
                    SECOND_BYTE <= '0';
                    DF_STATE <= ST_START_WRITE_ERSR;
                -- end state ST_START_WRITE
                
                when ST_START_WRITE_ERSR =>
                    SS <= '0';
                    CMD_BFR(0) <= DF_ERSR;
                    CMD_CTR <= 0;
                    DF_RETURN_STATE <= ST_START_WRITE_WRSR;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_START_WRITE_ERSR
                
                -- Send DF_WRSR 0x00
                when ST_START_WRITE_WRSR =>
                    SS <= '0';
                    CMD_BFR(1) <= DF_WRSR;
                    CMD_BFR(0) <= X"00";
                    CMD_CTR <= 1;
                    DF_RETURN_STATE <= ST_START_WRITE_WREN;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_START_WRITE_WRSR
                
                -- Send DF_WREN
                when ST_START_WRITE_WREN =>
                    SS <= '0';
                    CMD_BFR(0) <= DF_WREN;
                    CMD_CTR <= 0;
                    DF_RETURN_STATE <= ST_IDLE;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_START_WRITE_WREN
                
                
                -- ================================================================
                -- DF_AAI_PROG
                -- Write 2 bytes, setting address on first command and waiting for
                -- busy bit to clear afterward.
                -- ================================================================
                -- send DF_AAI_PROG
                when ST_AAI_PROG =>
                    SS <= '0';
                    if(FIRST_WRITE = '1') then
                        CMD_BFR(5) <= DF_AAI_PROG;
                        CMD_BFR(4) <= ADDRESS_REG(23 downto 16);
                        CMD_BFR(3) <= ADDRESS_REG(15 downto 8);
                        CMD_BFR(2) <= ADDRESS_REG(7 downto 0);
                        CMD_BFR(1) <= DATA_REG(15 downto 8);
                        CMD_BFR(0) <= DATA_REG(7 downto 0);
                        CMD_CTR <= 5;
                        FIRST_WRITE <= '0';
                    else
                        CMD_BFR(2) <= DF_AAI_PROG;
                        CMD_BFR(1) <= DATA_REG(15 downto 8);
                        CMD_BFR(0) <= DATA_REG(7 downto 0);
                        CMD_CTR <= 2;
                    end if;
                    DF_RETURN_STATE <= ST_AAI_PROG2;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_AAI_PROG
                
                when ST_AAI_PROG2 =>
                    DF_RETURN_STATE <= ST_IDLE;
                    DF_STATE <= WAIT_BUSY;
                -- end state ST_AAI_PROG2
                
                
                
                -- ================================================================
                -- Erase chip
                -- ================================================================
                -- Send DF_CHIP_ERASE command, poll status register until busy flag clears.
                -- Requires controller to be put into write state before use
                -- Goes back to read state on completion.
                when ST_CHIP_ERASE =>
                    SS <= '0';
                    CMD_BFR(0) <= DF_CHIP_ERASE;
                    CMD_CTR <= 0;
                    DF_RETURN_STATE <= ST_CHIP_ERASE2;
                    DF_STATE <= ST_SEND_CMD;
                -- end state ST_CHIP_ERASE2
                
                when ST_CHIP_ERASE2 =>
                    ADDRESS_REG <= X"000000";
                    DF_RETURN_STATE <= ST_START_READ;
                    DF_STATE <= WAIT_BUSY;
                -- end state ST_CHIP_ERASE2
                
                
                
                -- ================================================================
                -- Utility states
                -- ================================================================
                -- Repeatedly read status register, go back to DF_RETURN_STATE when busy flag clears
                when WAIT_BUSY =>
                    SS <= '0';
                    if(SPI_BUSY = '0' and SPI_XMIT = '0') then
                        SPI_TX_BYTE <= DF_RDSR;
                        SPI_XMIT <= '1';
                        DF_STATE <= WAIT_BUSY_READSR;
                    end if;
                -- end state WAIT_BUSY
                
                when WAIT_BUSY_READSR =>
                    if(SPI_BUSY = '0' and SPI_XMIT = '0') then
                        SPI_TX_BYTE <= X"00";
                        SPI_XMIT <= '1';
                        DF_STATE <= WAIT_BUSY_CHECKSR;
                    end if;
                -- end state WAIT_BUSY_READSR
                
                when WAIT_BUSY_CHECKSR =>
                    if(SPI_BUSY = '0' and SPI_XMIT = '0') then
                        if(SPI_RX_BYTE(0) = '1') then
                            DF_STATE <= WAIT_BUSY_READSR;
                        else
                            SS <= '1';
                            DF_STATE <= DF_RETURN_STATE;
                        end if;
                    end if;
                -- end state WAIT_BUSY_CHECKSR
                
                
                -- Send/receive CMD_CTR bytes from CMD_BFR
                -- Deasserts SS line afterward
                when ST_SEND_CMD =>
                    SPI_TX_BYTE <= CMD_BFR(CMD_CTR);
                    SPI_XMIT <= '1';
                    DF_STATE <= ST_FINISH_CMD_BYTE;
                -- end state ST_SEND_CMD
                
                when ST_FINISH_CMD_BYTE =>
                    if(SPI_BUSY = '0' and SPI_XMIT = '0') then
                        CMD_BFR(CMD_CTR) <= SPI_RX_BYTE;
                        if(CMD_CTR = 0) then
                            if(CMD_LEAVE_ACTIVE = '0') then
                                SS <= '1';
                            end if;
                            DF_STATE <= DF_RETURN_STATE;
                        else
                            CMD_CTR <= CMD_CTR - 1;
                            DF_STATE <= ST_SEND_CMD;
                        end if;
                    end if;
                -- end state ST_FINISH_CMD_BYTE
                
                
                -- Wait for SPI transactions, deselect, and go to return state
--                 when ST_END_SPI =>
--                     if(SPI_BUSY = '0' and SPI_XMIT = '0') then
--                         SS <= '1';
--                         DF_STATE <= DF_RETURN_STATE;
--                     end if;
--                 -- end state ST_END_SPI
                
                
                when ST_READ_BYTE =>
                    if(SPI_BUSY = '0' and SPI_XMIT = '0') then
                        DATA_OUT <= SPI_RX_BYTE;
                        DF_STATE <= ST_IDLE;
                    end if;
                -- end state ST_READ_BYTE
                
                
                -- Wait for commands
                when ST_IDLE =>
                    if(SPI_BUSY = '0' and SPI_XMIT = '0' and CONTROL = DFCTL_NOP) then
                        BUSY <= '0';
                    end if;
                    
                    -- Need to terminate continuous read
                    if(DF_RWMODE = MODE_READING and CONTROL /= DFCTL_RW_NEXT) then
                        CMD_LEAVE_ACTIVE <= '0';
                        SS <= '1';
                    end if;
                    
                    case CONTROL is
                        when DFCTL_CHIP_ERASE =>
                            DF_STATE <= ST_CHIP_ERASE;
                        -- end DFCTL_CHIP_ERASE
                        
                        when DFCTL_START_READ =>
                            ADDRESS_REG <= ADDRESS;
                            DF_STATE <= ST_START_READ;
                        -- end DFCTL_START_READ
                        
                        when DFCTL_START_WRITE =>
                            ADDRESS_REG <= ADDRESS;
                            DF_STATE <= ST_START_WRITE;
                        -- end DFCTL_START_WRITE
                        
                        when DFCTL_RW_NEXT =>
                            if(DF_RWMODE = MODE_READING) then
                                SPI_TX_BYTE <= X"00";-- send dummy byte
                                SPI_XMIT <= '1';
                                DF_STATE <= ST_READ_BYTE;
                            else
                                if(SECOND_BYTE = '0') then
                                    -- just save byte
                                    DATA_REG(15 downto 8) <= DATA_IN;
                                    SECOND_BYTE <= '1';
                                else
                                    -- save second byte and program word
                                    DATA_REG(7 downto 0) <= DATA_IN;
                                    DF_STATE <= ST_AAI_PROG;
                                    SECOND_BYTE <= '0';
                                end if;
                            end if;
                        -- end DFCTL_RW_NEXT
                        
                        when others =>
                        -- end
                    end case; -- CONTROL
                -- end state ST_IDLE
            end case; -- DF_STATE
        end if; -- rising_edge(SYS_CLK)
    end process; -- MainProc
end Behavioral;

