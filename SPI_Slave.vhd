library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SPI_Slave is
  generic (
    SPI_MODE          : integer := 0
    );
  port (
  
   i_Rst_L : in std_logic;        
   i_Clk   : in std_logic;       
   
   -- TX MOSI Signals
   i_TX_Byte   : in std_logic_vector(7 downto 0);   
   i_TX_DV     : in std_logic;          
            
   
   -- RX MISO Signals
   o_RX_DV   : out std_logic;    
   o_RX_Byte : out std_logic_vector(7 downto 0);   

   -- SPI Interface
   i_SPI_Clk  : in std_logic;
   o_SPI_MISO : out  std_logic;
   i_SPI_MOSI : in std_logic;
   i_SPI_CS_n : in std_logic
   );
end entity SPI_Slave;

architecture RTL_Slave of SPI_Slave is

  
  signal w_CPOL : std_logic;     -- Clock polarity
  signal w_CPHA : std_logic;     -- Clock phase
  signal w_SPI_Clk : std_logic;  -- Inverted/non-inverted depending on settings
  signal w_SPI_MISO : std_logic;
  
  signal r_RX_Bit_Count : unsigned(2 downto 0);
  signal r_TX_Bit_Count : unsigned(2 downto 0);   
  signal r_Temp_RX_Byte  : std_logic_vector(7 downto 0);
  signal r_RX_Byte       : std_logic_vector(7 downto 0);
  signal r_RX_Done       : std_logic;
  signal r2_RX_Done      : std_logic;
  signal r3_RX_Done      : std_logic;
  signal r_TX_Byte       : std_logic_vector(7 downto 0);
 
  signal r_SPI_MISO_Bit  : std_logic;
  signal r_Preload_MISO  : std_logic;
  
  

begin

 
  w_CPOL <= '1' when (SPI_MODE = 2) or (SPI_MODE = 3) else '0';

  w_CPHA <= '1' when (SPI_MODE = 1) or (SPI_MODE = 3) else '0';
  
  w_SPI_Clk <=  not i_SPI_Clk  when (w_CPHA = '1') else i_SPI_Clk ;

  
  MOSI_Data : process (w_SPI_Clk , i_SPI_CS_n)
  begin
    if rising_edge(w_SPI_Clk) or rising_edge(i_SPI_CS_n) then
      if i_SPI_CS_n = '1' then
        r_RX_Bit_Count  <= "000";
        r_RX_Done       <= '0';
      else
        r_RX_Bit_Count <= r_RX_Bit_Count + 1;
        r_Temp_RX_Byte <= r_Temp_RX_Byte(6 downto 0) &  i_SPI_MOSI;
      
        if r_RX_Bit_Count = "111" then
          r_RX_Done <= '1';
          r_RX_Byte <= r_Temp_RX_Byte(6 downto 0) &  i_SPI_MOSI;  
        elsif r_RX_Bit_Count = "010"  then
          r_RX_Done <= '0';  
        end if; 
      end if;
    end if;
 end process MOSI_Data;
  
--Cross from SPI Clock Domain to main FPGA clock domain
--Assert o_RX_DV for 1 clock cycle when o_RX_Byte has valid data.
process (i_Clk, i_Rst_L)
  begin
    if rising_edge(i_Clk) or falling_edge(i_Rst_L) then
      if i_Rst_L = '0' then
        r2_RX_Done      <= '0';
        r3_RX_Done      <= '0';
        o_RX_DV         <= '0';
        o_RX_Byte       <= X"00";
      
      else 

        r2_RX_Done <= r_RX_Done;
        r3_RX_Done <= r2_RX_Done;
     
      
        if r3_RX_Done = '0' and r2_RX_Done = '1' then --rising edge
          o_RX_DV      <= '1'; --Pulse Data Valid 1 clock cycle
          o_RX_Byte   <= r_RX_Byte;  
        else 
          o_RX_DV <= '0';
        end if;
      
      end if;
    end if;
 end process;

         
  
  preload_signal : process (w_SPI_Clk, i_SPI_CS_n)
  begin
    if i_SPI_CS_n= '1' then
      r_Preload_MISO <= '1';
      
    else
      r_Preload_MISO <= '0'; 
    end if;
  end process preload_signal;


 
  MISO_Data : process (w_SPI_Clk, i_SPI_CS_n)
  begin
    if rising_edge(w_SPI_Clk) or rising_edge(i_SPI_CS_n) then
      if i_SPI_CS_n= '1' then
        r_TX_Bit_Count    <= "111"; --Send MSb first
        r_SPI_MISO_Bit    <= r_TX_Byte(7);    
      else 
       r_TX_Bit_Count    <= r_TX_Bit_Count - 1;
       r_SPI_MISO_Bit    <= r_TX_Byte(to_integer(r_TX_Bit_Count));
      end if;
    end if;
  end process MISO_Data;

--Purpose: Register TX Byte when DV pulse comes.  Keeps registed byte in 
--this module to get serialized and sent back to master.
  process (i_Clk, i_Rst_L)
  
  begin
   if rising_edge(i_Clk) or falling_edge(i_Rst_L) then
    if i_Rst_L = '0' then
      r_TX_Byte      <= X"00";
            
    else
      if i_TX_DV = '1' then 
         r_TX_Byte <= i_TX_Byte;       
      
      end if;
    end if;
   end if;
  end process;
  
   --Preload MISO with top bit of send data when preload selector is high
   --Otherwise just send the normal MISO data
  
  w_SPI_MISO <= r_TX_Byte(7) when r_Preload_MISO = '0'  else r_SPI_MISO_Bit;
  
  o_SPI_MISO <= 'Z' when i_SPI_CS_n='1' else w_SPI_MISO;
  
  w_SPI_Clk <=  not i_SPI_Clk  when (w_CPHA = '1') else i_SPI_Clk ;
  
end architecture RTL_Slave;
