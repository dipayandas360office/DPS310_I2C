library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.VComponents.all;

entity top is
    generic (
        baud                : positive := 921600;
        clock_frequency     : positive := 100_000_000
    );
    port (  
        clock                   :   in      std_logic;
        user_reset              :   in      std_logic;  
        control                 :   in      std_logic_vector(3 downto 0); 
        usb_rs232_rxd           :   in      std_logic;
        usb_rs232_txd           :   out     std_logic;
        led2_r                  :   out     std_logic;
        led3_b                  :   out     std_logic;

-------------------SPI Ports--------------------------------------------------
        SCL                    :   out     std_logic;
        SDA                     :   inout     std_logic;
        test1                    :   out     std_logic; 
        test2                    :   out     std_logic; 
        TEST3                   : OUT std_logic;
        TEST4                   : OUT std_logic;
        TEST5                   : OUT std_logic;
        
        
      -- Ethernet MII  DP83848J
        eth_ref_clk             : out std_logic;                    -- Reference Clock X1
        eth_mdc                 : out std_logic;
        eth_mdio                : inout std_logic;
        eth_rstn                : out std_logic;                    -- Reset Phy
        eth_rx_clk              : in  std_logic;                     -- Rx Clock
        eth_rx_dv               : in  std_logic;                     -- Rx Data Valid
        eth_rxd                 : in  std_logic_vector(3 downto 0);  -- RxData
        eth_rxerr               : in  std_logic;                     -- Receive Error
        eth_col                 : in  std_logic;                     -- Ethernet Collision
        eth_crs                 : in  std_logic;                     -- Ethernet Carrier Sense
        eth_tx_clk              : in  std_logic;                     -- Tx Clock
        eth_tx_en               : out std_logic;                     -- Transmit Enable
        eth_txd                 : out std_logic_vector(3 downto 0);  -- Transmit Data
        -- SPI Flash Mem
        qspi_cs                 : out std_logic;        
        qspi_dq                 : inout std_logic_vector(3 downto 0)   -- dg(0) is MOSI, dq(1) MISO       
    );
end top;



architecture rtl of top is
    
    -----Common conrol signals----------------------------------------------------------------------------
    signal command_execute_READ , command_execute_WRITE ,checkControl  : std_logic := '0';
    signal command                        : std_logic_vector (7 downto 0);
    signal command_enable                 : std_logic := '0';
    
    
    -----Rx Tx of USB--------------------------------------------------------------------------------------
    signal tx, rx, rx_sync, reset, reset_sync       : std_logic;
    signal fifo_data_in_stb_t , fifo_data_out_stb   : std_logic;
    signal  fifo_data_in_t,fifo_data_out            : std_logic_vector ( 7 downto 0);
    signal fifo_empty, fifo_full_t                  : std_logic;
    signal sendLogic                                : std_logic := '0';
   
    
    
    ---ADC signals ------------------------------------------------------------------------------------------
    signal data_ready                                 : std_logic ;

    signal start_conv                                 : std_logic:= '0';
    signal high                                       : std_logic := '1';
    signal low                                        : std_logic := '0';
    signal timerCount                                 : unsigned(23 downto 0) := "000000000000000000000000";
    signal TimeADC                                    : std_logic_vector(31 downto 0);
    signal DataTypeADC                                : std_logic_vector(7 downto 0);
    signal DeviceID_ADC                               : std_logic_vector(7 downto 0);
    signal TransmitDataADC                            : std_logic_vector(15 downto 0);
    
    
    ---Transmit control signals -----------------------------------------------------------------------------
    type  Tranmitcontrol is  (ADC_Transmit, Loopback, ADC2_transmit);
    signal DataTranmitActive, ADCreadActive           : std_logic:='0';
    signal DataTime                                   : std_logic_vector(31 downto 0);
    signal DataType                                   : std_logic_vector(7 downto 0);
    signal DeviceID                                   : std_logic_vector(7 downto 0);
    signal TransmitData                               : std_logic_vector(15 downto 0);
    signal byteCount                                  : unsigned(4 downto 0):="00000";
    signal TX_wait_ack ,ack_received                  : std_logic;
    
    ---Timer control signal     -----------------------------------------------------------------------------
    signal TimeCounter                                : unsigned(31 downto 0):= (others=>'0');
    signal TimeCounterTmp                             : std_logic_vector(31 downto 0):= (others=>'0');
    signal ReduceSpeed                                : unsigned(27 downto 0):= (others=>'0');
    signal dataCount                                  : unsigned(15 downto 0):= (others=>'0');
    signal resetTimer                                 : std_logic := '0';
    
    ---State Declaration-------------------------------------------------------------------------------------
    type adc_state is (START_READ, STOP_READ, IDLE);
    signal adc_read_state : adc_state := IDLE ;
    
 ------- Control SIgnals and states----------------------------------------------------------------------------
    signal readActive                                 : std_logic := '0';
    signal stateActive                                : unsigned(1 downto 0):="00";
    signal readState                                  : std_logic:='0';
    signal readCount, readCount_eth                   : unsigned(3 downto 0):= "0000";
    signal stateRx1, stateRx2, stateRx3, stateRx4     : std_logic := '0'; 
    signal stateRx1_eth, stateRx2_eth, stateRx3_eth   : std_logic := '0'; 
    signal readDone, readDone_eth                     : std_logic := '0';
    signal rxDataReady, rxDataReady_eth               : std_logic := '0';
    signal sendCount,countTxdata                      : unsigned(3 downto 0) := "0000";
    signal receiveCount, receiveCount_eth             : unsigned(4 downto 0):= "00000";
    signal Txdone, Txdone_eth                         : std_logic := '0';
    type reg_array_type is array (0 to 7) of std_logic_vector(7 downto 0);
    signal Rxdata, Txdata : reg_array_type := (others => (others => '0'));
    type reg_array_type_eth is array (0 to 9) of std_logic_vector(7 downto 0);
    signal Rxdata_eth, Txdata_eth : reg_array_type_eth := (others => (others => '0'));
    
 ---------------80MHz signal-----------------------------------------------------------------------------------
   signal clk_80                                      : std_logic;
   signal clk_160                                     : std_logic;
   signal locked1                                     : std_logic;
   
----------------16 MHz Signal---------------------------------------------------------------------------------
  signal Clk_16M   , clk_1M                           : std_logic := '0';
  signal count_1M                                     : integer := 0;
  signal locked2                                      : std_logic;
    
  ---------------------   Ethernet Signals --------------------------------
  signal fifo_full_t_ethernet                             : std_logic;
  signal fifo_data_in_stb_t_ethernet                      : std_logic;
  signal fifo_data_in_t_ethernet                          : std_logic_vector(7 downto 0);
  signal fifo_empty_r_ethernet                             : std_logic;
  signal fifo_data_out_stb_r_ethernet                      : std_logic;
  signal fifo_data_out_r_ethernet                          : std_logic_vector(7 downto 0);
  
  
  signal flag                                              : std_logic;
  signal bytecnt                                           : unsigned(3 downto 0) := "0000";
  
  
  ------------------ i2c --------------------------------------------------
 
  signal SCL_signal        : std_logic;
  signal SDA_signal        : std_logic;
  signal data_ready_READ , data_ready_Write , start_conv_read , start_conv_WRITE : std_logic;
  signal reg_addr_read ,  reg_addr_write , data_write : std_logic_vector(7 downto 0);

  SIGNAL SCL_signal_READ ,SCL_signal_WRITE,SDA_signal_READ, SDA_signal_WRITE : std_logic;  
  SIGNAL SDA_SIGNAL_TRISTATE , IS_Z_READ , IS_Z_WRITE , IS_Z : std_logic;
  

  signal begin_scan , begin_read , begin_write: std_logic := '0';
  signal test       : std_logic_vector(1 downto 0);
  signal data_out   : std_logic_vector(143 downto 0);
  signal scan_done , read_done ,write_done : std_logic;
  signal transmit   : std_logic;
    
-----------------16MHz clk ------------------------------------------------------------------------------------
component clk_wiz_0
port(
   clk_out1   : out std_logic;
   clk_out2   : out std_logic;
   clk_out3   : out std_logic;
   reset      : in  std_logic;
   locked     : out std_logic;
   clk_in1    : in std_logic
    );
end component;


component i2c_main is
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
end component;



       
  ------------uart_command component declaration----------------------------------------------------------------    
      
    component UartCommand is
        generic (
            baud                : positive;
            clock_frequency     : positive
        );
        port(  
        clock                   : in   std_logic;
        reset                   : in   std_logic;  
        rx                      : in   std_logic;
        tx                      : out  std_logic;
        fifo_empty              : out  std_logic;
        fifo_full_t             : out  std_logic;
        fifo_data_in_stb_t      : in   std_logic;
        fifo_data_out_stb       : in   std_logic;
        fifo_data_in_t          : in   std_logic_vector(7 downto 0);
        fifo_data_out           : out  std_logic_vector(7 downto 0)
        );
    end component UartCommand;
 
 ---------------------------Ethernet Component Declaration----------------------------
    component ethernet is 
      Port (
         clock                  : in STD_LOGIC;
         Reset                  : in std_logic;
         
         ----FIFO  pins----------------
        fifo_empty              : out   std_logic;
        fifo_full_t             : out  std_logic;
        fifo_data_in_stb_t      : in   std_logic;
        fifo_data_out_stb       : in   std_logic;
        fifo_data_in_t          : in   std_logic_vector(7 downto 0);
        fifo_data_out           : out  std_logic_vector(7 downto 0);

        -- Ethernet MII  DP83848J
        eth_ref_clk             : out std_logic;                    -- Reference Clock X1
        eth_mdc                 : out std_logic;
        eth_mdio                : inout std_logic;
        eth_rstn                : out std_logic;                    -- Reset Phy
        eth_rx_clk              : in  std_logic;                     -- Rx Clock
        eth_rx_dv               : in  std_logic;                     -- Rx Data Valid
        eth_rxd                 : in  std_logic_vector(3 downto 0);  -- RxData
        eth_rxerr               : in  std_logic;                     -- Receive Error
        eth_col                 : in  std_logic;                     -- Ethernet Collision
        eth_crs                 : in  std_logic;                     -- Ethernet Carrier Sense
        eth_tx_clk              : in  std_logic;                     -- Tx Clock
        eth_tx_en               : out std_logic;                     -- Transmit Enable
        eth_txd                 : out std_logic_vector(3 downto 0);  -- Transmit Data
        
        -- SPI Flash Mem
        qspi_cs                 : out std_logic;        
        qspi_dq                 : inout std_logic_vector(3 downto 0)   -- dg(0) is MOSI, dq(1) MISO
         );   
    end component ethernet;

begin

   
    --------------Ethernet instance -------------------
      Ethernet_Instance : ethernet 
      Port map(
         clock                  => clock,
         Reset                  => Reset,
         ----FIFO  pins----------------
        fifo_empty             => fifo_empty_r_ethernet ,
        fifo_full_t            => fifo_full_t_ethernet,
        fifo_data_in_stb_t     => fifo_data_in_stb_t_ethernet,
        fifo_data_out_stb      =>  fifo_data_out_stb_r_ethernet,   
        fifo_data_in_t         => fifo_data_in_t_ethernet,
        fifo_data_out          => fifo_data_out_r_ethernet, 
        -- Ethernet MII  DP83848J
        eth_ref_clk             => eth_ref_clk,              -- Reference Clock X1
        eth_mdc                 => eth_mdc,
        eth_mdio                => eth_mdio,
        eth_rstn                => eth_rstn,                    -- Reset Phy
        eth_rx_clk              => eth_rx_clk,                    -- Rx Clock
        eth_rx_dv               => eth_rx_dv,                     -- Rx Data Valid
        eth_rxd                 => eth_rxd,  -- RxData
        eth_rxerr               => eth_rxerr,                     -- Receive Error
        eth_col                 => eth_col,                    -- Ethernet Collision
        eth_crs                 => eth_crs,                    -- Ethernet Carrier Sense
        eth_tx_clk              => eth_tx_clk,                     -- Tx Clock
        eth_tx_en               => eth_tx_en,                     -- Transmit Enable
        eth_txd                 => eth_txd,   -- Transmit Data
        -- SPI Flash Mem
        qspi_cs                 => qspi_cs,        
        qspi_dq                 => qspi_dq   -- dg(0) is MOSI, dq(1) MISO
         );   

    ----------------------------------------------------------------------------
    --  USB Uart_Command instantiation
    ----------------------------------------------------------------------------
    UartCommandInstance : UartCommand
    generic map (
        baud                => 921600,
        clock_frequency     => clock_frequency
    )
    port map (  
        clock               => clock,
        reset               => reset,    
        rx                  => rx,
        tx                  => tx,
        fifo_empty          => fifo_empty,
        fifo_full_t         => fifo_full_t,
        fifo_data_in_stb_t  =>   fifo_data_in_stb_t,
        fifo_data_out_stb   =>  fifo_data_out_stb,
        fifo_data_in_t      =>  fifo_data_in_t ,   
        fifo_data_out       =>  fifo_data_out
       
    );
 

   
    --- 16 MHz AND 80mhz clk_out;
    ClockGen : clk_wiz_0
    port map(
    clk_out1  =>  Clk_16M,
    clk_out2  =>  clk_80,
    clk_out3  =>  clk_160,
    reset     =>  reset,
    locked    =>  locked2,
    clk_in1   =>  clock
    );
    
    
   i2c_main_inst : entity work.i2c_main
    port map (
        clk         => clock,              -- system clock
        reset       => reset,            -- active-high reset
        begin_scan  => begin_scan,       -- trigger
        begin_read  => begin_read,
        begin_write => begin_write,
        IS_Z_out    => IS_Z,         -- I2C tristate indicator
        SCL_out     => SCL_signal,          -- I2C SCL
        SDA_out     => SDA_signal,          -- I2C SDA
        SDA_in      => SDA_SIGNAL_TRISTATE,
        test        => test,             -- debug signals
        data_out    => data_out,         -- 8-bit data output
        scan_done   => scan_done,
        read_done   => read_done,         -- 1-cycle done pulse
        write_done  => write_done
    );
    
    

    

    
    -- Deglitch inputs
    ----------------------------------------------------------------------------
    deglitch : process (clock)
    begin
        if rising_edge(clock) then
            rx_sync         <= usb_rs232_rxd;
            rx              <= rx_sync;
            reset_sync      <= user_reset;
            reset           <= reset_sync;
            usb_rs232_txd   <= tx;
        end if;
    end process;
    
    
    clk_1m_process : process (clock)
    begin
        if (rising_edge(clock)) then    
            if (count_1M = 500) then
                clk_1M <= not clk_1M;
                count_1M <= 0;
            else 
                count_1M <= count_1M + 1;
            end if;
        end if;
    end process;
    


---------------------------ADC process------------------------------------------------  
    i2c:  process(clock, fifo_data_in_stb_t, fifo_data_in_stb_t_ethernet,command_execute_READ ,command_execute_WRITE )
    begin
        if rising_edge(clock) then
            if reset = '1' then
                -- Reset
                command_execute_READ    <= '0';
                command_execute_WRITE   <= '0';
                fifo_data_out_stb  <= '0';
                start_conv          <= '0';
                high               <= '1';
                low                <= '0';
                timerCount         <= (others => '0');
            else
                -- Default deassert
                fifo_data_out_stb  <= '0';
                if resetTimer = '1' then
                    resetTimer <= '0';
                end if;
                        

                    
                           
    ---------------------------Reading the Command--------------------------------------------------
                if(scan_done = '1') then
                       begin_scan <= '0';
                       begin_read <= '0';
                       begin_write <= '0';
                       transmit <= '1';
                elsif(read_done = '1') then
                       begin_scan <= '0';
                       begin_read <= '0';
                       begin_write <= '0';
                       transmit <= '1'; 
                elsif (write_done = '1') then
                       begin_scan <= '0';
                       begin_read <= '0';
                       begin_write <= '0';
                       transmit <= '1';                     
                end if; 
                            
                            
    --    ---------------------------Reading the Command--------------------------------------------------
                    fifo_data_out_stb  <= '0'; 
                    if fifo_empty = '0' and sendLogic = '0'  then
                        fifo_data_out_stb       <= '1';
                        if fifo_data_out = x"32"  then ------------ read coeff
                            begin_scan <= '1';
                            command <= fifo_data_out;
                        elsif fifo_data_out  = x"33" then -------- read data
                            begin_read <= '1';
                            command <= fifo_data_out ;
                        elsif fifo_data_out  = x"31" then -------- write
                            begin_write <= '1';
                            command <= fifo_data_out ;
                        else    
                            transmit <= '0';
                            sendLogic <= sendLogic xor '1';
                        end if;
                     elsif sendLogic = '1' then
                        sendLogic <= sendLogic xor '1';
                     end if;
            
            
 ------------------------ Transmission -----------------------------------------------------           

                if (transmit = '1') then  -------------- need to change that to (data_ready = '1') 

                      case byteCount is

                        --------------------------------------------------------------------
                        -- 0 : Send COMMAND
                        --------------------------------------------------------------------
                        when "00000" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= command;
                            byteCount                     <= byteCount + 1;
                    
                        --------------------------------------------------------------------
                        -- 1 to 18 : Send 18 bytes of data_out
                        -- Byte 1  => data_out(7 downto 0)
                        -- Byte 2  => data_out(15 downto 8)
                        -- ...
                        -- Byte 18 => data_out(143 downto 136)
                        --------------------------------------------------------------------
                    
                        when "00001" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(7 downto 0);
                            byteCount                     <= byteCount + 1;
                    
                        when "00010" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(15 downto 8);
                            byteCount                     <= byteCount + 1;
                    
                        when "00011" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(23 downto 16);
                            byteCount                     <= byteCount + 1;
                    
                        -- Continue the same pattern...
                        -- I will generate all 18 data bytes below automatically.
                    
                        when "00100" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(31 downto 24);
                            byteCount                     <= byteCount + 1;
                    
                        when "00101" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(39 downto 32);
                            byteCount                     <= byteCount + 1;
                    
                        when "00110" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(47 downto 40);
                            byteCount                     <= byteCount + 1;
                    
                        when "00111" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(55 downto 48);
                            byteCount                     <= byteCount + 1;
                    
                        when "01000" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(63 downto 56);
                            byteCount                     <= byteCount + 1;
                    
                        when "01001" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(71 downto 64);
                            byteCount                     <= byteCount + 1;
                    
                        when "01010" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(79 downto 72);
                            byteCount                     <= byteCount + 1;
                    
                        when "01011" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(87 downto 80);
                            byteCount                     <= byteCount + 1;
                    
                        when "01100" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(95 downto 88);
                            byteCount                     <= byteCount + 1;
                    
                        when "01101" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(103 downto 96);
                            byteCount                     <= byteCount + 1;
                    
                        when "01110" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(111 downto 104);
                            byteCount                     <= byteCount + 1;
                    
                        when "01111" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(119 downto 112);
                            byteCount                     <= byteCount + 1;
                    
                        when "10000" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(127 downto 120);
                            byteCount                     <= byteCount + 1;
                    
                        when "10001" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(135 downto 128);
                            byteCount                     <= byteCount + 1;
                    
                        when "10010" =>
                            fifo_data_in_stb_t            <= '1';
                            fifo_data_in_stb_t_ethernet   <= '1';
                            fifo_data_in_t                <= data_out(143 downto 136);
                            byteCount                     <= byteCount + 1;
                    
                        --------------------------------------------------------------------
                        -- DONE (after 19 bytes)
                        --------------------------------------------------------------------
                        when others =>
                            byteCount                   <= "00000";
                            fifo_data_in_stb_t          <= '0';
                            fifo_data_in_stb_t_ethernet <= '0';
                            DataTranmitActive           <= '0';
                            ADCreadActive               <= '0';
                            command_execute_WRITE       <= '0';
                            command_execute_READ        <= '0';
                            transmit                    <= '0';
                    end case;
                end if; 
             end if;
      end if;
    end process;

  
  
   SCL <= SCL_signal;
   SDA <= SDA_SIGNAL_TRISTATE;
   
--   IS_Z <= IS_Z_READ when COMMAND_EXECUTE_READ = '1' ELSE IS_Z_WRITE ;
--   SCL_SIGNAL <= SCL_signal_READ AND SCL_signal_WRITE;
--   SDA_signal <= SDA_signal_Read when COMMAND_EXECUTE_READ = '1' ELSE SDA_SIGNAL_WRITE ; 
   SDA_SIGNAL_TRISTATE <= SDA_SIGNAL WHEN (IS_Z = '0') ELSE 'Z';
   
   
--  led3_b <= newData;
  led2_r <= data_ready;
  test1 <= SCL_signal;
  test2 <= SDA_SIGNAL_TRISTATE;
  TEST3 <= scan_done;
  TEST4 <= test(0);
  TEST5 <= SDA_signal_Read;
end rtl;
