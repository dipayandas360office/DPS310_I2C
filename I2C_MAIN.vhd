library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;


entity i2c_main is
  Port(
   clk         : in std_logic;
   reset       : in std_logic;
   begin_scan  : in std_logic;
   begin_read  : in std_logic;
   begin_write : in std_logic;
   IS_Z_out    : out std_logic;
   SCL_out     : out std_logic;
   SDA_out     : out std_logic;
   SDA_IN      : in std_logic;
   test        : out std_logic_vector(1 downto 0) ;
   data_out    : out std_logic_vector(143 downto 0);
   scan_done   : out std_logic;
   read_done   : out std_logic;
   write_done  : out std_logic
   );
end i2c_main;

architecture Behavioral of i2c_main is
signal SCL_signal        : std_logic;
signal SDA_signal        : std_logic;
signal data_ready_READ , data_ready_Write , start_conv_read , start_conv_WRITE : std_logic;
signal reg_addr_read ,  reg_addr_write , data_write : std_logic_vector(7 downto 0);
signal data                                         : std_logic_vector(7 downto 0);
SIGNAL SCL_signal_READ ,SCL_signal_WRITE,SDA_signal_READ, SDA_signal_WRITE : std_logic;  
SIGNAL SDA_SIGNAL_TRISTATE , IS_Z_READ , IS_Z_WRITE , IS_Z : std_logic;

signal command_execute_READ , command_execute_WRITE , clk_1M , scan_done_signal , read_done_signal , write_done_signal, sig_d , rising_scan_done_signal: std_logic;
signal count_1M , counter ,counter_scan , reg_read_integer: integer := 0;
signal device_addr  : std_logic_vector(7 downto 0);


-- NEW SIGNALS:
type coeff_array is array (0 to 17) of std_logic_vector(7 downto 0);  -- first
signal coeff_reg_array : coeff_array := (x"10",x"11",x"12",x"13",x"14",x"15",x"16",x"17",x"18",x"19",x"1A",x"1B",x"1C",x"1D",x"1E",x"1F",x"20",x"21");

type data_array is array (0 to 7) of std_logic_vector(7 downto 0);  -- first
signal data_reg_array  : data_array := (x"00", x"01", x"02", x"03", x"04", x"05", x"0d", x"0d");

type write_array is array (0 to 2) of std_logic_vector(7 downto 0);  -- first
signal write_reg_array  : write_array := (x"06", x"07", x"08");

type write_data_array is array (0 to 2) of std_logic_vector(7 downto 0);  -- first
signal write_data  : write_data_array := (x"00", x"80", x"07");

signal ptr_max : integer := 17;

type fsm_state is (
    IDLE,        -- waiting for begin_scan
    R_W,    -- assert command_execute_READ and load reg address
    DELAY,  -- wait for data_ready_READ = '1'
    TRANSMIT    -- 1-cycle delay before next read
);

signal fsm  : fsm_state; 
signal write_fsm : fsm_state;
 


component DPS310_I2C_READ_Dipayan
  Port (
    start_conv : in std_logic;
    data_rdy : out std_logic;
    data_reg : out std_logic_vector(7 downto 0);
    reg_addr_read : in  std_logic_vector(7 downto 0);
    clk_1M  : in  std_logic;
    IS_Z      : OUT std_logic;
    SDA_READ : IN std_logic;
    SCL : out std_logic;
    SDA : inout std_logic
    );
end component;

component DPS310_WRITE_SAYAN
  Port (
    start_conv : in std_logic;
--    device_addr : in std_logic_vector(7 downto 0); 
    data_rdy : out std_logic;
    data     : in  std_logic_vector(7 downto 0);
    reg_addr_write : in  std_logic_vector(7 downto 0);
    clk_1M  : in  std_logic;
    IS_Z      : OUT std_logic;
    SCL : out std_logic;
    SDA : inout std_logic
    );
end component;

begin



DPS310_READ1_instance : DPS310_I2C_READ_Dipayan
port map (
    start_conv => command_execute_READ,
    data_rdy => data_ready_READ,
    data_reg  => data,
    reg_addr_read => reg_addr_read,
    clk_1M =>  clk_1M,
    IS_Z => IS_Z_READ,
    SDA_READ => SDA_IN,
    SCL  => SCL_signal_READ,
    SDA  => SDA_signal_READ
);


DPS310_WRITE_instance : DPS310_WRITE_SAYAN
port map (
    start_conv => command_execute_WRITE,
--    device_addr =>  device_addr,
    data_rdy => data_ready_WRITE,
    data     => data_WRITE,
    reg_addr_write => reg_addr_WRITE,
    clk_1M =>  clk_1M,
    IS_Z => IS_Z_WRITE,
    SCL  => SCL_signal_WRITE,
    SDA  => SDA_signal_WRITE
);




clk_1m_process : process (clk)
begin
    if (rising_edge(clk)) then    
        if (count_1M = 500) then
            clk_1M <= not clk_1M;
            count_1M <= 0;
        else 
            count_1M <= count_1M + 1;
        end if;
    end if;
end process;





COEFF_SCAN_and_READ : process(clk, reset)
variable data_out_signal : std_logic_vector(143 downto 0);
variable ptr : integer := 0;
variable fsm_delay : integer := 0;

begin
    if rising_edge(clk) then
        if reset = '1' then
            command_execute_read <= '0';
            scan_done_signal     <= '0';
            ptr := 0;
            fsm_delay := 0;
        else
            if begin_scan = '1' or begin_read = '1' then
                case fsm is 
                   WHEN IDLE =>
                        if ptr > ptr_max then
                            fsm <= TRANSMIT;
                        else 
                            fsm <= R_W;
                        end if;
                   WHEN R_W =>
                        if data_ready_READ = '0' then 
                            if begin_scan = '1' and begin_read = '0'  then
                                reg_addr_read <= coeff_reg_array(ptr);
                            elsif begin_scan = '0' and begin_read = '1' then
                                reg_addr_read <= data_reg_array(ptr);
                            end if;
                            command_execute_read <= '1';
                        elsif data_ready_READ = '1' and command_execute_read = '1'then
                            command_execute_read <= '0';
                            data_out_signal :=  data & data_out_signal(143 downto 8) ;
                            fsm <= DELAY;
                            ptr := ptr  + 1;
                        end if;
                   WHEN DELAY =>
                       if fsm_delay < 100 then
                           fsm_delay := fsm_delay + 1;     -- keep counting
                       else
                           fsm_delay := 0;                 -- reset counter
                           fsm <= IDLE;
                       end if;
                   WHEN TRANSMIT =>
                       if begin_scan = '1' and begin_read = '0'  then
                           scan_done_signal <= '1';
                       elsif begin_scan = '0' and begin_read = '1' then
                           read_done_signal <= '1';
                       end if;
                       data_out <= data_out_signal;
                   WHEN OTHERS =>
                        fsm <= IDLE;
                end case;
                    
            elsif begin_scan = '0' and begin_read = '0' then
                fsm <= IDLE;
                scan_done_signal <= '0';
                read_done_signal <= '0';
                command_execute_read <= '0';
                fsm_delay := 0;
                data_out_signal := (others => '0');
                ptr := 0;
            end if;

        end if;
    end if;
end process;



WRITE : process(clk,reset) 
VARIABLE w_ptr , w_fsm_delay: integer:=0;
begin
if rising_edge(clk) then
    if reset = '1' then
        command_execute_write <= '0';
    elsif begin_write = '1' then
        case write_fsm is 
            when IDLE =>
                if w_ptr > 2 then
                    write_fsm <= TRANSMIT;
                else 
                    write_fsm <= R_W;
                end if;
            when R_W =>
                if data_ready_WRITE = '0' then 
                    reg_addr_write <= write_reg_array(w_ptr);
                    data_WRITE <= write_data (w_ptr);
                    command_execute_write <= '1';
                elsif data_ready_WRITE = '1' and command_execute_write = '1'then
                    command_execute_write <= '0';
                    write_fsm <= DELAY;
                    w_ptr := w_ptr  + 1;
                end if;
            when DELAY =>  
                if w_fsm_delay < 100 then
                   w_fsm_delay := w_fsm_delay + 1;     -- keep counting
                else
                   w_fsm_delay := 0;                 -- reset counter
                   write_fsm <= IDLE;
                end if;
            when TRANSMIT =>
                write_done_signal <= '1';
            when others =>
                write_fsm <= IDLE;
        end case;
    elsif begin_write = '0' then
            write_fsm <= IDLE;
            write_done_signal <= '0';
            command_execute_write <= '0';
            w_fsm_delay := 0;
            w_ptr := 0;
    end if; 
end if;
end process;


ptr_max <= 17 when begin_scan = '1' else 7;
IS_Z_out <= IS_Z_READ when COMMAND_EXECUTE_READ = '1' ELSE IS_Z_WRITE ;
SCL_SIGNAL <= SCL_signal_READ when COMMAND_EXECUTE_READ = '1' else SCL_SIGNAL_WRITE  ; 
SDA_signal <= SDA_signal_Read when COMMAND_EXECUTE_READ = '1' ELSE SDA_SIGNAL_WRITE ; 

--scan_done <= rising_scan_done_signal;
scan_done <= scan_done_signal;
read_done <= read_done_signal;
write_done <= write_done_signal;

SCL_OUT <= SCL_signal;
SDA_OUT <= SDA_SIGNAL;
test(0) <= SDA_SIGNAL_WRITE;

end Behavioral;
