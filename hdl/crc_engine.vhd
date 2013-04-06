
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library UNISIM;
    use UNISIM.VComponents.all;

entity CRC_Engine is
    port(
        RESET:   in std_logic;-- asynchronous reset
        SYS_CLK: in std_logic;
        
        DATA:    in std_logic_vector(7 downto 0);
        WRITE:   in std_logic;
        CLEAR:   in std_logic;
        
        CRC_OUT: out std_logic_vector(15 downto 0);
        READY:   out std_logic
    );
end CRC_Engine;

architecture Behavioral of CRC_Engine is
    signal CRC: std_logic_vector(15 downto 0);
    signal BIT_CTR: unsigned(3 downto 0);
    
begin
    CRC_OUT <= CRC;
    
    MainProc: process(RESET, SYS_CLK) is
    begin
        if(RESET = '1') then
            CRC <= X"FFFF";
            BIT_CTR <= X"0";
        elsif(rising_edge(SYS_CLK)) then
            READY <= '0';
            
            if(CLEAR = '1') then
                CRC <= X"FFFF";
                BIT_CTR <= X"0";
            elsif(BIT_CTR = 0) then
                if(WRITE = '1') then
                    CRC(15 downto 8) <= CRC(15 downto 8) xor DATA;
                    BIT_CTR <= to_unsigned(8, 4);
                else
                    READY <= '1';
                end if;
            else
                BIT_CTR <= BIT_CTR - 1;
                if(CRC(15) = '1') then
                    CRC <= (CRC(14 downto 0) & '0') xor X"1021";
                else
                    CRC <= CRC(14 downto 0) & '0';
                end if;
            end if;
        end if;
    end process;
end Behavioral;

