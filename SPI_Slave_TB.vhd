library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SPI_Slave_TB is
end entity SPI_Slave_TB;

architecture TB_Slave of SPI_Slave_TB is

  constant SPI_MODE : integer := 1; -- CPOL = 0, CPHA = 1
  constant CLKS_PER_HALF_BIT  : integer := 2;
  constant NUM_SLAVES         :  integer := 1;
  constant SPI_CLK_DELAY : integer:= 20;   -- 2.5 MHz
  constant MAIN_CLK_DELAY : integer:= 2;  -- 25 MHz
  
  signal w_CPOL : std_logic;     -- Clock polarity
  signal w_CPHA : std_logic;     -- Clock phase
  
  
  
  signal r_Rst_L    : std_logic := '0';
 -- signal dataPayload  : std_logic_vector(7 downto 0) := X"00";
 -- signal dataLength  : std_logic_vector(7 downto 0);
  
  signal w_SPI_Clk  : std_logic;
  signal r_SPI_En     : std_logic := '0';
  signal r_Clk      : std_logic := '0';
  signal w_SPI_MOSI : std_logic;
  signal w_SPI_MISO : std_logic;
  
  -- Master Specific
  signal r_Master_TX_Byte  : std_logic_vector(7 downto 0) := X"00";
  signal r_Master_TX_DV    : std_logic := '0';
  signal r_Master_CS_n     : std_logic := '1';
  signal w_Master_TX_Ready : std_logic;
  signal r_Master_RX_DV    : std_logic := '0';
  signal r_Master_RX_Byte  : std_logic_vector(7 downto 0) := X"00";

  -- Slave Specific
  signal w_Slave_RX_DV  : std_logic; 
  signal r_Slave_TX_DV  : std_logic;
  signal w_Slave_RX_Byte  : std_logic_vector(7 downto 0);
  signal r_Slave_TX_Byte  : std_logic_vector(7 downto 0);
  
  
  -- Sends a single byte from master. 
  procedure SendSingleByte (
    data   : in  std_logic_vector(7 downto 0);
    signal o_data : out std_logic_vector(7 downto 0);
    signal o_dv   : out std_logic;
    signal CS_n   : inout std_logic) is
    
  begin
    wait until rising_edge(r_Clk);
    o_data <= data;
    o_dv   <= '1';
    CS_n    <= '0';
    wait until rising_edge(r_Clk);
    o_dv  <= '0';
    wait until (w_Master_TX_Ready='1');
    CS_n    <= '1';
  end procedure SendSingleByte;
  
 -- procedure SendMultiByte (
  --  data          : in  std_logic_vector(7 downto 0);
  --  length        : in  std_logic;
  --  ii            : in  integer;
 -- begin
  --  wait until rising_edge(r_Clk);
  --  r_Master_CS_n  <= '0';
  --  for ii in 0 to length loop
   --         wait until rising_edge(r_Clk);
    --        r_Master_TX_Byte  <= data[ii];
   --         r_Master_TX_DV   <= '1';
    --        wait until rising_edge(r_Clk);
    --        r_Master_TX_DV   <= '0';
   --         wait until (w_Master_TX_Ready='1');
   --     end loop;
    --    r_Master_CS_n='1' 
  -- end procedure SendMultiByte;


begin  -- architecture TB
  
   w_CPOL <= '1' when (SPI_MODE = 2) or (SPI_MODE = 3) else '0';
   w_CPHA <= '1' when (SPI_MODE = 1) or (SPI_MODE = 3) else '0';
   -- Clock Generators:
  r_Clk <= not r_Clk after 2 ns;

  -- Instantiate Master
  SPI_Slave_UUT : entity work.SPI_Slave
    generic map (
      SPI_MODE => SPI_MODE)
    port map (
      -- Control/Data Signals,
      i_Rst_L    => r_Rst_L,            -- FPGA Reset
      i_Clk      => r_Clk,              -- FPGA Clock
      -- RX (MOSI) Signals
      o_RX_DV    => w_Slave_RX_DV,            -- Data Valid pulse
      o_RX_Byte  => w_Slave_RX_Byte,          -- Byte received on MOSI

      -- TX (MISO) Signals
      i_TX_Byte  => w_Slave_RX_Byte,          -- Byte to serialize to MISO (set up for loopback)
      i_TX_DV    => w_Slave_RX_DV,            -- Data Valid pulse
      
      -- SPI Interface
      i_SPI_Clk  => w_SPI_Clk, 
      o_SPI_MISO => w_SPI_MISO,
      i_SPI_MOSI => w_SPI_MOSI,
      i_SPI_CS_n => r_Master_CS_n
      );
      
  SPI_Master_UUT : entity work.SPI_Master
    generic map (CLKS_PER_HALF_BIT => CLKS_PER_HALF_BIT,
    NUM_SLAVES => NUM_SLAVES,
    SPI_MODE => SPI_MODE )
    port map (
      -- Control/Data Signals,
      i_Rst_L    => r_Rst_L,            -- FPGA Reset
      i_Clk      => r_Clk,              -- FPGA Clock
      -- TX (MOSI) Signals
      i_TX_Byte  => r_Master_TX_Byte,          -- Byte to transmit
      i_TX_DV    => r_Master_TX_DV,            -- Data Valid pulse
      o_TX_Ready => w_Master_TX_Ready,         -- Transmit Ready for Byte
      -- RX (MISO) Signals
      o_RX_DV    => r_Master_RX_DV,            -- Data Valid pulse
      o_RX_Byte  => r_Master_RX_Byte,          -- Byte received on MISO
      -- SPI Interface
      o_SPI_Clk  => w_SPI_Clk, 
      i_SPI_MISO => w_SPI_MISO,
      o_SPI_MOSI => w_SPI_MOSI
      
      );

      
  Testing : process is
  begin
    wait for 100 ns;
    r_Rst_L <= '0';
    wait for 100 ns;
    r_Rst_L <= '1';
    r_Slave_TX_Byte <=X"5A";
    r_Slave_TX_DV   <= '1';
    wait for 100 ns;
    r_Slave_TX_DV   <= '0';
    -- Test single byte
    SendSingleByte(X"C1", r_Master_TX_Byte, r_Master_TX_DV,r_Master_CS_n);
    wait for 100 ns;
  --  dataPayload[0]  <= X"00";
   -- dataPayload[1]  <= X"01";
  --  dataPayload[2]  <= X"80";
    --dataPayload[3]  <= X"FF";
    --dataPayload[4]  <= X"55";
    --dataPayload[5]  <= X"AA";
    --dataLength      <= 6;
    -- Test double byte
    SendSingleByte(X"BE", r_Master_TX_Byte, r_Master_TX_DV,r_Master_CS_n);
    
    wait for 50 ns;
    assert false report "Test Complete" severity failure;
  end process Testing;

end architecture TB_Slave;