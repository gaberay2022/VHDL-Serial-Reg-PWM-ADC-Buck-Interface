----------------------------------------------------------------------------------
-- Company:  University of Arkansas (NCREPT)
-- Engineer: Chris Farnell
-- 
-- Create Date:			9Jun2019
-- Design Name: 		Generic Components
-- Module Name: 		Various
-- Project Name: 		Bus Interface Example
-- Target Devices: 		LCMXO2-7000HC-4FG484C (UCB v1.3a)
-- Tool versions: 		Lattice Diamond_x64 Build 3.10.2.115.1
--
-- Description: 
-- This is a general repository for multiple common generic components which are reused.
--
--
-- Revisions:--
--
-- Revision 1.1b - 
-- Minor Comment Updates
--
-- Revision 0.01 - 
-- File Created; Basic\Classical Operation Implemented
--
--
-- Additional Comments: 
-- 
--
----------------------------------------------------------------------------------





--#############################Generic Components################################################--

------------------------------Bus Interface--------------------------------------------------
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.Bus_Interface_Common.all;

entity Bus_Int is
	Generic (
		constant DATA_WIDTH : integer := 16;
		constant Address_WIDTH : integer := 16
	);
	port(clk: in std_logic;
		rst: in std_logic;
		DataIn: in std_logic_vector(DATA_WIDTH-1 downto 0);
		DataOut: out std_logic_vector(DATA_WIDTH-1 downto 0);
		AddrIn: in std_logic_vector(Address_WIDTH-1 downto 0);
		WE: in std_logic;
		RE: in std_logic;
		Busy: out std_logic;
		Data: inout std_logic_vector(DATA_WIDTH-1 downto 0);
		Addr: out std_logic_vector(Address_WIDTH-1 downto 0);
		Xrqst: out std_logic;
		XDat: in std_logic;
		YDat: out std_logic;
		BusRqst: out std_logic;
		BusCtrl: in std_logic
		);
end;

architecture behavior of Bus_Int is
	type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10);
 	signal CS, NS: state_type;
	signal AddrIn_reg_o: std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');
	signal DataIn_reg_o: std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');
	signal LD_AddrIn, LD_DataIn, LD_Data: std_logic:='0';

begin


	----Registers	
	Reg_Proc: process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			AddrIn_reg_o <= (others => '0');
			DataIn_reg_o <= (others => '0');
			DataOut <= (others => '0');
		else
			if (LD_AddrIn = '1') then AddrIn_reg_o <= AddrIn; end if;		--Register for reading input address
			if (LD_DataIn = '1') then DataIn_reg_o <= DataIn; end if;		--Register for reading input address
			if (LD_Data = '1') then DataOut <= Data; end if;					--Register for reading input address
	end if;
	end process;
	----End Registers



	----Next State Logic Bus Interface
	NS_Bus_Int: process(CS,WE,RE,XDat,BusCtrl,AddrIn_reg_o,DataIn_reg_o)
	begin
	
	

			
		----Default States to remove latches
		Busy <='1';
		Data <=(others => 'Z');
		Addr <=(others => 'Z');
		XRqst <='Z';
		YDat <='Z';
		BusRqst <='0';
		NS <= S0;
		LD_AddrIn <='0';
		LD_DataIn <='0';
		LD_Data <='0';
	
		case CS is
			when S0 =>							-- Waits until a read or write request is initiated.
				if (RE = '1') then
					NS <= S1;
				elsif (WE ='1') then
					NS <= S3;
				else
					NS<=S0;
				end if;
				Busy <='0';
				LD_AddrIn <='1';			-- Loads the Input Address
				LD_DataIn <='1';			-- Loads the Input Data
				
				
			--Begin Read Process
			when S1=>							-- Request Control of the Bus and wait.
					if (BusCtrl = '1') then
						NS<=S2;
					else
						NS<=S1;
					end if;
					BusRqst <='1';		
					
			when S2 =>							-- Bus Control granted. Request data.
					if (Xdat ='0') then		--Active High
						NS<= S2;
					else
						NS<= S0;
					end if;
					Addr <= AddrIn_reg_o;
					XRqst <='1';				--Active High--Active Low because of pull-ups for internal tristate
					LD_Data <='1';
			--End Read Process		
			
			--Begin Write Process
			when S3=>							-- Request Control of the Bus and wait.
					if (BusCtrl = '1') then
						NS<=S4;
					else
						NS<=S3;
					end if;
					BusRqst <='1';		
					
			when S4 =>							-- Bus Control granted. Write data.
					Addr <= AddrIn_reg_o;
					Data<=DataIn_reg_o;
					YDat <='1';					--Active High--Active Low because of pull-ups for internal tristate
					NS <=S0;
			--End Write Process		

			when others => 
				NS<=S0;
				
		end case;
	end process;
	----End Next State Logic for Bus Interface


	----State Sync
	sync_States: process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			CS <= S0;
		else
			CS <= NS;
		end if;
	end process;
	----End State Sync


end behavior;
----------------------------------End Bus Interface------------------------------------



------------------------------Generic FIFO--------------------------------------------------



Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity STD_FIFO is
	Generic (
		DATA_WIDTH 		: integer := 8;		-- Width of FIFO
		FIFO_DEPTH 		: integer := 512;	--	Depth of FIFO
		FIFO_ADDR_LEN  : integer := 9		-- Required number of bits to represent FIFO_Depth
	);
	Port ( 
		CLK     : in  STD_LOGIC;                                       -- Clock input
		RST     : in  STD_LOGIC;                                       -- Active low reset
		WriteEn : in  STD_LOGIC;                                       -- Write enable signal
		DataIn  : in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);      -- Data input bus
		ReadEn  : in  STD_LOGIC;                                       -- Read enable signal
		DataOut : out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);      -- Data output bus
		Empty   : out STD_LOGIC;                                       -- FIFO empty flag
		Full    : out STD_LOGIC                                        -- FIFO full flag
	);
end STD_FIFO;

architecture Behavioral of STD_FIFO is

		type FIFO_Memory is array (0 to FIFO_DEPTH - 1) of STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		signal Memory : FIFO_Memory;
		signal Head : STD_LOGIC_VECTOR (FIFO_ADDR_LEN-1 downto 0);
		signal Tail : STD_LOGIC_VECTOR (FIFO_ADDR_LEN-1 downto 0);
		signal Looped : boolean;
begin

	-- Memory Pointer Process
	fifo_proc : process (CLK)
		

	begin
		if rising_edge(CLK) then
			if RST = '0' then
				Head <= (others => '0');
				Tail <= (others => '0');
				Looped <= false;
				Full  <= '0';
				Empty <= '1';
			else
				if (ReadEn = '1') then
					if ((Looped = true) or (Head /= Tail)) then
						-- Update data output
						DataOut <= Memory(CONV_INTEGER(Tail));
						
						-- Update Tail pointer as needed
						if (Tail = FIFO_DEPTH - 1) then
							Tail <= (others => '0');
							
							Looped <= false;
						else
							Tail <= Tail + 1;
						end if;
					end if;
				end if;
				
				if (WriteEn = '1') then
					if ((Looped = false) or (Head /= Tail)) then
						-- Write Data to Memory
						Memory(CONV_INTEGER(Head)) <= DataIn;
						-- Increment Head pointer as needed
						if (Head = FIFO_DEPTH - 1) then
							Head <= (others => '0');
							Looped <= true;
						else
							Head <= Head + 1;
						end if;
					end if;
				end if;
				
				-- Update Empty and Full flags
				if (Head = Tail) then
					if Looped then
						Full <= '1';
					else
						Empty <= '1';
					end if;
				else
					Empty	<= '0';
					Full	<= '0';
				end if;
			end if;
		end if;
	end process;
		
end Behavioral;

------------------------------End Generic FIFO--------------------------------------------------

------------------------16-Bit PWM with Phase shift-------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;


entity PWM_16b is
	generic( Freq_in:integer:=25000000;		--Clk (25 MHz)
				Max_PWM:integer:=65535;			--PWM Resolution (2^16-1)
				Freq_Sw:integer:=6104);			--PWM Switching Frequency	(Should be derived from Main Clock) (25e6/2^12)
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           DC : in  STD_LOGIC_VECTOR (15 downto 0);
           Phase : in  STD_LOGIC_VECTOR (15 downto 0);
           En : in  STD_LOGIC;
           PWM_Out : out  STD_LOGIC);
end PWM_16b;

architecture Behavioral of PWM_16b is

	--Constants
	constant Max_Period:	integer:=(Freq_in/Freq_Sw)-1;
	constant PWM_Step_Inv: integer:=Max_PWM/Max_Period;		--Clk cycle step size for Duty cycle
	constant PWM_Max:integer:=Max_PWM;	
	constant PWM_Min:integer:=PWM_Step_Inv;
	
	--Signals
	signal PWM_Count, DC_Read, Phase_Read: STD_LOGIC_VECTOR(15 DOWNTO 0):= (others => '0');
	
	begin
	
		
	DC_Update: process
	begin
	
		wait until clk'event and clk = '1';
		if rst='0' then
			DC_Read<=(others => '0');
			Phase_Read<=(others => '0');
		else


--			-- For 1.526 kHz
--			DC_Read(15 downto 14)<=(others => '0');
--			DC_Read(13 downto 0)<= DC(15 downto 2); 			--shift 2 places for divide by 4 (PWM_Step_Inv)
--			Phase_Read(15 downto 14)<=(others => '0');
--			Phase_Read(13 downto 0)<= Phase(15 downto 2); 	--shift 2 places for divide by 4 (PWM_Step_Inv)

			-- For 3.052 kHz
--			DC_Read(15 downto 13)<=(others => '0');
--			DC_Read(12 downto 0)<= DC(15 downto 3); 			--shift 3 places for divide by 8
--			Phase_Read(15 downto 13)<=(others => '0');
--			Phase_Read(12 downto 0)<= Phase(15 downto 3); 	--shift 3 places for divide by 8

			-- For 6.104 kHz
			DC_Read(15 downto 12)<=(others => '0');
			DC_Read(11 downto 0)<= DC(15 downto 4); 			--shift 4 places for divide by 16 (PWM_Step_Inv)
			Phase_Read(15 downto 12)<=(others => '0');
			Phase_Read(11 downto 0)<= Phase(15 downto 4); 	--shift 4 places for divide by 16 (PWM_Step_Inv)
			
		end if;
	end process;
		
	Count_Update: process
	begin
		wait until clk'event and clk = '1';
		if rst='0' then
			PWM_Count<=(others => '0');
			
		elsif (PWM_Count <= (Max_Period+Phase_Read)) then
			PWM_Count <= PWM_Count+1;
		
		else
			PWM_Count<=Phase_Read;

		end if;
	end process;
		
	
	PWM_Update: process
	begin
			wait until clk'event and clk = '1';
			if rst = '0' then
				PWM_Out<='0';
				
			elsif en = '0' then
				PWM_Out<='0';
			
			elsif ((PWM_Count <= (DC_Read + Phase_Read)) and ((PWM_Count) > (Phase_Read))) then
				PWM_Out <='1';
						
			else
				PWM_Out <='0';

			end if;
		end process;


end Behavioral;

-----------------------------End 16-Bit PWM with Phase shift------------------------------


----------------------------------16-Bit Shift Register(Parallel-to-Serial)--------------
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity Sreg_PS_16 is
	port(ld_D,sh_D,rst,clk: in std_logic;
		Data_In: in STD_LOGIC_VECTOR(15 downto 0);
		Data_Out: out std_logic);
end;

architecture BEHAVIOR of Sreg_PS_16 is
signal temp: STD_LOGIC_VECTOR(15 downto 0);
	
begin

--Data_Out <= temp(15);

	Counter_behav: process
	begin

		wait until clk'event and clk = '1';
		if rst='0' then
			temp <= (Others =>'0');
			Data_Out <= '0';
		elsif ld_D = '1' then
			temp <= Data_In;
			Data_Out <= temp(15);
		elsif sh_D = '1' then
			temp <= temp(14 downto 0) & '0';
			Data_Out <= temp(15);
		else
			Data_Out <= temp(15);
		end if;
		

	end process;
end BEHAVIOR;

----------------------------------End of 16-Bit Shift Register(Parallel-to-Serial)------------------



----------------------------------16-Bit Shift Register(Serial-to-Parallel)--------------
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity Sreg_SP_16 is
	port(ld_D,rst,clk: in std_logic;
		Data_In: in std_logic;
		Data_Out: out STD_LOGIC_VECTOR(15 downto 0));
end;

architecture BEHAVIOR of Sreg_SP_16 is
signal temp: STD_LOGIC_VECTOR(15 downto 0);
begin
	Counter_behav: process
	begin
		wait until clk'event and clk = '1';
		if rst='0' then
			temp <= (Others =>'0');
			Data_Out <= (Others =>'0');
		elsif ld_D = '1' then
			temp <= temp(14 downto 0) & Data_In;
			--temp(0) <= Data_In;
			Data_Out <= temp;
		else
			Data_Out <= temp;
		end if;
		
	end process;
end BEHAVIOR;

----------------------------------End of 16-Bit Shift Register(Parallel-to-Serial)------------------



---------------------------------- Standard Counter------------------------------------
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity Std_Counter is
	generic 
	(
		Width : integer := 8		--width of counter
	);
	port(INC,rst,clk: in std_logic;
		 Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
end;

architecture BEHAVIOR of Std_Counter is
signal temp: STD_LOGIC_VECTOR(Width-1 downto 0);
begin
	Counter_behav: process
	begin
		wait until clk'event and clk = '1';
		if rst='0' then
			temp<=(Others =>'0');
		elsif INC = '1' then
				temp<=temp+1;
				else
			null;
		end if;
		
	end process;
	Count<=temp;
end BEHAVIOR;

----------------------------------End of Standard Counter----------------------------------


--#############################End Generic Components################################################--



