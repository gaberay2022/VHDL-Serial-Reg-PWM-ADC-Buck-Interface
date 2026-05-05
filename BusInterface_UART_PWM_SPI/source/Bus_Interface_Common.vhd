----------------------------------------------------------------------------------
-- Company:  University of Arkansas (NCREPT)
-- Engineer: Chris Farnell
-- 
-- Create Date:			9Jun2019
-- Design Name: 		Bus_Interface_Common
-- Module Name: 		Bus_Interface_Common
-- Project Name: 		Bus Interface Example
-- Target Devices: 		LCMXO2-7000HC-4FG484C (UCB v1.3a)
-- Tool versions: 		Lattice Diamond_x64 Build 3.10.2.115.1
--
-- Description: 
-- This Package was created to allow for Memory Mapping as well as the declaration of various needed constants.
--
---- Register and Memory Map Information:
-- This section describes the Memory Map used in this project.
-- This design contains a SPRAM Module which is 16 bits wide and 1024 entries deep.
-- Register addresses are from X"0000" to X"03FF".
-- All registers are 16-bits wide.
-- The SPRAM Module is located in the Bus_Master portion of the code.
-- This RAM Module may be accessed externally using either Serial Port interface.
-- Reserved for future use.
-- X"0300" - X"03FF"
--
-- LED Configuration Values-
-- Range is X"0100" - X"010A"
--
-- SPI ADC Measurement Values-
-- Range is X"0200" - X"020A"
--
-- Register Map is found as constants in Bus_Interface_Common and shared with all submodules of this program.

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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;




package Bus_Interface_Common is

	----Common Constants
	constant Second : STD_LOGIC_VECTOR(31 downto 0):=X"017C66D0";
	constant Clk_Freq : integer := 24930000;
	--constant Clk_Freq : integer :=25000000;
	----End Constants



	------Register Map

	--System Registers
	--End System Registers

	--LED Registers
	constant Addr_LED_En: STD_LOGIC_VECTOR(15 downto 0):= X"0100";		--Enable LED Outputs (LSB)
	constant Addr_LED_PRD: STD_LOGIC_VECTOR(15 downto 0):= X"0101";		--LED PWM Period
	constant Addr_LED_PW: STD_LOGIC_VECTOR(15 downto 0):= X"0102";		--LED Pulse Width (On-Time)
	constant Addr_LED1_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0103";		--LED1 PWM Duty Cycle
	constant Addr_LED2_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0104";		--LED2 PWM Duty Cycle
	constant Addr_LED3_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0105";		--LED3 PWM Duty Cycle
	constant Addr_LED4_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0106";		--LED4 PWM Duty Cycle
	constant Addr_LED5_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0107";		--LED5 PWM Duty Cycle
	constant Addr_LED6_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0108";		--LED6 PWM Duty Cycle
	constant Addr_LED7_DC: STD_LOGIC_VECTOR(15 downto 0):= X"0109";		--LED7 PWM Duty Cycle
	constant Addr_LED8_DC: STD_LOGIC_VECTOR(15 downto 0):= X"010A";		--LED8 PWM Duty Cycle
	--End LED Registers
	
	--SPI ADC Registers
	constant Addr_ADC0: STD_LOGIC_VECTOR(15 downto 0):= X"0200";			--ADC0 Value
	constant Addr_ADC1: STD_LOGIC_VECTOR(15 downto 0):= X"0201";			--ADC1 Value
	constant Addr_ADC2: STD_LOGIC_VECTOR(15 downto 0):= X"0202";			--ADC2 Value
	constant Addr_ADC3: STD_LOGIC_VECTOR(15 downto 0):= X"0203";			--ADC3 Value
	constant Addr_ADC4: STD_LOGIC_VECTOR(15 downto 0):= X"0204";			--ADC4 Value
	constant Addr_ADC5: STD_LOGIC_VECTOR(15 downto 0):= X"0205";			--ADC5 Value
	constant Addr_ADC6: STD_LOGIC_VECTOR(15 downto 0):= X"0206";			--ADC6 Value
	constant Addr_ADC7: STD_LOGIC_VECTOR(15 downto 0):= X"0207";			--ADC7 Value
	constant Addr_ADC8: STD_LOGIC_VECTOR(15 downto 0):= X"0208";			--ADC8 Value
	constant Addr_ADC9: STD_LOGIC_VECTOR(15 downto 0):= X"0209";			--ADC9 Value
	constant Addr_ADC10: STD_LOGIC_VECTOR(15 downto 0):= X"020A";			--ADC10 Value
	constant Addr_ADC11: STD_LOGIC_VECTOR(15 downto 0):= X"020B";			--ADC11 Value
	constant Addr_ADC12: STD_LOGIC_VECTOR(15 downto 0):= X"020C";			--ADC12 Value
	constant Addr_ADC13: STD_LOGIC_VECTOR(15 downto 0):= X"020D";			--ADC13 Value
	constant Addr_ADC14: STD_LOGIC_VECTOR(15 downto 0):= X"020E";			--ADC14 Value
	constant Addr_ADC15: STD_LOGIC_VECTOR(15 downto 0):= X"020F";			--ADC15 Value
	--End SPI ADC Registers
	
	--Buck Control Registers
	constant Addr_Buck_SP: STD_LOGIC_VECTOR (15 downto 0) := X"0103"; 		--Set point for buck converter
	constant Addr_Buck_DC: STD_LOGIC_VECTOR (15 downto 0) := X"0301";      -- Calculate Duty Cycle
	--END Buck control Registers
	
	------End Register Map



	
 end Bus_Interface_Common;


package body Bus_Interface_Common is



end Bus_Interface_Common;