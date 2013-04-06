
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

package CommEngine_pkg is
    component CommEngine is
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
    end component;
    
    constant OpCode_Sync:        std_logic_vector(7 downto 0) := X"01";
    constant OpCode_Ack:         std_logic_vector(7 downto 0) := X"02";
--     constant OpCode_Version:     std_logic_vector(7 downto 0) := X"03";
    
--     constant OpCode_SetAddress:  std_logic_vector(7 downto 0) := X"10";
    
    constant OpCode_ReadBuffer:  std_logic_vector(7 downto 0) := X"20";
    constant OpCode_WriteBuffer: std_logic_vector(7 downto 0) := X"21";
    constant OpCode_CRC_Buffer:  std_logic_vector(7 downto 0) := X"22";
    
    constant OpCode_DFlash_Cmd:       std_logic_vector(7 downto 0) := X"30";
    constant OpCode_DFlash_WriteData: std_logic_vector(7 downto 0) := X"31";
    constant OpCode_DFlash_ReadData:  std_logic_vector(7 downto 0) := X"32";
    
    constant Resp_Error:         std_logic_vector(7 downto 0) := X"FF";
    
    -- NACK due to CRC mismatch is single byte response of Resp_Error.
    
    -- OpCode_WriteBuffer: Write to buffer.
    -- in: (OpCode_WriteBuffer START_LOC:16 LAST_LOC:16) (N bytes payload)
    -- out: (OpCode_WriteBuffer UNUSED:16 PAYLOAD_CRC:16)
    
    -- OpCode_ReadBuffer: Read from buffer.
    -- in: (OpCode_ReadBuffer START_LOC:16 LAST_LOC:16)
    -- out: (N bytes payload) (OpCode_ReadBuffer UNUSED:16 PAYLOAD_CRC:16)
end package CommEngine_pkg;
