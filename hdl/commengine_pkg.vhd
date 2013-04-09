

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

package CommEngine_pkg is
    type pkt_bfr_t is array (0 to 4) of std_logic_vector(7 downto 0);
    
    component CommEngine is
        port(
            RESET:   in std_logic;-- asynchronous reset
            SYS_CLK: in std_logic;
            
            UART_RX: in  std_logic;
            UART_TX: out std_logic;
            
            -- These may be connected to a RAM or ROM to allow efficient transfer of large amounts of data
            RAMBUF_DO:   in  std_logic_vector(7 downto 0);
            RAMBUF_DI:   out std_logic_vector(7 downto 0);
            RAMBUF_ADDR: out std_logic_vector(15 downto 0);
            RAMBUF_WE:   out std_logic;
        
            STATUS:      in  std_logic_vector(31 downto 0);
            
            RX_PKT:       out pkt_bfr_t;
            PKT_RECEIVED: out std_logic;
            
            -- A NACK is signaled by setting byte 0 of TX_PKT to 0x00.
            -- Otherwise, TX_PKT is sent normally.
            TX_PKT:   in pkt_bfr_t;
            SEND_PKT: in  std_logic
        );
    end component;
    
    constant CommEngine_ProtocolVersion: std_logic_vector(31 downto 0) := X"00000001";
    
    constant CE_Status_BusyBit: integer := 0;
    
    constant OpCode_Sync:        std_logic_vector(7 downto 0) := X"01";
    constant OpCode_Ack:         std_logic_vector(7 downto 0) := X"02";
    constant OpCode_PollStatus:  std_logic_vector(7 downto 0) := X"03";
    constant OpCode_Version:     std_logic_vector(7 downto 0) := X"04";
    
    constant OpCode_ReadBuffer:  std_logic_vector(7 downto 0) := X"08";
    constant OpCode_WriteBuffer: std_logic_vector(7 downto 0) := X"09";
    constant OpCode_CRC_Buffer:  std_logic_vector(7 downto 0) := X"0A";
    
    constant OpCode_DFlash_Cmd:       std_logic_vector(7 downto 0) := X"30";
    constant OpCode_DFlash_ChipErase: std_logic_vector(7 downto 0) := X"31";
    constant OpCode_DFlash_WriteAddr: std_logic_vector(7 downto 0) := X"35";
    constant OpCode_DFlash_WriteData: std_logic_vector(7 downto 0) := X"36";
    constant OpCode_DFlash_ReadAddr:  std_logic_vector(7 downto 0) := X"38";
    constant OpCode_DFlash_ReadData:  std_logic_vector(7 downto 0) := X"39";
    
--     constant OpCode_SetAddress:  std_logic_vector(7 downto 0) := X"10";
    
    
    constant Resp_Error:         std_logic_vector(7 downto 0) := X"FF";
end package CommEngine_pkg;
