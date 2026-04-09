library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity DPS310_WRITE_SAYAN is
  Port (
    start_conv : in  std_logic;
--    device_addr : in std_logic_vector(7 downto 0); 
    data_rdy   : out std_logic;
    data       : in std_logic_vector(7 downto 0);
    reg_addr_write : in  std_logic_vector(7 downto 0);
    clk_1M     : in  std_logic;
    IS_Z       : out std_logic;
    SCL        : out std_logic;
    SDA        : inout std_logic
  );
end DPS310_WRITE_SAYAN;
architecture Behavioral of DPS310_WRITE_SAYAN is
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
--cmd_byte <= device_addr(6 downto 0) & '0';
--cmd_byte_2 <= "00000111";
cmd_byte_2 <= reg_addr_write;
--cmd_byte_3 <= "10000000";
cmd_byte_3 <= data;
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
        scl_enable <= '0';
      elsif count = 2 then  
        SCL_signal_test <= '0';
      elsif count >= 3 and count <= 10 then
        SCL_enable <= '1';
        SCL_signal_test <= '1';
        sda <= cmd_byte(10 - count);
      elsif count = 11 then
        sda <= 'Z';
        IS_Z <= '1';
      elsif count >= 12 and count <= 19 then
        sda <= cmd_byte_2(19 - count);
        IS_Z <= '0';
      elsif count = 20 then
        sda <='Z';
        IS_Z <= '1';
      elsif count >= 21 and count <= 28 then
          IS_Z <= '0';
          sda <= cmd_byte_3(28 - count);
      elsif count = 29 then
          sda <= 'Z';
          IS_Z <= '1';
      elsif count = 30 then
        sda <='0';
      elsif count = 31 then
--        sda <='1';
--        scl_enable <= '1'
        scl_enable <= '0';
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




data_rdy <= data_ready;
--data_reg <= data24_T & data24_p;
end Behavioral;
