----------------------------------------------------------------------------------
-- Company:  University of Arkansas (NCREPT)
-- Engineer: Chris Farnell
-- 
-- Create Date:			9Jun2019
-- Design Name: 		Bus_Master
-- Module Name: 		Bus_Master_Behavioral
-- Project Name: 		Bus Interface Example
-- Target Devices: 		LCMXO2-7000HC-4FG484C (UCB v1.3a)
-- Tool versions: 		Lattice Diamond_x64 Build 3.10.2.115.1
--
-- Description: 
-- This module establishes and manages the common bus of the design.
-- It includes a Single Port RAM module which is 16bits wide and has a depth of 1024 addresses.
-- Each of these addresses is Read/Write capable.
-- A priority encoder is used in case multiple clients request access at the same time.
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



Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.Bus_Interface_Common.all;

entity Bus_Master is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           Data : inout  STD_LOGIC_VECTOR (15 downto 0);
           Addr : in  STD_LOGIC_VECTOR (15 downto 0);
           Xrqst : in  STD_LOGIC;
           XDat : out  STD_LOGIC;
           YDat : in  STD_LOGIC;
           BusRqst : in  STD_LOGIC_VECTOR (9 downto 0);
           BusCtrl : out  STD_LOGIC_VECTOR (9 downto 0));
end Bus_Master;


architecture Behavioral of Bus_Master is
	type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11);
 	signal CS, NS: state_type;
	
	--Signals for Mem1
	signal Mem1_wea: STD_LOGIC:='0';
	signal Mem1_rst: STD_LOGIC:='0';
	signal Mem1_addra: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal Mem1_dina, Mem1_douta, Mem1_doutb: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal clk_en: STD_LOGIC:='1'; 		
				
	
	--Signals for Registers
	signal LD_Addr, LD_Data, LD_BusCtrl: Std_Logic:= '0'; 
	signal BusCtrl_Temp : STD_LOGIC_VECTOR(9 downto 0):= (others => '0');


    --declare SPRAM
    COMPONENT SPRAM
	PORT(
		Clock: in  std_logic; 
		ClockEn: in  std_logic; 
		Reset: in  std_logic; 
		WE: in  std_logic; 
		Address: in  std_logic_vector(9 downto 0); 
		Data: in  std_logic_vector(15 downto 0); 
		Q: out  std_logic_vector(15 downto 0)
		);
    END COMPONENT;

begin

	--Instantiate SPRAM_16bx1024
	 Mem1: SPRAM	Port Map( 
		Clock => clk,
		ClockEn => clk_en,
		Reset => Mem1_rst,
		WE => Mem1_wea,
		Address => Mem1_addra(9 downto 0),
		Data => Mem1_dina,
		Q => Mem1_douta
		);
		
	--COMPONENT DPRAM is
    --PORT (
        --DataInA: in  std_logic_vector(15 downto 0); 
        --DataInB: in  std_logic_vector(15 downto 0); 
        --AddressA: in  std_logic_vector(13 downto 0); 
        --AddressB: in  std_logic_vector(13 downto 0); 
        --ClockA: in  std_logic; 
        --ClockB: in  std_logic; 
        --ClockEnA: in  std_logic; 
        --ClockEnB: in  std_logic; 
        --WrA: in  std_logic; 
        --WrB: in  std_logic; 
        --ResetA: in  std_logic; 
        --ResetB: in  std_logic; 
        --QA: out  std_logic_vector(15 downto 0); 
        --QB: out  std_logic_vector(15 downto 0));
	--END COMPONENT;

--begin

	----Instantiate DPRAM_16bx12288
	 --Mem1: DPRAM	Port Map( 
		--DataInA => Mem1_dina,
		--DataInB => (others => '0'),
		--AddressA => Mem1_addra(13 downto 0),
		--AddressB => (others => '0'),
		--ClockA => clk,
		--ClockB => clk,
		--ClockEnA => clk_en,
		--ClockEnB => '0',
		--WrA => Mem1_wea,
		--WrB => '0',
		--ResetA => Mem1_rst,
		--ResetB => '1',
		--QA => Mem1_douta,
		--QB => Mem1_doutb
		--);
		

		
	----Registers	
	Reg_Proc: process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			Mem1_addra <= (others => '0');
			Mem1_dina <= (others => '0');
			BusCtrl <= (others => '0');

		else
			if (LD_Addr = '1') then Mem1_addra <= Addr; end if;				--Register for reading input address
			if (LD_Data = '1') then Mem1_dina <= Data; end if;					--Register for writing input data
			if (LD_BusCtrl = '1') then BusCtrl <=BusCtrl_Temp; end if;	
	end if;
	end process;
	----End Registers



	----Next State Logic Bus Control
	NS_Bus_Ctrl: process(CS,BusRqst,XRqst,YDat,Mem1_douta)
	begin
			
		----Default States to remove latches
		Data <=(others => 'Z');
		XDat <='0';
		BusCtrl_Temp <=(others => '0');
		LD_BusCtrl <='0';
		NS <= S0;
		Mem1_wea <='0';
		LD_Addr <= '0';
		LD_Data <='0';
		clk_en <= '1';

	
		case CS is
			when S0 =>							-- Waits until a request is made.
				if (BusRqst > 0) then
					NS <= S1;
				else
					NS <= S0;
				end if;	
				
			when S1=>							-- Grant Control of the Bus (Priority Encoder)
				if(BusRqst(0) = '1') then
					BusCtrl_Temp(0) <= '1';
				elsif(BusRqst(1) = '1') then
					BusCtrl_Temp(1) <= '1';
				elsif(BusRqst(2) = '1') then
					BusCtrl_Temp(2) <= '1';
				elsif(BusRqst(3) = '1') then
					BusCtrl_Temp(3) <= '1';
				elsif(BusRqst(4) = '1') then
					BusCtrl_Temp(4) <= '1';
				elsif(BusRqst(5) = '1') then
					BusCtrl_Temp(5) <= '1';
				elsif(BusRqst(6) = '1') then
					BusCtrl_Temp(6) <= '1';
				elsif(BusRqst(7) = '1') then
					BusCtrl_Temp(7) <= '1';
				elsif(BusRqst(8) = '1') then
					BusCtrl_Temp(8) <= '1';
				elsif(BusRqst(9) = '1') then
					BusCtrl_Temp(9) <= '1';
				end if;
				LD_BusCtrl <='1';
				NS <= S2;
					
			when S2 =>							-- Bus Control granted. Wait until Read or Write Request.
					if (XRqst = '1') then	--Active High--Active Low because of pull-ups for internal tristate
						NS<= S3;

					elsif (YDat = '1') then	--Active High--Active Low because of pull-ups for internal tristate
						NS<= S5;
					else
						NS<= S2;
					end if;
					LD_Addr <= '1';
					LD_Data <= '1';
					
			when S3=>							--(Read Operation) Send Data
					NS <= S4;

			when S4=>							--(Read Operation) Send Data
					data<=Mem1_douta;
					Xdat <='1';					--Active High
					NS <= S6;
					
			when S5 =>							--(Write Operation) Receive Data
					Mem1_wea <='1';
					NS <= S6;
					
			when S6 =>
					LD_BusCtrl <='1';
					NS <= S0;


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
			Mem1_rst<='1';	--reset Memory
			CS <= S0;
		else
			Mem1_rst<='0';
			CS <= NS;
		end if;
	end process;
	----End State Sync


end Behavioral;