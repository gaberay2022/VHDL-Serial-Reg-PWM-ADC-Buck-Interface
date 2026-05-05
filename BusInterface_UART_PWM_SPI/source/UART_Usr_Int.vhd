----------------------------------------------------------------------------------
-- Company:  University of Arkansas (NCREPT)
-- Engineer: Chris Farnell
-- 
-- Create Date:			9Jun2019
-- Design Name: 		RS232_Usr_Int
-- Module Name: 		RS232_Usr_Int - Behavioral
-- Project Name: 		Bus Interface Example
-- Target Devices: 		LCMXO2-7000HC-4FG484C (UCB v1.3a)
-- Tool versions: 		Lattice Diamond_x64 Build 3.10.2.115.1
-- 
-- Description: 
-- This module provides an RS232 UART interface which allows access to the memory locations of the device.
-- Default configuration is 1 start bit, 1 stop bit, no parity, and 9600bps.
-- This module uses the Common Bus Architecture.
-- Max of 125 registers for multi-Read and multi-Write Operations per command.
-- Pkt_Length includes bytes between Pkt_Length and Checksum...
-- Pkt_Length (bytes) = Register data + 4; Max Value is 0xFE [Op_ID(1 byte)+ Reg_Cnt(1 byte)+Start_Address(2 bytes) + Register_Data(2 bytes x Register_Cnt)]
--
---- Serial Communications:
-- In the project we will construct packets to facilitate serial communication between the device and a computer. 
-- Using packets we can implement operational commands and check sums which allow for easily implementing a user GUI. 
-- You may use various Serial Interface programs to communicate with this including the old version of X-CTU (Version 5.2.8.6), 
-- Termite, HypterTerminal, or the Custom LabVIEW Interface created for this project (LabVIEW-CommEx_Bus_Interface_v1.1b_9Jun2019).
-- A key to remember is that you will need to create packets in Hex-Mode not the standard ASCII-Mode.
-- All packets will begin with a Start Delimiter (0x7E) and end with a CheckSum. 
-- The CheckSum is calculated by adding up all the bytes of the packet between the packet length and the checksum then 
-- subtracting the sum from 0xFF. 
-- We will implement two types of packets for our use. 
-- Register Write Command Packet (Used to update registers internal to the CPLD)
-- Register Read Command Packet (Used to read registers internal to the CPLD)
--
---Serial Write Packet (OP_ID = 0x0A)
-- The Register Write Command Packet is used to update registers internal to the CPLD. 
-- The following example breaks down a write request packet. 
-- The packet below writes 7 16-bit registers starting at register 0x0100; Values listed below. 
-- PWM_Enable     => 0x0001 (1=Enable; 0=Disable) 
-- LED_BlinkFreq  => 0xBFFF [75%]   (BFFF/FFFF) (%) 
-- LED_OnTime     => 0x6000 [50%]   (6000/BFFF) (%) 
-- LED1_Intensity => 0x2000 [12.5%] (2000/FFFF) (%)
-- LED2_Intensity => 0x4000 [25%]   (4000/FFFF) (%)
-- LED3_Intensity => 0x8000 [50%]   (8000/FFFF) (%)
-- LED4_Intensity => 0xFFFF [100%]  (FFFF/FFFF) (%)
--
-- Start Delimiter| Pkt Len |Op ID| Register_Cnt |Start Address   |Register Data (16bit x Register_Cnt) | ChkSum
-- 0x7E           | 0x12    |0x0A |0x07          |0x0100          |0x0001BFFF6000200040008000FFFF       | 0xF0
-- 0x7E120A0701000001BFFF6000200040008000FFFFF0 results in all LEDs being set to the above parameters.
-- 0x7E120A0701000001BFFF60000000000000000000CE results in all LED Intensities being set to 0%. 
--
--- Serial Read Packet (OP_ID = 0x0F)
-- The Register Read Command Packet is used to read registers internal to the CPLD. 
-- The following example breaks down a read request packet. 
-- The packet below reads 16 16-bit registers starting at register 0x0100. 
--  Start Delimiter| Pkt Len |Op ID| Register_Cnt |Start Address | ChkSum
--  0x7E           | 0x04    |0x0F |0x10          |0x0100        | 0xDF
-- 0x7E040F100100DF 
--
-- The above command results in a write command being sent from the CPLD which contains data from 16 16-bit registers starting at address 0x0100. 
-- An example response from the CPLD is shown below: 
-- 0x7E240A1001000001BFFF6000200040008000FFFF000000000000000000000000000000000000E7 
--  Start Delimiter| Pkt Len |Op ID| Register_Cnt |Start Address |Register Data (16bit x Register_Cnt)                               | ChkSum
--  0x7E           | 0x24    |0x0A |0x10          |0x0100        |0x0001BFFF6000200040008000FFFF000000000000000000000000000000000000 | 0xE7
-- 
--
--
--
-- Revisions:--
--
---- Revision 1.1b-
-- 	Minor Comment Changes
--
---- Revision 1.1a - 
-- Updated to use Protocols based on Zigbee Implementation
--
-- Revision 1.0b - 
-- Updated to use UCB instead of Evaluation Board
--
-- Revision 0.01 - 
-- File Created; Basic\Classical Operation Implemented
--
--
-- Additional Comments: 
-- 
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all; 
use IEEE.numeric_std.all; 
use IEEE.std_logic_arith.all;


library work;
use work.Bus_Interface_Common.all;

entity RS232_Usr_Int is
	generic(
				Baud : integer := 9600;				--9,600 bps
				clk_in : integer := 25000000);			--25MHz 
    Port ( 	clk : in  STD_LOGIC;
				rst : in  STD_LOGIC;
				rs232_rcv : in  STD_LOGIC;
				rs232_xmt : out  STD_LOGIC;
				Data : INOUT  std_logic_vector(15 downto 0);
				Addr : OUT  std_logic_vector(15 downto 0);
				Xrqst : OUT  std_logic;
				XDat : IN  std_logic;
				YDat : OUT  std_logic;
				BusRqst : OUT  std_logic;
				BusCtrl : IN  std_logic
			  );
end RS232_Usr_Int;

architecture Behavioral of RS232_Usr_Int is
	type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12,S13,S14,S15,S16,S17,S18,S19,S20,S21,S22,S23,S24,S25,S26,S27,S28,S29,S30,S31,S32,S33,S34,S35,S36);
 	signal CS_RS232_R, NS_RS232_R, CS_RS232_W, NS_RS232_W, CS_FIFO_Bus, NS_FIFO_Bus: state_type;
	signal rx_done,tx_done :STD_LOGIC:= '0';
	signal temp_rcv: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal i,j: STD_LOGIC_VECTOR (15 downto 0):= (others => '0');
	signal uartclk : STD_LOGIC:= '0';
	signal u: integer;
	signal rs232_rcv_s,rs232_rcv_t: STD_LOGIC:= '1';
	signal txbuff: STD_LOGIC_VECTOR(9 downto 0):= (others => '1');	--buff used to transmit 1 bytes with start and stop bits
	
	--Declare Signals for FIFO Serial Read
	signal STD_FIFO_R_WriteEn, STD_FIFO_R_ReadEn: STD_LOGIC:= '0';
	signal STD_FIFO_R_DataIn, STD_FIFO_R_DataOut: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal STD_FIFO_R_Empty, STD_FIFO_R_Full: STD_LOGIC:= '0';
	
	--Declare Signals for FIFO Serial Write
	signal STD_FIFO_W_WriteEn, STD_FIFO_W_ReadEn: STD_LOGIC:= '0';
	signal STD_FIFO_W_DataIn, STD_FIFO_W_DataOut: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal STD_FIFO_W_Empty, STD_FIFO_W_Full: STD_LOGIC:= '0';
	
	--Declare Signals for Bus Interface
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy: STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
		 
	--Declare Signals for Registers
	signal LD_busy,LD_busy2,LD_rx,LD_tx,LD_temp_data,LD_temp2: STD_LOGIC:= '0';
	signal LD_Temp_Addr_High,LD_Temp_Addr_Low,LD_Temp_Data_High: STD_LOGIC:= '0';
	signal LD_Temp_Data_Low,ld_temp_cmd: STD_LOGIC:= '0';
	signal LD_Pkt_Len,LD_Chk_Sum: STD_LOGIC:= '0';
	signal LD_Base_Addr: STD_LOGIC:= '0';
	signal LD_Reg_Addr_H,LD_Reg_Addr_L: STD_LOGIC:= '0';
	signal LD_Reg_Addr: STD_LOGIC:= '0';
	signal LD_Reg_Cnt: STD_LOGIC:= '0';
	signal LD_Data_Temp_H,LD_Data_Temp_L: STD_LOGIC:= '0';
	
	signal busy,busy_reg_o,busy2,busy2_reg_o,rx,rx_reg_o,tx,tx_reg_o: STD_LOGIC:= '0';
	signal temp_data_reg_o, temp_data: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal temp2_reg_o, temp2: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Temp_Addr_High_reg_o, Temp_Addr_High: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Temp_Addr_Low_reg_o, Temp_Addr_Low: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Temp_Data_High_reg_o, Temp_Data_High: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Temp_Data_Low_reg_o, Temp_Data_Low: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Temp_Cmd_reg_o, Temp_Cmd: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Pkt_Len_reg_o, Pkt_Len: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Chk_Sum_reg_o, Chk_Sum: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal Base_Addr_reg_o, Base_Addr: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal Reg_Addr_H_reg_o, Reg_Addr_H: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Reg_Addr_L_reg_o, Reg_Addr_L: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Reg_Addr_reg_o, Reg_Addr: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal Reg_Cnt_reg_o, Reg_Cnt: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Data_Temp_H_reg_o, Data_Temp_H: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Data_Temp_L_reg_o, Data_Temp_L: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	
	--Signals for Counters
	signal Rcv_Cnt_rst,Rcv_Cnt_INC: STD_LOGIC:= '0';
	signal Rcv_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Buf_Cnt_rst,Buf_Cnt_INC: STD_LOGIC:= '0';
	signal Buf_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal Reg_Cnt_rst,Reg_Cnt_INC: STD_LOGIC:= '0';
	signal Reg_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	
	
	--Signals for RAM (Storing Temp Packet Data) [256 Max]
	type ram_type is array (0 to (2**8)-1) of std_logic_vector(7 downto 0);	
	signal RAM : ram_type;
	signal RAM_wea: STD_LOGIC:= '0';
	signal RAM_address,RAM_Data_In,RAM_Data_Out : std_logic_vector(7 downto 0);



	----User defined variables
	-- CM is the Clock Divder 25MHz/CM=115,200 Baud
	constant CM : integer := clk_in/Baud;
	-- CN is the read offset for serial input
	constant CN : integer :=CM/2; 		
	----End User defined variables
	
	



	--declare STD_FIFO
	COMPONENT STD_FIFO
	Generic (
		DATA_WIDTH 		: integer;		-- Width of FIFO
		FIFO_DEPTH 		: integer;		--	Depth of FIFO
		FIFO_ADDR_LEN  : integer		-- Required number of bits to represent FIFO_Depth
	);
	Port ( 
		CLK     : in  STD_LOGIC;                                      
		RST     : in  STD_LOGIC;         
		WriteEn : in  STD_LOGIC;     
		DataIn  : in  STD_LOGIC_VECTOR (7 downto 0);    
		ReadEn  : in  STD_LOGIC;                                
		DataOut : out STD_LOGIC_VECTOR (7 downto 0);  
		Empty   : out STD_LOGIC;                                
		Full    : out STD_LOGIC                                     
	);
	end COMPONENT;
	
	--declare Bus Interface
	COMPONENT Bus_Int
   PORT(
		clk : IN  std_logic;
		rst : IN  std_logic;
		DataIn : IN  std_logic_vector(15 downto 0);
		DataOut : OUT  std_logic_vector(15 downto 0);
		AddrIn : IN  std_logic_vector(15 downto 0);
		WE : IN  std_logic;
		RE : IN  std_logic;
		Busy : OUT  std_logic;
		Data : INOUT  std_logic_vector(15 downto 0);
		Addr : OUT  std_logic_vector(15 downto 0);
		Xrqst : OUT  std_logic;
		XDat : IN  std_logic;
		YDat : OUT  std_logic;
		BusRqst : OUT  std_logic;
		BusCtrl : IN  std_logic
    );
    END COMPONENT;
	
	--declare Std_Counter Component
	component Std_Counter is
	generic 
	(
		Width : integer		--width of counter
	);
	port(INC,rst,clk: in std_logic;
		 Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end component;
	
	 
	 
begin


	--Instantiate STD_FIFO for Reading Serial Data
	 STD_FIFO_R: STD_FIFO	
	 Generic Map
	 (
		DATA_WIDTH 	=> 8,		-- Width of FIFO
		FIFO_DEPTH 	=> 512,	--	Depth of FIFO
		FIFO_ADDR_LEN => 9	-- Required number of bits to represent FIFO_Depth
	 )
	 Port Map
	 ( 
		CLK => clk,
		RST => rst, 
		WriteEn => STD_FIFO_R_WriteEn,
		DataIn => STD_FIFO_R_DataIn,
		ReadEn => STD_FIFO_R_ReadEn,
		DataOut => STD_FIFO_R_DataOut,
		Empty   => STD_FIFO_R_Empty,
		Full   => STD_FIFO_R_Full 
		);
		
	--Instantiate STD_FIFO for Writing Serial Data
	 STD_FIFO_W: STD_FIFO	
	 Generic Map
	 (
		DATA_WIDTH 	=> 8,		-- Width of FIFO
		FIFO_DEPTH 	=> 512,	--	Depth of FIFO
		FIFO_ADDR_LEN => 9	-- Required number of bits to represent FIFO_Depth
	 )
	 Port Map( 
		CLK => clk,
		RST => rst, 
		WriteEn => STD_FIFO_W_WriteEn,
		DataIn => STD_FIFO_W_DataIn,
		ReadEn => STD_FIFO_W_ReadEn,
		DataOut => STD_FIFO_W_DataOut,
		Empty   => STD_FIFO_W_Empty,
		Full   => STD_FIFO_W_Full 
		);

	--Instantiate Bus Interface
	Bus_Int1: Bus_Int PORT MAP (
          clk => clk,
          rst => rst,
          DataIn => Bus_Int1_DataIn,
          DataOut => Bus_Int1_DataOut,
          AddrIn => Bus_Int1_AddrIn,
          WE => Bus_Int1_WE,
          RE => Bus_Int1_RE,
          Busy => Bus_Int1_Busy,
          Data => Data,
          Addr => Addr,
          Xrqst => Xrqst,
          XDat => XDat,
          YDat => YDat,
          BusRqst => BusRqst,
          BusCtrl => BusCtrl
        );
		
	--instantiate Rcv_Cnt_8
	Rcv_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk,
			rst=> Rcv_Cnt_rst,
			INC=> Rcv_Cnt_INC,
			Count=>Rcv_Cnt_Out);
			
	--instantiate Buf_Cnt_8
	Buf_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk,
			rst=> Buf_Cnt_rst,
			INC=> Buf_Cnt_INC,
			Count=>Buf_Cnt_Out);
			
	--instantiate Reg_Cnt_8
	Reg_Cnt1: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk,
			rst=> Reg_Cnt_rst,
			INC=> Reg_Cnt_INC,
			Count=>Reg_Cnt_Out);
			
			




	----Registers	
	Reg_Proc: process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			busy_reg_o <= '0';
			busy2_reg_o <='0';
			rx_reg_o <= '0';
			tx_reg_o <= '0';
			temp_data_reg_o <= (others => '0');
			temp2_reg_o <= (others => '0');
			Temp_Addr_High_reg_o <= (others => '0');
			Temp_Addr_Low_reg_o <= (others => '0');
			Temp_Data_High_reg_o <= (others => '0');
			Temp_Data_Low_reg_o <= (others => '0');
			Temp_Cmd_reg_o <= (others => '0');
			Pkt_Len_reg_o <= (others => '0');
			Chk_Sum_reg_o <= (others => '0');
			Reg_Addr_H_reg_o <= (others => '0');
			Reg_Addr_L_reg_o <= (others => '0');
			Reg_Addr_reg_o <= (others => '0');
			Data_Temp_H_reg_o <= (others => '0');
			Data_Temp_L_reg_o <= (others => '0');
			Reg_Cnt_reg_o <= (others => '0');
			Base_Addr_reg_o <= (others => '0');
			
		else
		if (LD_busy = '1') then busy_reg_o <= busy; end if;
		if (LD_busy2 = '1') then busy2_reg_o <= busy2; end if;
		if (LD_rx = '1') then rx_reg_o <= rx; end if;
		if (LD_tx = '1') then tx_reg_o <= tx; end if;
		if (LD_temp_data = '1') then temp_data_reg_o <= temp_data; end if;
		if (LD_temp2 = '1') then temp2_reg_o <= temp2; end if;
		if (LD_Temp_Addr_High = '1') then Temp_Addr_High_reg_o <= Temp_Addr_High; end if;
		if (LD_Temp_Addr_Low = '1') then Temp_Addr_Low_reg_o <= Temp_Addr_Low; end if;
		if (LD_Temp_Data_High = '1') then Temp_Data_High_reg_o <= Temp_Data_High; end if;
		if (LD_Temp_Data_Low = '1') then Temp_Data_Low_reg_o <= Temp_Data_Low; end if;
		if (LD_Temp_Cmd = '1') then Temp_Cmd_reg_o <= Temp_Cmd; end if;
		if (LD_Pkt_Len = '1') then Pkt_Len_reg_o <= Pkt_Len; end if;
		if (LD_Chk_Sum = '1') then Chk_Sum_reg_o <= Chk_Sum; end if;
		if (LD_Reg_Addr_H = '1') then Reg_Addr_H_reg_o <= Reg_Addr_H; end if;
		if (LD_Reg_Addr_L = '1') then Reg_Addr_L_reg_o <= Reg_Addr_L; end if;
		if (LD_Reg_Addr = '1') then Reg_Addr_reg_o <= Reg_Addr; end if;
		if (LD_Data_Temp_H = '1') then Data_Temp_H_reg_o <= Data_Temp_H; end if;
		if (LD_Data_Temp_L = '1') then Data_Temp_L_reg_o <= Data_Temp_L; end if;
		if (LD_Reg_Cnt = '1') then Reg_Cnt_reg_o <= Reg_Cnt; end if;
		if (LD_Base_Addr = '1') then Base_Addr_reg_o <= Base_Addr; end if;
	end if;
	end process;
	----End Registers
	
	----Process Memory Data_Reg: process
	Ram_Proc: process
	begin
		wait until clk'event and clk = '1';
		
		if (RAM_wea = '1') then
			RAM(conv_integer(RAM_address)) <= RAM_Data_In;
		end if;
		RAM_Data_Out <= RAM(conv_integer(RAM_address));
	end process Ram_Proc;
	----End Ram
		


	----Next State Logic for Serial Interface Read
	NSL_RS232_R: process(CS_RS232_R,rs232_rcv_s,rx_done,STD_FIFO_R_Full,temp_rcv)
	begin
	
			
		----Default States to remove latches
		busy <='0';
		rx <= '0';
		NS_RS232_R <= S0;
		LD_busy <= '0';
		LD_rx <= '0';
		
		--Signals for FIFO
		STD_FIFO_R_WriteEn <='0';
		STD_FIFO_R_DataIn<= (others => '0');


		
		case CS_RS232_R is
			when S0 =>							-- Waits until data is detected on rs232_rcv_s.
				if (rs232_rcv_s = '1') then
					NS_RS232_R <= S0;
				else
					NS_RS232_R <= S1;
				end if;
					busy <='0';					-- the busy signal stops the baud generator
					rx <= '0';					-- signals to stop reading data
					LD_rx <= '1';
					LD_busy <= '1';

			when S1=>							-- Starts the baud rate generator and reading
					NS_RS232_R<=S2;
					busy <='1';					-- the busy signal starts the baud generator
					rx <= '1';					-- signals to start reading data
					LD_rx <= '1';
					LD_busy <= '1';
					
			when S2 =>							-- Waits until all data is read
					if (rx_done ='0') then
						NS_RS232_R<= S2;
					else
						NS_RS232_R<=S3;
					end if;
					
			when S3 =>
					if (STD_FIFO_R_Full = '0') then
						STD_FIFO_R_DataIn <= temp_rcv;
						STD_FIFO_R_WriteEn <='1';
					end if;
					NS_RS232_R<=S0;

			when others => 
				NS_RS232_R<=S0;
				
		end case;
	end process;
	----End Next State Logic for Serial Interface Read





	----Next State Logic for Serial Interface Write
	NSL_RS232_W: process(CS_RS232_W,tx_done,STD_FIFO_W_Empty,STD_FIFO_W_DataOut)
	begin
	
		----Default States to remove latches
		tx<='0';
		NS_RS232_W <= S0;
		temp2 <= (others => '0');
		LD_tx <= '0';
		LD_temp2<='0';
		Busy2 <='0';
		LD_Busy2<='0';
		
		--Signals for FIFO
		STD_FIFO_W_ReadEn <= '0';

		case CS_RS232_W is
		
			when S0=>
				if(STD_FIFO_W_Empty = '1') then
					NS_RS232_W<=S0;
				else
					NS_RS232_W<=S1;
					STD_FIFO_W_ReadEn <= '1';
				end if;
				busy2 <='0';					-- the busy signal stops the baud generator
				tx <= '0';						-- signals to stop sending data
				LD_tx <= '1';
				LD_busy2 <= '1';
		
			when S1=>
				temp2<=STD_FIFO_W_DataOut;
				LD_temp2<='1';
				NS_RS232_W<=S2;
				
			when S2=>
				busy2 <='1';					-- the busy signal starts the baud generator
				tx<='1';							-- signals to start sending data
				LD_tx<='1';
				LD_busy2 <= '1';
				NS_RS232_W<=S3;
				
			when S3=>
				if(tx_done='0') then
					NS_RS232_W <=S3;
				else
					NS_RS232_W <=S0;
				end if;

			when others => 
				NS_RS232_W <=S0;

		end case;
	end process;
	----End Next State Logic for Serial Interface Write




	----Next State Logic for FIFO to Bus
	NSL_FIFO_Bus: process(CS_FIFO_Bus, STD_FIFO_R_Empty,Temp_Cmd_reg_o,Bus_Int1_Busy,STD_FIFO_R_DataOut,Temp_Addr_High_reg_o,Temp_Addr_Low_reg_o,Temp_Data_High_reg_o,Temp_Data_Low_reg_o,Temp_Data_reg_o,Bus_Int1_DataOut,temp_data_reg_o,Pkt_Len_reg_o,Chk_Sum_reg_o,Rcv_Cnt_Out,RAM_Data_Out,Reg_Cnt_reg_o,Reg_Addr_H_reg_o,Reg_Addr_L_reg_o,Base_Addr_reg_o )
	begin

		----Default States to remove latches
		NS_FIFO_Bus <=S0;
		Temp_Cmd <= (others => '0');
		LD_Temp_Cmd <='0';
		Temp_Addr_High <= (others => '0');
		LD_Temp_Addr_High <='0';
		Temp_Addr_Low <= (others => '0');
		LD_Temp_Addr_Low <='0';
		Bus_Int1_AddrIn <= (others => '0');
		Bus_Int1_RE <='0';
		Bus_Int1_DataIn <= (others => '0');
		Bus_Int1_WE <='0';
		Temp_Data <= (others => '0');
		LD_Temp_Data <='0';
		Temp_Data_High <= (others => '0');
		LD_Temp_Data_High <='0';
		Temp_Data_Low<= (others => '0');
		LD_Temp_Data_Low <='0';
		
		--Signals for FIFO
		STD_FIFO_R_ReadEn <='0';
		STD_FIFO_W_DataIn <= (others => '0');
		STD_FIFO_W_WriteEn <='0';
		
		--Signals for Counters
		Rcv_Cnt_rst<='1';
		Rcv_Cnt_INC<='0';
		Buf_Cnt_rst<='1';
		Buf_Cnt_INC<='0';
		Reg_Cnt_rst<='1';
		Reg_Cnt_INC<='0';
		
		--Signals for memory
		RAM_address <= (others => '0');
		RAM_Data_In <= (others => '0');
		RAM_wea <= '0';
		
		Pkt_Len <= (others => '0');
		LD_Pkt_Len <='0';
		Chk_Sum <= (others => '0');
		LD_Chk_Sum <='0';
		
		
		Reg_Addr_H <= (others => '0');
		LD_Reg_Addr_H <='0';
		Reg_Addr_L <= (others => '0');
		LD_Reg_Addr_L <='0';
		Reg_Addr <= (others => '0');
		LD_Reg_Addr <='0';
		Data_Temp_H <= (others => '0');
		LD_Data_Temp_H <='0';
		Data_Temp_L <= (others => '0');
		LD_Data_Temp_L <='0';
		Reg_Cnt <= (others => '0');
		LD_Reg_Cnt <='0';
		Base_Addr <= (others => '0');
		LD_Base_Addr <='0';
			

		case CS_FIFO_Bus is
		
			when S0=>					
				if(STD_FIFO_R_Empty = '1') then		--Check to see if commands are in queue
					NS_FIFO_Bus<=S0;
				else
					NS_FIFO_Bus<=S1;
					STD_FIFO_R_ReadEn <= '1';		--Assert Read Signal for FIFO
				end if;
				Rcv_Cnt_rst<='0';
				Buf_Cnt_rst<='0';
				Reg_Cnt_rst<='0';
				
			when S1=>								--Read Command from FIFO
				Temp_Cmd<=STD_FIFO_R_DataOut;
				LD_Temp_Cmd<='1';
				NS_FIFO_Bus<=S2;
			
			when S2=>
				if(Temp_Cmd_reg_o = X"7E") then		--Check Cmd (Start Delimiter)
					NS_FIFO_Bus <= S3;
				else								--Check Cmd (Invalid Data)
					NS_FIFO_Bus <= S0;
				end if;
						
			when S3=>
				if(STD_FIFO_R_Empty = '1') then		--Check to see if commands are in queue
					NS_FIFO_Bus<=S3;
				else
					NS_FIFO_Bus<=S4;
					STD_FIFO_R_ReadEn <= '1';		--Assert Read Signal for FIFO
				end if;
			
			when S4=>								--Read Command from FIFO
				Pkt_Len<=STD_FIFO_R_DataOut;
				LD_Pkt_Len<='1';
				NS_FIFO_Bus<=S5;
			
			when S5=>
				if((Pkt_Len_reg_o < X"FF") and (Pkt_Len_reg_o > X"03")) then		--Check Packet Length (Packet Length < 255 bytes) [0xFE is Max; 0x04 is Min]
					NS_FIFO_Bus <= S6;
				else								--Check Cmd (Invalid Data)
					NS_FIFO_Bus <= S0;
				end if;
				Chk_Sum <= X"0000";
				LD_Chk_Sum <='1';
				Rcv_Cnt_rst<='0';					--Active Low
				
			when S6=>
				if(Rcv_Cnt_Out < (Pkt_Len_reg_o+1)) then		--Read data to memory
					NS_FIFO_Bus <= S7;
				else			
					NS_FIFO_Bus <= S9;
				end if;
			
			when S7=>	
				if(STD_FIFO_R_Empty = '1') then		--Check to see if commands are in queue
					NS_FIFO_Bus<=S7;
				else
					NS_FIFO_Bus<=S8;
					STD_FIFO_R_ReadEn <= '1';			--Assert Read Signal for FIFO
				end if;
		
			when S8=>									--Read Data from FIFO to memory and calc checksum
				if(Rcv_Cnt_Out < (Pkt_Len_reg_o)) then
					LD_Chk_Sum <= '1';
				end if;

				RAM_Data_In <= STD_FIFO_R_DataOut;
				RAM_address <= Rcv_Cnt_Out;
				RAM_wea <='1';
				Chk_Sum <= Chk_Sum_reg_o + STD_FIFO_R_DataOut;
				Temp_Cmd <= STD_FIFO_R_DataOut;
				LD_Temp_Cmd <= '1';
				Rcv_Cnt_INC<='1';
				NS_FIFO_Bus <= S6;
				
			when S9=>									--Check Calculated Checksum with recieved
				if((X"FF"-Chk_Sum_reg_o(7 downto 0)) = Temp_Cmd_reg_o) then
					NS_FIFO_Bus <= S10;
				else
					NS_FIFO_Bus <= S0;
				end if;
				Rcv_Cnt_rst<='0';
				RAM_address <= X"01";
				
			when S10=>								--Load Register Count
				Reg_Cnt <= RAM_Data_Out;
				LD_Reg_Cnt <='1';
				RAM_address <= X"01";
				NS_FIFO_Bus <= S11;
				
			when S11=>
				RAM_address <= X"02";
				NS_FIFO_Bus <= S12;
				
			when S12=>								--Load Starting Address High
				Reg_Addr_H <= RAM_Data_Out;
				LD_Reg_Addr_H <='1';
				RAM_address <= X"02";
				NS_FIFO_Bus <= S13;
				
			when S13=>
				RAM_address <= X"03";
				NS_FIFO_Bus <= S14;
				
			when S14=>								--Load Starting Address Low
				Reg_Addr_L <= RAM_Data_Out;
				LD_Reg_Addr_L <='1';
				RAM_address <= X"03";
				NS_FIFO_Bus <= S15;
				
			when S15=>
				Base_Addr(15 downto 8) <= Reg_Addr_H_reg_o;
				Base_Addr(7 downto 0) <= Reg_Addr_L_reg_o;
				LD_Base_Addr <= '1';
				RAM_address <= X"00";
				NS_FIFO_Bus <= S16;
							
			when S16=>
				if(RAM_Data_Out = X"0F") then		--Check Cmd (Read)
					NS_FIFO_Bus <= S17;
				elsif(RAM_Data_Out = X"0A") then	--Check Cmd (Write)
					NS_FIFO_Bus <= S28;
				else								--Check Cmd (Invalid Data)
					NS_FIFO_Bus <= S0;
				end if;
				RAM_address <= X"00";
				Rcv_Cnt_rst<='0';
			
			-- Start Read Command Sequence
			when S17=>								--Send First byte of Packet(Start Deliminator)
				STD_FIFO_W_DataIn<= X"7E";
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= X"00FF";					--Reset Checksum
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus<=S18;
				
			when S18=>
				STD_FIFO_W_DataIn <= ((Reg_Cnt_reg_o(7 downto 0) + Reg_Cnt_reg_o(7 downto 0)) + 4);	--Packet Length = Registers * 2 + 4 bytes overhead
				STD_FIFO_W_WriteEn <='1';
				NS_FIFO_Bus<=S19;
							
			when S19=>								--Send Second byte of Packet (OP_ID)
				STD_FIFO_W_DataIn <= X"0A";			--Send OP_ID (Write)
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= Chk_Sum_reg_o - X"0A";
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus<=S20;
			
			when S20=>								--Send Third byte of Packet (Register Count)
				STD_FIFO_W_DataIn <= Reg_Cnt_reg_o;	--Send Start Address High
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= Chk_Sum_reg_o - Reg_Cnt_reg_o;
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus<=S21;

			when S21=>								--Send Fourth byte of Packet (Starting Address High)
				STD_FIFO_W_DataIn <= Reg_Addr_H_reg_o;	--Send Start Address High
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= Chk_Sum_reg_o - Reg_Addr_H_reg_o;
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus<=S22;
				
			when S22=>								--Send Fifth byte of Packet (Starting Address Low)
				STD_FIFO_W_DataIn <= Reg_Addr_L_reg_o;	--Send Start Address Low
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= Chk_Sum_reg_o - Reg_Addr_L_reg_o;
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus<=S23;
					
			when S23=>
				if(Rcv_Cnt_Out < Reg_Cnt_reg_o) then	--If less than Register Count
					Bus_Int1_AddrIn <= Base_Addr_reg_o + Rcv_Cnt_Out ;	--Send Address to Bus Interface for Read 
					Bus_Int1_RE <='1';						--Read Flag to Bus Interface
					NS_FIFO_Bus<=S24;
				else
					NS_FIFO_Bus<=S27;
				end if;
					
			when S24=>										--Wait until data is ready
				if(Bus_Int1_Busy = '1') then
					NS_FIFO_Bus<=S24;
				else
					NS_FIFO_Bus<=S25;
				end if;
				Temp_Data <= Bus_Int1_DataOut;
				LD_Temp_Data <= '1';
			
			when S25=>									-- Send Data High
				STD_FIFO_W_DataIn <= Temp_Data_reg_o(15 downto 8);
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= Chk_Sum_reg_o - Temp_Data_reg_o(15 downto 8);
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S26;
				
			when S26=>									-- Send Data Low
				STD_FIFO_W_DataIn<= Temp_Data_reg_o(7 downto 0);
				STD_FIFO_W_WriteEn <='1';
				Chk_Sum <= Chk_Sum_reg_o - Temp_Data_reg_o(7 downto 0);
				LD_Chk_Sum <= '1';
				Rcv_Cnt_Inc <='1';
				NS_FIFO_Bus <= S23;
				
			when S27=>
				STD_FIFO_W_DataIn<= Chk_Sum_reg_o(7 downto 0);
				STD_FIFO_W_WriteEn <='1';
				NS_FIFO_Bus <= S0;
			-- End Read Command Sequence
			
			-- Start Write Command Sequence
			when S28=>
				if(Rcv_Cnt_Out < Reg_Cnt_reg_o) then	--If less than Register Count
					NS_FIFO_Bus <= S29;
				else
					NS_FIFO_Bus <= S0;					--Done
				end if;
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out + 4;
				
			when S29=>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out + 4;
				Temp_Data_High <= RAM_Data_Out;
				--LD_Temp_Data_High <='1';
				NS_FIFO_Bus <= S30;
				
			when S30=>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out + 4;
				Temp_Data_High <= RAM_Data_Out;
				LD_Temp_Data_High <='1';
				NS_FIFO_Bus <= S31;
			
			when S31=>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out + 5;
				NS_FIFO_Bus <= S32;
			
			when S32=>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out + 5;
				Temp_Data_Low <= RAM_Data_Out;
				--LD_Temp_Data_Low <='1';
				NS_FIFO_Bus <= S33;
				
			when S33=>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out + 5;
				Temp_Data_Low <= RAM_Data_Out;
				LD_Temp_Data_Low <='1';
				NS_FIFO_Bus <= S34;
				
			when S34=>
				NS_FIFO_Bus <= S35;
				
			when S35=>
				Bus_Int1_AddrIn <= Base_Addr_reg_o + Rcv_Cnt_Out;   --Send Address to Bus Interface for Write
				Bus_Int1_DataIn(15 downto 8)<=Temp_Data_High_reg_o;	--Send Data to Bus Interface for Write 
				Bus_Int1_DataIn(7 downto 0)<=Temp_Data_Low_reg_o;		--Send Data to Bus Interface for Write 
				Bus_Int1_WE <='1';												--Write Flag to Bus Interface
				NS_FIFO_Bus <= S36;
				
			when S36=>										--Wait until data is ready
				if(Bus_Int1_Busy = '1') then
					NS_FIFO_Bus<=S36;
				else
					Rcv_Cnt_Inc <='1';
					NS_FIFO_Bus<=S28;
				end if;	
			-- End Write Command Sequence

			when others => 
				NS_FIFO_Bus <=S0;

		end case;
	end process;
	----End Next State Logic for FIFO to Bus	

	----UART Clock Divider
	UART_Clk: process
	begin
		wait until clk'event and clk = '1';
		--Synchronize async signal
		rs232_rcv_t<=rs232_rcv;				--Synchro1 rs232_rcv
		rs232_rcv_s<=rs232_rcv_t;			--Synchro2 rs232_rcv
		
		if(rst = '0' or (busy_reg_o = '0' and busy2_reg_o = '0')) then
			uartclk <='0';
			i <= CONV_STD_LOGIC_VECTOR(CN,16);
		elsif( i = CM ) then
				uartclk <= '1';
				i <= X"0000";
		else
				i <= i+1;
				uartclk<='0';
			end if;
	end process;
	---- End UART Clock Divider

	----UART_Read
	UART_Read: process
	begin
		wait until clk'event and clk = '1';
		if rst ='0' or rx_reg_o='0' then
			temp_rcv<= x"00";
			j<=x"0000";
			rx_done<='0';
		elsif rx_reg_o='1' then
			if uartclk='1' then
				if j<X"09" then
					temp_rcv(7)<=rs232_rcv_s;			
					temp_rcv(6 downto 0)<=temp_rcv(7 downto 1);
					j<=j+1;
					rx_done <='0';
				else
					j <= X"0000";
					rx_done <='1';
				end if;
			else
				rx_done<='0';
			end if;
		end if;
	end process;
	----End UART_Read



	-----UART_Xmit
	UART_Xmit: process
	begin
		wait until clk'event and clk = '1';
		if (rst = '0' or tx_reg_o='0') then
			rs232_xmt<='1';
			tx_done <='0';
			u<=0;
			
			--structure the 10-bit frame to be sent
			txbuff(9)<='1'; --stopbit 2
			txbuff(8 downto 1) <= temp2_reg_o;
			txbuff(0)<='0';	--startbit 2
		else
			if uartclk = '1' then
				if(u<10) then
					rs232_xmt<= txbuff(0);
					txbuff(8 downto 0) <= txbuff(9 downto 1);
					tx_done<='0';
					u<=u+1;
				else
					u<=0;
					tx_done<='1';
				end if;
			end if;
		end if;
	end process;
	-----End UART_Xmit

	
	----State Sync
	sync_States: process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			CS_RS232_R <= S0;
			CS_RS232_W <= S0;
			CS_FIFO_Bus <= S0;
		else
			CS_RS232_R <= NS_RS232_R;
			CS_RS232_W <= NS_RS232_W;
			CS_FIFO_Bus <= NS_FIFO_Bus;
		end if;
	end process;
	----End State Sync
	
	
end Behavioral;

