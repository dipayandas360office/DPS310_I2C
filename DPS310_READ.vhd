library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity DPS310_I2C_READ_Dipayan is
  Port (
    start_conv : in  std_logic;
    data_rdy   : out std_logic;
    data_reg   : out std_logic_vector(7 downto 0);
    reg_addr_read : in  std_logic_vector(7 downto 0);
    clk_1M     : in  std_logic;
    SDA_READ  : IN std_logic;
    IS_Z      : OUT std_logic;
    SCL       : out std_logic;
    SDA       : inout std_logic
  );
end DPS310_I2C_READ_Dipayan;
architecture Behavioral of DPS310_I2C_READ_Dipayan is
signal data_ready   : std_logic := '0';
signal count        : integer := 0;
signal cmd_byte     : std_logic_vector(7 downto 0);
signal data24_T , data24_p       : std_logic_vector(23 downto 0) ;
signal data_count   : integer:=0;
signal scl_enable  : std_logic := '0';
signal SCL_signal  : std_logic;
signal SCL_signal_test     : std_logic := '1'; 
signal cmd_byte_2 : std_logic_vector(7 downto 0);
signal cmd_byte_3 : std_logic_vector(7 downto 0);
begin
  cmd_byte <= "11101110";
--cmd_byte_2 <= "00001101";
cmd_byte_2 <= reg_addr_read;
cmd_byte_3 <= "11101111";
--cmd_byte_4 <= std_logic_vector((unsigned(cmd_byte) + 3));
--cmd_byte_5 <= std_logic_vector((unsigned(cmd_byte) + 4));
--cmd_byte_6 <= std_logic_vector((unsigned(cmd_byte) + 5));
-----------------------------------------------------------------
-- SCLK output with dead-time control
-----------------------------------------------------------------
SCL_signal <= ((not clk_1M) ) when scl_enable = '1' else '1';
SCL <= SCL_signal and SCL_signal_test;
process(clk_1M)
begin
  if rising_edge(clk_1M) then
    if start_conv = '1' then
      
      count <= count + 1;
      
      if count = 1 then
        sda <= '0';
        IS_Z <= '0';
      elsif count = 2 then  
        SCL_signal_test <= '0';
      elsif count >= 5 and count <= 12 then
        SCL_signal_test <= '1';
        scl_enable <= '1';
        sda <= cmd_byte(12 - count);
      elsif count = 13 then
        sda <= 'Z';
         IS_Z <= '1';
      elsif count >= 14 and count <= 21 then
       IS_Z <= '0';
        sda <= cmd_byte_2(21 - count);
      elsif count = 22 then
        sda <='Z';
        IS_Z <= '1';
        
        
      elsif count = 24 then
         scl_enable <= '0';        
      elsif count = 31 then
          sda <= '0';
          IS_Z <= '0';
       elsif count = 32 then 
          SCL_signal_test <= '0';
        elsif count >= 35 and count <= 42 then
          SCL_signal_test <= '1';
          scl_enable <= '1';
          sda <= cmd_byte_3(42 - count);
        elsif count = 43 then
          sda <= '0';
--          scl_enable <= '0';
        elsif count = 44 then
            scl_enable <= '0';
        elsif count >= 45 and count <= 52 then
--          sda <= cmd_byte_3(51 - count)
          scl_enable <= '1';
          sda <= 'Z';
           IS_Z <= '1';
        elsif count = 53 then
         IS_Z <= '0';
          sda <='1';
          scl_enable <= '1';
      elsif count = 54 then
        sda <='0';
        scl_enable <= '0';
      elsif count = 55 then
--        sda <='1';
--        scl_enable <= '1';
        IS_Z <= '1';
        data_ready <= '1';
      end if;
      
  else
    scl_enable <= '0';
    data_ready  <= '0';
    count       <=  0;
    sda <= 'Z';
    IS_Z <= '1';
  end if;
 end if;
end process;


data_process: process(scl_signal)
begin
    if rising_edge(scl_signal) then
        if count <= 53 and count >=46 then
            data_reg(53 - count) <= SDA_READ;  -- maps to Pressure Reg(23..16)
        end if;
    end if;
end process;


data_rdy <= data_ready;
--data_reg <= data24_T & data24_p;
end Behavioral;
