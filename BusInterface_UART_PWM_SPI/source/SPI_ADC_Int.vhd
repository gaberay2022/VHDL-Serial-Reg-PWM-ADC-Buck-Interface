----------------------------------------------------------------------------------
-- Company:  University of Arkansas (NCREPT)
-- Engineer: Chris Farnell
-- 
-- Create Date:			9Jun2019
-- Last Updated:		25Apr2021
-- Design Name: 		ADC_Int 
-- Module Name: 		ADC_Int - Behavioral 
-- Project Name: 		Bus Interface Example
-- Target Devices: 		LCMXO3D-9400HC-6BG256C (MachXO3D_BreakoutBrd)
-- Tool versions: 		Lattice Diamond_x64 Build  3.12.0.240.2
-- 
-- Description: 
-- This module provides an RS232 UART interface which allows access to the memory locations of the device.
-- Default configuration is 1 start bit, 1 stop bit, no parity, and 9600bps.
-- This module uses the Common Bus Architecture.
-- Max of 125 registers for multi-Read and multi-Write Operations per command.
-- Pkt_Length includes bytes between Pkt_Length and Checksum...
-- Pkt_Length (bytes) = Register data + 4; Max Value is 0xFE [Op_ID(1 byte)+ Reg_Cnt(1 byte)+Start_Address(2 bytes) + Register_Data(2 bytes x Register_Cnt)]
--
-- Description: 		This module controls a 12-bit (AD7928BRUZ) ADC.
--
-- This module continously samples the ADC of to the channel defined by "Chan".
-- Currently we are sampling at 2 times the switching frequency then averaging
-- over one switching period.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
-- This module controls a 12-bit (AD7928BRUZ) ADC.



--#################################################################################
-- * 
-- * Register details for ADC7928
-- * Control: 12 bits wide, first 12 of 16 bits used
-- * ___________________________________________________________________
-- * |write|SEQ|don'tcare|ADD2|ADD1|ADD0|PM1|PM0 |SHADOW|DC|RANGE|CODING|
-- * | 11  |10 | 9       | 8  | 7  | 6  | 5 | 4  |  3   |2 |  1  |  0   |
-- * |1=wr |n1 |         |ch to convert |pwr mode| n1   |  | n2  | n3   |
-- * 
-- * n1: selects the mode of channel sampling 00= addressed channel only
-- * n2: 0 = 0v to 2*REFin, 1 = 0v to REFin
-- * n3: 0 = two's comp output, 1 = raw binary
-- * 
-- * 
-- * Sequence register is 16 bits (2*8), order of channel sampling
--#################################################################################




----------------------------------ROM for ADC Commands------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity SPI_ROM is
	port(	rst,clk,D_Sel: in std_logic;
		data: out std_logic_vector(15 downto 0));
end;

architecture behavior of SPI_ROM is

begin
	SPI_ROM_behav: process
	begin
			-- X"831F";		-- Command to read ADC Channel 0
			-- X"FFDF";		-- Command to read All ADC Channels Continuously
			-- X"E3DF";		-- Command to read ADC Channel 0 Continuously
			-- X"E7DF";		-- Command to read ADC Channel 1+2 Continuously
			--	X"FFDF";		-- Command to read All ADC Channels Continuously
			--	X"871F";		-- Command to read ADC Channel 1
			--	X"8B1F";		-- Command to read ADC Channel 2
			--	X"8F1F";		-- Command to read ADC Channel 3
			--	X"931F";		-- Command to read ADC Channel 4
			--	X"971F";		-- Command to read ADC Channel 5
			--	X"9B1F";		-- Command to read ADC Channel 6
			--	X"9F1F";		-- Command to read ADC Channel 7
			
		wait until clk'event and clk = '1';
		if rst='0' then
			data<=(Others =>'0');
		else
			if D_Sel = '0' then
				data <= X"FFDF";		-- Command to read All ADC Channels Continuously
			else
				data <= X"FFFF";		-- Dummy Command for startup
			end if;
		end if;
		
	end process;
end behavior;
----------------------------------End ROM for ADC Commands------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

library work;
use work.Bus_Interface_Common.all;

entity ADC_Int is
    Port ( clk : in  STD_LOGIC;										-- System Clock Input
				rst : in  STD_LOGIC;										-- System Reset
				Data : INOUT  std_logic_vector(15 downto 0);
				Addr : OUT  std_logic_vector(15 downto 0);
				Xrqst : OUT  std_logic;
				XDat : IN  std_logic;
				YDat : OUT  std_logic;
				BusRqst : OUT  std_logic;
				BusCtrl : IN  std_logic;
				SPI_Sclk : inout  STD_LOGIC;								-- Output SPI CLK
				SPI_Din : inout  STD_LOGIC;								-- Output SPI Data
				SPI_CSn : out  STD_LOGIC;								-- Chip-Select for ADC
				SPI_Dout : in  STD_LOGIC								-- Input from ADC
				);
end ADC_Int;

architecture Behavioral of ADC_Int is
	
	----Constants
	constant Chan : STD_LOGIC_VECTOR (2 downto 0) := b"111";				-- Set Maximum sampled ADC Channel to 7
	--constant Delay : STD_LOGIC_VECTOR (15 downto 0) := X"03FE";			-- Initial ADC delay for Sync
	constant Delay : STD_LOGIC_VECTOR (15 downto 0) := X"00BA";			-- Initial ADC delay for Sync
	constant Offset_Chan : STD_LOGIC_VECTOR (7 downto 0) := X"07";		-- Delay between samples (Channel)
	constant Offset_Set : STD_LOGIC_VECTOR (7 downto 0) := X"1E";		-- This is the delay between sampling sets
	constant Sample_Size :integer := 2;											-- Sample Size for Averaging
	

	type state_type is (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18);
	signal CS_ADC_Ctrl, NS_ADC_Ctrl, CS_Bus_Ctrl, NS_Bus_Ctrl: state_type:=S0;
	
	signal SPI_Cnt_INC, SPI_Cnt_rst, Prg_Cnt_INC, Prg_Cnt_rst, Setup_Cnt_INC, Setup_Cnt_rst  :std_logic:='0';
	signal Prg_Cnt_Out, Setup_Cnt_Out : STD_LOGIC_VECTOR (7 downto 0):= (others => '0');
	signal SPI_Cnt_Out: STD_LOGIC_VECTOR (15 downto 0):= (others => '0');
	
	signal SPI_ROM1_D_SEL :std_logic:='0';
	--signal SPI_ROM1_addr :STD_LOGIC_VECTOR (2 downto 0);
	signal SPI_ROM1_data :STD_LOGIC_VECTOR (15 downto 0):= (others => '0');
	
	signal SPI_PS_ld_D, SPI_PS_sh_D, SPI_PS_rst :std_logic:='0';
	--signal SPI_PS_Data_In :STD_LOGIC_VECTOR (15 downto 0);
	
	signal SPI_SP_ld_D, SPI_SP_rst :std_logic:='0';
	signal SPI_SP1_Data_Out,SPI_SP2_Data_Out :STD_LOGIC_VECTOR (15 downto 0):= (others => '0');
	
	signal SPI_Dout1_Sync  :std_logic:='0';
	signal SPI_Dout2_Sync  :std_logic:='0';
	
	--Signals for ADC Memory
	type Memory is array (15 downto 0) of STD_LOGIC_VECTOR (15 downto 0);
	signal ADC_Mem: Memory;																	--Memory Array for collecting sample data
	signal ADC_wea:std_logic:='0';														--Write Enable
	signal ADC_Mem_Ave: Memory;															--Memory Array for averaging samples
	signal ADC_Ave_Ld, ADC_Ave_En :std_logic:='0';									--Load Averaged Memory Array
	signal ADC_Mem_Temp: Memory;															--Temp Memory Array for averaging samples
	signal ADC_Temp_rst:std_logic:='0';													--Reset Temp Memory Array
	signal Ave_Cnt_INC, Ave_Cnt_rst :std_logic:='0';								--Counter Control Signals
	signal Ave_Cnt_Out : STD_LOGIC_VECTOR (7 downto 0):= (others => '0');	--Counter Output
	signal ADC_Mem_Ave_M1,ADC_Mem_Ave_M2: Memory;									--Registers for Metastable crossing of clock domains
	
	
	--Declare Signals for Bus Interface
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy: STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal Bus_Cnt_rst, Bus_Cnt_INC: STD_LOGIC:= '0';
	signal Bus_Cnt_Out: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal Mem_Addr_Cnt_rst, Mem_Addr_Cnt_INC: STD_LOGIC:= '0';
	signal Mem_Addr_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');

	
	
	--For Clock Divider
	signal clk_temp2 : std_logic_vector(3 downto 0):= (others => '0');
	signal clk_SPI : std_logic := '0';
	
	--For SPI Setup Loop Counter
	signal SPI_CNT_Loop_INC, SPI_CNT_Loop_rst  :std_logic:='0';
	signal SPI_CNT_Loop_Out : STD_LOGIC_VECTOR (15 downto 0):= (others => '0');
	
	

	--declare Std_Counter Component
	component Std_Counter is
	generic 
	(
		Width : integer		--width of counter
	);
	port(INC,rst,clk: in std_logic;
		 Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end component;
	
	
	
	-- declare SPI_ROM component
		component SPI_ROM is
		 Port ( clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC;
				  D_Sel : in  STD_LOGIC;
				  data: out std_logic_vector(15 downto 0));
	end component;

	-- declare Sreg_PS_16 component
		component Sreg_PS_16 is
		 Port ( clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC;
				  ld_D : in  STD_LOGIC;
				  sh_D : in  STD_LOGIC;
				  Data_In: in STD_LOGIC_VECTOR(15 downto 0);
				  Data_Out: out std_logic);
	end component;
	
	-- declare Sreg_SP_16 component
		component Sreg_SP_16 is
		 Port ( clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC;
				  ld_D : in  STD_LOGIC;
				  Data_In: in  STD_LOGIC;
				  Data_Out: out STD_LOGIC_VECTOR(15 downto 0));
	end component;
	
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


begin

	--Connect Signals
	SPI_sclk <= clk_SPI;
	--SPI_Din<=SPI_PS_Data_Out;

	--instantiate SPI_Cnt_16
	SPI_Cnt: Std_Counter
	generic map
	(
		Width => 16
	)
	port map( 
			clk => clk_SPI,
			rst=> SPI_Cnt_rst,
			INC=> SPI_Cnt_INC,
			Count=>SPI_Cnt_Out);
			

	--instantiate Prg_Cnt_8
	Prg_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk_SPI,
			rst=> Prg_Cnt_rst,
			INC=> Prg_Cnt_INC,
			Count=>Prg_Cnt_Out);
			
	--instantiate Setup_Cnt_8
	Setup_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk_SPI,
			rst=> Setup_Cnt_rst,
			INC=> Setup_Cnt_INC,
			Count=>Setup_Cnt_Out);
			
	--instantiate Ave_Cnt_8
	Ave_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk_SPI,
			rst=> Ave_Cnt_rst,
			INC=> Ave_Cnt_INC,
			Count=>Ave_Cnt_Out);
			
	--instantiate Mem_Cnt
	Mem_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
			clk => clk,
			rst=> Mem_Addr_Cnt_rst,
			INC=> Mem_Addr_Cnt_INC,
			Count=> Mem_Addr_Cnt_Out);
							
	--instantiate SPI_ROM1
	SPI_ROM1: SPI_ROM	port map( 
			clk => clk_SPI,
			rst=> rst,
			D_SEL=> SPI_ROM1_D_SEL,
			data=>SPI_ROM1_data);
	
	--instantiate SPI_PS
	SPI_PS: Sreg_PS_16	port map( 
			clk => clk_SPI,
			rst=> SPI_PS_rst,
			ld_D=> SPI_PS_ld_D,
			sh_D=> SPI_PS_sh_D,
			--Data_In=> SPI_PS_Data_In,
			Data_In=>SPI_ROM1_data,
			Data_Out=> SPI_Din);

	--instantiate SPI_SP for ADC1
	SPI_SP: Sreg_SP_16	port map( 
			clk => clk_SPI,
			rst=> SPI_SP_rst,
			ld_D=> SPI_SP_ld_D,
			Data_In=> SPI_Dout1_Sync,
			Data_Out=> SPI_SP1_Data_Out);
					
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
		  
	--instantiate Bus_Cnt_16
	Bus_Cnt: Std_Counter
	generic map
	(
		Width => 16
	)
	port map( 
			clk =>  clk,
			rst=> Bus_Cnt_rst,
			INC=> Bus_Cnt_INC,
			Count=>Bus_Cnt_Out);
			
	--instantiate Bus_Cnt_16
	SPI_Loop_Cnt: Std_Counter
	generic map
	(
		Width => 16
	)
	port map( 
			clk =>  clk,
			rst=> SPI_CNT_Loop_rst,
			INC=> SPI_CNT_Loop_INC,
			Count=>SPI_CNT_Loop_Out);
			

			
	----Process for storing sampled data into ADC Memory	
	ADC_Mem_W: process
	begin
		wait until clk_SPI'event and clk_SPI = '1';
		if rst = '0' then
			ADC_Mem(0) <= (others => '0');
			ADC_Mem(1) <= (others => '0');
			ADC_Mem(2) <= (others => '0');
			ADC_Mem(3) <= (others => '0');
			ADC_Mem(4) <= (others => '0');
			ADC_Mem(5) <= (others => '0');
			ADC_Mem(6) <= (others => '0');
			ADC_Mem(7) <= (others => '0');
			ADC_Mem(8) <= (others => '0');
			ADC_Mem(9) <= (others => '0');
			ADC_Mem(10) <= (others => '0');
			ADC_Mem(11) <= (others => '0');
			ADC_Mem(12) <= (others => '0');
			ADC_Mem(13) <= (others => '0');
			ADC_Mem(14) <= (others => '0');
			ADC_Mem(15) <= (others => '0');
			
		elsif ADC_wea = '1' then
			if SPI_SP1_Data_Out(14 downto 12)= "000" then ADC_Mem(0)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "001" then ADC_Mem(1)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "010" then ADC_Mem(2)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "011" then ADC_Mem(3)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "100" then ADC_Mem(4)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "101" then ADC_Mem(5)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "110" then ADC_Mem(6)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			if SPI_SP1_Data_Out(14 downto 12)= "111" then ADC_Mem(7)		<= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;


	end if;
	end process;
	----End Registers
	
	----Process for averaging sampled data
	Sample_Ave: process
	begin
		wait until clk_SPI'event and clk_SPI = '1';
		if (rst = '0' or ADC_Temp_rst = '0') then
			ADC_Mem_Temp(0) <= (others => '0');
			ADC_Mem_Temp(1) <= (others => '0');
			ADC_Mem_Temp(2) <= (others => '0');
			ADC_Mem_Temp(3) <= (others => '0');
			ADC_Mem_Temp(4) <= (others => '0');
			ADC_Mem_Temp(5) <= (others => '0');
			ADC_Mem_Temp(6) <= (others => '0');
			ADC_Mem_Temp(7) <= (others => '0');
			ADC_Mem_Temp(8) <= (others => '0');
			ADC_Mem_Temp(9) <= (others => '0');
			ADC_Mem_Temp(10) <= (others => '0');
			ADC_Mem_Temp(11) <= (others => '0');
			ADC_Mem_Temp(12) <= (others => '0');
			ADC_Mem_Temp(13) <= (others => '0');
			ADC_Mem_Temp(14) <= (others => '0');
			ADC_Mem_Temp(15) <= (others => '0');
			
		elsif ADC_Ave_En = '1' then
		
			ADC_Mem_Temp(0) <= ADC_Mem(0) + ADC_Mem_Temp(0);
			ADC_Mem_Temp(1) <= ADC_Mem(1) + ADC_Mem_Temp(1);
			ADC_Mem_Temp(2) <= ADC_Mem(2) + ADC_Mem_Temp(2);
			ADC_Mem_Temp(3) <= ADC_Mem(3) + ADC_Mem_Temp(3);
			ADC_Mem_Temp(4) <= ADC_Mem(4) + ADC_Mem_Temp(4);
			ADC_Mem_Temp(5) <= ADC_Mem(5) + ADC_Mem_Temp(5);
			ADC_Mem_Temp(6) <= ADC_Mem(6) + ADC_Mem_Temp(6);
			ADC_Mem_Temp(7) <= ADC_Mem(7) + ADC_Mem_Temp(7);
			ADC_Mem_Temp(8) <= ADC_Mem(8) + ADC_Mem_Temp(8);
			ADC_Mem_Temp(9) <= ADC_Mem(9) + ADC_Mem_Temp(9);
			ADC_Mem_Temp(10) <= ADC_Mem(10) + ADC_Mem_Temp(10);
			ADC_Mem_Temp(11) <= ADC_Mem(11) + ADC_Mem_Temp(11);
			ADC_Mem_Temp(12) <= ADC_Mem(12) + ADC_Mem_Temp(12);
			ADC_Mem_Temp(13) <= ADC_Mem(13) + ADC_Mem_Temp(13);
			ADC_Mem_Temp(14) <= ADC_Mem(14) + ADC_Mem_Temp(14);
			ADC_Mem_Temp(15) <= ADC_Mem(15) + ADC_Mem_Temp(15);

	end if;
	end process;
	----End Registers
	
	
		----Process for storing averaged sample data
	ADC_Mem_Ave_Reg: process
	begin
		wait until clk_SPI'event and clk_SPI = '1';
		if (rst = '0' ) then
			ADC_Mem_Ave(0) <= (others => '0');
			ADC_Mem_Ave(1) <= (others => '0');
			ADC_Mem_Ave(2) <= (others => '0');
			ADC_Mem_Ave(3) <= (others => '0');
			ADC_Mem_Ave(4) <= (others => '0');
			ADC_Mem_Ave(5) <= (others => '0');
			ADC_Mem_Ave(6) <= (others => '0');
			ADC_Mem_Ave(7) <= (others => '0');
			ADC_Mem_Ave(8) <= (others => '0');
			ADC_Mem_Ave(9) <= (others => '0');
			ADC_Mem_Ave(10) <= (others => '0');
			ADC_Mem_Ave(11) <= (others => '0');
			ADC_Mem_Ave(12) <= (others => '0');
			ADC_Mem_Ave(13) <= (others => '0');
			ADC_Mem_Ave(14) <= (others => '0');
			ADC_Mem_Ave(15) <= (others => '0');
			
		elsif ADC_Ave_Ld = '1' then
			ADC_Mem_Ave(0) <=	b"0" & ADC_Mem_Temp(0)(15 downto 1);
			ADC_Mem_Ave(1) <= b"0" & ADC_Mem_Temp(1)(15 downto 1);
			ADC_Mem_Ave(2) <= b"0" & ADC_Mem_Temp(2)(15 downto 1);
			ADC_Mem_Ave(3) <= b"0" & ADC_Mem_Temp(3)(15 downto 1);
			ADC_Mem_Ave(4) <= b"0" & ADC_Mem_Temp(4)(15 downto 1);
			ADC_Mem_Ave(5) <= b"0" & ADC_Mem_Temp(5)(15 downto 1);
			ADC_Mem_Ave(6) <= b"0" & ADC_Mem_Temp(6)(15 downto 1);
			ADC_Mem_Ave(7) <= b"0" & ADC_Mem_Temp(7)(15 downto 1);
			ADC_Mem_Ave(8) <= b"0" & ADC_Mem_Temp(8)(15 downto 1);
			ADC_Mem_Ave(9) <= b"0" & ADC_Mem_Temp(9)(15 downto 1);
			ADC_Mem_Ave(10) <= b"0" & ADC_Mem_Temp(10)(15 downto 1);
			ADC_Mem_Ave(11) <= b"0" & ADC_Mem_Temp(11)(15 downto 1);
			ADC_Mem_Ave(12) <= b"0" & ADC_Mem_Temp(12)(15 downto 1);
			ADC_Mem_Ave(13) <= b"0" & ADC_Mem_Temp(13)(15 downto 1);
			ADC_Mem_Ave(14) <= b"0" & ADC_Mem_Temp(14)(15 downto 1);
			ADC_Mem_Ave(15) <= b"0" & ADC_Mem_Temp(15)(15 downto 1);

	end if;
	end process;
	----End Registers
	
	
	
	----Process for crossing clock domains from SPI to clk to prevent metastablity
	ADC_Mem_Ave_Reg_Meta: process
	begin
		wait until clk'event and clk = '1';
		if (rst = '0' ) then
			ADC_Mem_Ave_M1(0) <= (others => '0');
			ADC_Mem_Ave_M1(1) <= (others => '0');
			ADC_Mem_Ave_M1(2) <= (others => '0');
			ADC_Mem_Ave_M1(3) <= (others => '0');
			ADC_Mem_Ave_M1(4) <= (others => '0');
			ADC_Mem_Ave_M1(5) <= (others => '0');
			ADC_Mem_Ave_M1(6) <= (others => '0');
			ADC_Mem_Ave_M1(7) <= (others => '0');
			ADC_Mem_Ave_M1(8) <= (others => '0');
			ADC_Mem_Ave_M1(9) <= (others => '0');
			ADC_Mem_Ave_M1(10) <= (others => '0');
			ADC_Mem_Ave_M1(11) <= (others => '0');
			ADC_Mem_Ave_M1(12) <= (others => '0');
			ADC_Mem_Ave_M1(13) <= (others => '0');
			ADC_Mem_Ave_M1(14) <= (others => '0');
			ADC_Mem_Ave_M1(15) <= (others => '0');
			ADC_Mem_Ave_M2(0) <= (others => '0');
			ADC_Mem_Ave_M2(1) <= (others => '0');
			ADC_Mem_Ave_M2(2) <= (others => '0');
			ADC_Mem_Ave_M2(3) <= (others => '0');
			ADC_Mem_Ave_M2(4) <= (others => '0');
			ADC_Mem_Ave_M2(5) <= (others => '0');
			ADC_Mem_Ave_M2(6) <= (others => '0');
			ADC_Mem_Ave_M2(7) <= (others => '0');
			ADC_Mem_Ave_M2(8) <= (others => '0');
			ADC_Mem_Ave_M2(9) <= (others => '0');
			ADC_Mem_Ave_M2(10) <= (others => '0');
			ADC_Mem_Ave_M2(11) <= (others => '0');
			ADC_Mem_Ave_M2(12) <= (others => '0');
			ADC_Mem_Ave_M2(13) <= (others => '0');
			ADC_Mem_Ave_M2(14) <= (others => '0');
			ADC_Mem_Ave_M2(15) <= (others => '0');
			
		else
			ADC_Mem_Ave_M1(0) <= ADC_Mem_Ave(0);
			ADC_Mem_Ave_M1(1) <= ADC_Mem_Ave(1);
			ADC_Mem_Ave_M1(2) <= ADC_Mem_Ave(2);
			ADC_Mem_Ave_M1(3) <= ADC_Mem_Ave(3);
			ADC_Mem_Ave_M1(4) <= ADC_Mem_Ave(4);
			ADC_Mem_Ave_M1(5) <= ADC_Mem_Ave(5);
			ADC_Mem_Ave_M1(6) <= ADC_Mem_Ave(6);
			ADC_Mem_Ave_M1(7) <= ADC_Mem_Ave(7);
			ADC_Mem_Ave_M1(8) <= ADC_Mem_Ave(8);
			ADC_Mem_Ave_M1(9) <= ADC_Mem_Ave(9);
			ADC_Mem_Ave_M1(10) <= ADC_Mem_Ave(10);
			ADC_Mem_Ave_M1(11) <= ADC_Mem_Ave(11);
			ADC_Mem_Ave_M1(12) <= ADC_Mem_Ave(12);
			ADC_Mem_Ave_M1(13) <= ADC_Mem_Ave(13);
			ADC_Mem_Ave_M1(14) <= ADC_Mem_Ave(14);
			ADC_Mem_Ave_M1(15) <= ADC_Mem_Ave(15);
			ADC_Mem_Ave_M2(0) <= ADC_Mem_Ave_M1(0);
			ADC_Mem_Ave_M2(1) <= ADC_Mem_Ave_M1(1);
			ADC_Mem_Ave_M2(2) <= ADC_Mem_Ave_M1(2);
			ADC_Mem_Ave_M2(3) <= ADC_Mem_Ave_M1(3);
			ADC_Mem_Ave_M2(4) <= ADC_Mem_Ave_M1(4);
			ADC_Mem_Ave_M2(5) <= ADC_Mem_Ave_M1(5);
			ADC_Mem_Ave_M2(6) <= ADC_Mem_Ave_M1(6);
			ADC_Mem_Ave_M2(7) <= ADC_Mem_Ave_M1(7);
			ADC_Mem_Ave_M2(8) <= ADC_Mem_Ave_M1(8);
			ADC_Mem_Ave_M2(9) <= ADC_Mem_Ave_M1(9);
			ADC_Mem_Ave_M2(10) <= ADC_Mem_Ave_M1(10);
			ADC_Mem_Ave_M2(11) <= ADC_Mem_Ave_M1(11);
			ADC_Mem_Ave_M2(12) <= ADC_Mem_Ave_M1(12);
			ADC_Mem_Ave_M2(13) <= ADC_Mem_Ave_M1(13);
			ADC_Mem_Ave_M2(14) <= ADC_Mem_Ave_M1(14);
			ADC_Mem_Ave_M2(15) <= ADC_Mem_Ave_M1(15);

	end if;
	end process;
	----End Registers

		
----Next State Logic for ADC Control Signals
 ADC_Ctrl: process(SPI_Dout1_Sync, SPI_Dout2_Sync, NS_ADC_Ctrl, CS_ADC_Ctrl, SPI_CNT_Out, Prg_Cnt_Out, Setup_CNT_Out, Ave_Cnt_Out,SPI_CNT_Loop_Out)
	begin
	
		---- Define Default States to prevent Latches
		SPI_ROM1_D_SEL 	<= '0';
		SPI_PS_rst			<= '1';
		SPI_PS_ld_D 		<= '0';
		SPI_PS_sh_D 		<= '0';
		SPI_Cnt_rst 		<= '1';
		SPI_Cnt_INC 		<= '0';
		Setup_Cnt_rst 		<= '1';
		Setup_Cnt_INC		<= '0';
		Prg_Cnt_rst 		<= '1';
		Prg_Cnt_INC 		<= '0';

		
		SPI_CSn 	<= '1';
		SPI_SP_rst	<= '1';
		SPI_SP_ld_D <= '0';
		
		--ADC_Mem
		ADC_wea 			<= '0';
		ADC_Ave_En 		<= '0';
		Ave_Cnt_rst 	<= '1';
		Ave_Cnt_INC		<= '0';
		ADC_Temp_rst	<= '1';
		ADC_Ave_Ld 		<= '0';
		
		--For Setup Loop
		SPI_CNT_Loop_rst	<= '1';
		SPI_CNT_Loop_INC	<= '0';
		


		
		case CS_ADC_Ctrl is
			when S0 =>
				SPI_Cnt_rst<='0';
				Setup_Cnt_rst<='0';
				Prg_Cnt_rst<='0';
				SPI_SP_rst<='0';
				SPI_PS_rst<='0';
				ADC_Temp_rst <= '0';
				Ave_Cnt_rst <= '0';
				SPI_CNT_Loop_rst <= '0';
				NS_ADC_Ctrl <= S1;
				
			--Delay for Alignment
			when S1 =>							--Wait for Delay's defined Cycles to align with PWM switching
				if(SPI_CNT_Out < Delay) then
					SPI_CNT_Inc<='1';
					NS_ADC_Ctrl <= S1;
				else
					SPI_CNT_rst<='0';
					NS_ADC_Ctrl<=S2;					
				end if;

				
			--Begin Dummy Load
			when S2 =>
				SPI_ROM1_D_SEL <='1';
				SPI_PS_ld_D <='1';
				SPI_Cnt_rst<='0';
				NS_ADC_Ctrl <=S3;
				
			when S3 =>
				SPI_ROM1_D_SEL <='1';
				SPI_PS_ld_D <='1';
				NS_ADC_Ctrl <= S4;
				
			when S4 =>
				NS_ADC_Ctrl <= S5;
				
			when S5 =>
				SPI_CSn <='0';
				if (SPI_CNT_Out < 15) then
					SPI_Cnt_INC <='1';
					NS_ADC_Ctrl <=S5;
				elsif (Setup_CNT_Out < 1) then
					Setup_CNT_INC <='1';
					SPI_ROM1_D_SEL <='1';
					NS_ADC_Ctrl <=S2;
				else
					SPI_CNT_rst<='0';
					NS_ADC_Ctrl <=S6;
						
				end if;
			--End Dummy Load

			
			----Begin ADC Loop
			
			--Delay for beginning of Loop
			when S6 =>							--Wait for 10 Cycles
				if(SPI_CNT_Out < 10) then
					SPI_CNT_Inc<='1';
					NS_ADC_Ctrl <= S6;
				else
					NS_ADC_Ctrl<=S7;					
				end if;	
			
			--Begin Write Command
			when S7 =>
				SPI_Cnt_rst<='0';
				SPI_SP_rst <='0';
				Prg_Cnt_rst <='0';
				SPI_PS_ld_D <='1';
				NS_ADC_Ctrl<= S8;
				
			when S8 =>
				SPI_PS_sh_D <='1';
				--SPI_SP_ld_D <='1';
				NS_ADC_Ctrl <= S9;
				
			when S9 =>
				SPI_PS_sh_D <='1';
				SPI_Cnt_INC <='1';
				SPI_CSn <='0';
				if (SPI_CNT_Out < 15) then
					NS_ADC_Ctrl <=S9;
				else
					NS_ADC_Ctrl <=S10;	
				end if;
			--End Write Command
			
			when S10 =>
				SPI_Cnt_rst<='0';
				SPI_SP_rst <='0';
				NS_ADC_Ctrl <=S11;
			
			--Begin Read Command
			when S11 =>
				NS_ADC_Ctrl <= S12;

			when S12 =>
				SPI_Cnt_INC <='1';
				SPI_CSn <='0';
				SPI_SP_ld_D <='1';
				if (SPI_CNT_Out < 15) then
					NS_ADC_Ctrl <=S12;
				else
					NS_ADC_Ctrl <=S13;	
				end if;
						
			when S13 =>
				SPI_Cnt_rst<='0';
				--ADC_wea<='1';
				NS_ADC_Ctrl <=S14;
				
			when S14 =>
				ADC_wea<='1';
				NS_ADC_Ctrl<=S15;
			
			when S15 =>							--Wait between Channel samples
				if(SPI_CNT_Out < Offset_Chan) then
					SPI_CNT_Inc<='1';
					NS_ADC_Ctrl <= S15;
				elsif(Prg_Cnt_Out < Chan) then	--Make sure all requested channels are read	
					Prg_Cnt_INC <='1';
					NS_ADC_Ctrl <=S10;
				else
					SPI_CNT_rst<='0';
					Prg_Cnt_rst<='0';
					Setup_Cnt_rst<='0';
					NS_ADC_Ctrl<=S16;					
				end if;
				
			when S16 =>					--Average sample data
				if (Ave_Cnt_Out < (Sample_Size-1)) then
					NS_ADC_Ctrl<=S18;
				else
					NS_ADC_Ctrl<=S17;
				end if;
				ADC_Ave_En <= '1';		--Enable Average
				Ave_Cnt_INC <= '1';		--Increment Counter
						
			when S17 =>						--Average sample data
				ADC_Ave_Ld 		<= '1';
				ADC_Temp_rst <= '0';		--Reset Temp Registers
				Ave_Cnt_rst <= '0';		--Reset Counter
				SPI_CNT_Inc<='1';			--Increment SPI_CNT for offset error
				NS_ADC_Ctrl<=S18;		
				
			when S18 =>					--Wait between Full Sample Set
				if(SPI_CNT_Out < Offset_Set) then
					SPI_CNT_Inc<='1';
					NS_ADC_Ctrl <= S18;
				else
					SPI_CNT_rst<='0';
					Prg_Cnt_rst<='0';
					if(SPI_CNT_Loop_Out < 1000) then	
						SPI_CNT_Loop_Inc <= '1';
						NS_ADC_Ctrl<=S10;
					else
						NS_ADC_Ctrl<=S0; 	-- After 1000 interations, resend Dummy and Setup Commands
					end if;
				end if;
				
			when others =>
				NS_ADC_Ctrl <=S0;
				
			end case;
	end process;
	----Next State Logic for ADC Control Signals
	
	
	
	
	
	
	----Next State Logic for Bus Interface
	NSL_Bus: process(CS_Bus_Ctrl,Bus_Cnt_Out,Bus_Int1_Busy,Mem_Addr_Cnt_Out,ADC_Mem_Ave_M2)
	begin
			
		----Default States to remove latches
		Bus_Int1_AddrIn <= (others => '0');
		Bus_Int1_RE <='0';
		Bus_Int1_DataIn <= (others => '0');
		Bus_Int1_WE <='0';
		Bus_Cnt_rst <='1';
		Bus_Cnt_INC <='0';
		Mem_Addr_Cnt_rst <='1';
		Mem_Addr_Cnt_INC <='0';

		
		case CS_Bus_Ctrl is
			when S0 =>							
					Bus_Cnt_rst <='0';		-- Reset Bus Counter
					Mem_Addr_Cnt_rst <='0';	-- Reset Address Counter
					NS_Bus_Ctrl <= S1;

			--Write Measurement Data to Bus
			when S1=>							--Wait (2^12-94) Clk Cycles for 1x per fs
					if(Bus_Cnt_Out < 4002) then 
						NS_Bus_Ctrl<=S1;
					else
						NS_Bus_Ctrl<=S2;
					end if;
					Bus_Cnt_INC<='1';
					
			when S2 =>							-- Wait until Bus Interface is availible
					if(Bus_Int1_Busy = '1') then
						NS_Bus_Ctrl<= S2;
					else
						NS_Bus_Ctrl<=S3;
					end if;
					
			when S3 =>							-- Write 15 Channels of ADC data to bus
				if(Mem_Addr_Cnt_Out < 15) then
					NS_Bus_Ctrl<=S2;
				else
					NS_Bus_Ctrl<=S0;
				end if;

				--ADC Map
				if(Mem_Addr_Cnt_Out = 0) then Bus_Int1_AddrIn <= Addr_ADC0; end if;		
				if(Mem_Addr_Cnt_Out = 1) then Bus_Int1_AddrIn <= Addr_ADC1; end if;		
				if(Mem_Addr_Cnt_Out = 2) then Bus_Int1_AddrIn <= Addr_ADC2; end if;		
				if(Mem_Addr_Cnt_Out = 3) then Bus_Int1_AddrIn <= Addr_ADC3; end if;		
				if(Mem_Addr_Cnt_Out = 4) then Bus_Int1_AddrIn <= Addr_ADC4;end if;		
				if(Mem_Addr_Cnt_Out = 5) then Bus_Int1_AddrIn <= Addr_ADC5;end if;		
				if(Mem_Addr_Cnt_Out = 6) then Bus_Int1_AddrIn <= Addr_ADC6; end if;		
				if(Mem_Addr_Cnt_Out = 7) then Bus_Int1_AddrIn <= Addr_ADC7; end if;		
				if(Mem_Addr_Cnt_Out = 8) then Bus_Int1_AddrIn <= Addr_ADC8; end if;		
				if(Mem_Addr_Cnt_Out = 9) then Bus_Int1_AddrIn <= Addr_ADC9; end if;		
				if(Mem_Addr_Cnt_Out = 10) then Bus_Int1_AddrIn <= Addr_ADC10; end if;	
				if(Mem_Addr_Cnt_Out = 11) then Bus_Int1_AddrIn <= Addr_ADC11; end if;	
				if(Mem_Addr_Cnt_Out = 12) then Bus_Int1_AddrIn <= Addr_ADC12; end if;	
				if(Mem_Addr_Cnt_Out = 13) then Bus_Int1_AddrIn <= Addr_ADC13; end if;	
				if(Mem_Addr_Cnt_Out = 14) then Bus_Int1_AddrIn <= Addr_ADC14; end if;	
				if(Mem_Addr_Cnt_Out = 15) then Bus_Int1_AddrIn <= Addr_ADC15; end if;	

				Bus_Int1_DataIn <= ADC_Mem_Ave_M2(conv_integer(Mem_Addr_Cnt_Out(3 downto 0)));	--Set data to write to Bus
				Mem_Addr_Cnt_INC <='1';
				Bus_Int1_WE <='1';
				
				
			

			when others => 
				NS_Bus_Ctrl<=S0;
				
		end case;
	end process;
	----End Next State Logic for Bus Interface
	



	-- Sync Process for FSMs
	sync_ADC: process
	begin
		wait until clk_SPI'event and clk_SPI = '1';
		if rst = '0' then
			CS_ADC_Ctrl <= S0;
		else
			CS_ADC_Ctrl <= NS_ADC_Ctrl;
		end if;
	end process;
	
	-- Sync Process for FSMs
	sync_Bus: process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			CS_Bus_Ctrl <= S0;
		else
			CS_Bus_Ctrl <= NS_Bus_Ctrl;
		end if;
	end process;
	
	
	
	
	-- Synchro for Dout signals
	sync_SPI: process
	begin
		wait until clk_SPI'event and clk_SPI = '0';
		if rst = '0' then
			SPI_Dout1_Sync<='0';
		else
			SPI_Dout1_Sync<=SPI_Dout;
		end if;
	end process;
	
	
	
	
	-- Clock Divider for SPI_Sclk 
	Clk_Div_Top: process
	begin
		wait until clk'event and clk = '1';
			clk_temp2 <= clk_temp2+1;
			--clk_SPI <= clk_temp2(3);
			clk_SPI <= clk_temp2(2);
			--clk_SPI <= not(clk_SPI);
	end process;

end Behavioral;