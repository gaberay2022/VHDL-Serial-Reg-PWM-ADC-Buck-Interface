Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library machxo3d;
use machxo3d.all;

library work;
use work.Bus_Interface_Common.all;

entity Bus_Interface_Top is 
	Port (
					---- RS232 Communications
					SCI_RX : in STD_LOGIC;   --- serial In for user control
					SCI_TX : inout STD_LOGIC;  ---serial out for user control 
					--- Board LEDs
					LED_1	:	out STD_LOGIC;
					LED_2	:	out STD_LOGIC;
					LED_3	:	out STD_LOGIC;
					LED_4	:	out STD_LOGIC;
					LED_5	:	out STD_LOGIC;
					LED_6	:	out STD_LOGIC;
					LED_7	:	out STD_LOGIC;
					LED_8	:	out STD_LOGIC;
					PWM_Test_Out	:	out	STD_LOGIC;
					ADC_SCLK : INOut std_logic;
					ADC_DIN : inout std_logic;
					ADC_CSn : out std_logic;
					ADC_DOUT : IN std_logic;
					DSP_G1 : out std_logic;
					DSP_G2 : out std_logic
					);
end Bus_Interface_Top;

architecture Behavioral of Bus_Interface_Top is

					--- Declare Internal Oscillator
					COMPONENT OSCJ
					GENERIC (NOM_FREQ: string := "8.31");
					PORT ( STDBY : IN std_logic;
							OSC : OUT std_logic;
							SEDSTDBY : OUT std_logic
							);
					END COMPONENT;
					
					--Declare PLL
					COMPONENT PLL_Clk
					PORT (
							ClkI: in std_logic;
							ClkOP: out std_logic;
							Lock: out std_logic
							);
					END COMPONENT;
					
					
					--Declare Bus_Master
					COMPONENT Bus_Master
					PORT (
								clk	:	IN	std_logic;
								rst	:	IN	std_logic;
								Data	:	INOUT	std_logic_vector (15 downto 0);
								Addr	:	IN	std_logic_vector (15 downto 0);
								Xrqst	:	IN	std_logic;
								XDat	:	OUT	std_logic;
								YDat	:	IN	std_logic;
								BusRqst	:	IN	std_logic_vector (9 downto 0);
								BusCtrl	:	OUT	std_logic_vector (9 downto 0)
							);
					END COMPONENT;
					
					
					-- DECLARE RS232_Usr_Int
					COMPONENT RS232_Usr_Int
						Generic (
						Baud	:	integer; ---baud rate
						clk_in	:	integer --- input Clk
						);
					PORT (
						clk	: IN std_logic;
						rst	: IN std_logic;
						rs232_rcv	:	IN std_logic;
						rs232_xmt	:	OUT std_logic;
						Data	:	INOUT	std_logic_vector (15 downto 0);
						Addr	:	OUT std_logic_vector (15 downto 0);
						Xrqst	:	OUT	std_logic;
						XDat	:	IN	std_logic;
						YDat	:	OUT std_logic;
						BusRqst	:	OUT std_logic;
						BusCtrl	:	IN std_logic
						);
				End Component;
				
				---Declare LED_Ctrl
				component LED_Ctrl
				port (
							clk : in std_logic;
							rst : in std_logic;
							Data : inout std_logic_vector (15 downto 0);
							Addr : out std_logic_vector (15 downto 0);
							Xrqst : out std_logic;
							XDat : in std_logic;
							YDat : out std_logic;
							BusRqst : out std_logic;
							BusCtrl : in std_logic;
							LED_En : out std_logic; 
							LED1_Out : out std_logic;
							LED2_Out : out std_logic;
							LED3_Out : out std_logic;
							LED4_Out : out std_logic;
							LED5_Out : out std_logic;
							LED6_Out : out std_logic;
							LED7_Out : out std_logic;
							LED8_Out : out std_logic
						);
				End component;
				
				--Declare ADC_Int
				Component ADC_Int is
				port (
							clk : in std_logic;
							rst : in std_logic;
							Data : inout std_logic_vector(15 downto 0);
							Addr : out std_logic_vector(15 downto 0);
							Xrqst : out std_logic;
							XDat : in std_logic;
							YDat : out std_logic;
							BusRqst : out std_logic;
							BusCtrl : in std_logic;
							SPI_Sclk: inout std_logic;
							SPI_Din : inout std_logic;
							SPI_CSn : out std_logic;
							SPI_Dout : in std_logic
							);
				END Component;
				 
			    Component PI_Buck is
				port ( clk : in std_logic;
						  rst : in std_logic;
						  Data : inout std_logic_vector (15 downto 0);
						  Addr : out std_logic_vector (15 downto 0);
						  Xrqst : out std_logic;
						  XDat : in std_logic;
						  YDat : out std_logic;
						  BusRqst : out std_logic;
						  BusCtrl : in std_logic
						  );
				end component; 
			
				--Declare std_counter component
				component Std_Counter
				generic
				(
						Width : integer ---width of counter
				);
				port (INC, rst, clk: in std_logic;
						Count: out STD_LOGIC_VECTOR (Width-1 downto 0));
				end component;
				
				--signals
				-- declare signals for bus inteface
				signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy: STD_LOGIC:= '0';
				signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn: STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
				
				--inputs
				signal Addr : std_logic_vector (15 downto 0) := (others => '0');
				signal Xrqst : std_logic := '0';
				signal YDat : std_logic := '0';
				signal BusRqst : std_logic_vector (9 downto 0) := (others => '0');
				signal Data : std_logic_vector (15 downto 0) := (others =>'0');
				signal Xdat : std_logic := '0';
				signal BusCtrl : std_logic_vector (9 downto 0) := (others => '0');
				
				--internal clock
				signal OSC_Stdby, OSC_Out, OSC_SEDSTDBY, clk: std_logic := '0';
				
				--reset
				signal PLL_Lock, System_rst: std_logic := '0';
				signal Reset_Cnt_INC, Reset_Cnt_rst: std_logic := '0';
				signal Reset_Cnt_Out: std_logic_vector (7 downto 0) := (others => '0');
				
				--- Misc
				signal LED_En : std_logic := '0';
				-- for inverting LED Outputs (active low)
				signal LED_1n, LED_2n, LED_3n, LED_4n, LED_5n, LED_6n, LED_7n, LED_8n: std_logic := '0';	
				
		begin
				
				--instantiate internal oscillator
				Int_OSC: OSCJ PORT MAP(
										STDBY => OSC_Stdby,
										OSC => OSC_Out,
										SEDSTDBY => OSC_SEDSTDBY
								);
				
				--instantiate PLL
				PLL_1:	PLL_Clk PORT MAP(
										CLKI => OSC_Out,
										ClkOP => clk,
										Lock => Pll_Lock
								);
								
				-- Instantiate Bus_Master
				BM:	Bus_Master PORT MAP (
										clk => clk,
										rst => System_rst,
										Data => Data,
										Addr => Addr,
										Xrqst => Xrqst,
										XDat => XDat,
										YDat => YDat,
										BusRqst => BusRqst,
										BusCtrl => BusCtrl
								);
								
				--Instantiate RS232_Usr_Int
				RS232_Usr: RS232_Usr_Int
				Generic Map
				(
						Baud		=>		9600,
						Clk_In		=>		Clk_Freq
				)
				PORT MAP (
							clk => clk,
							rst => System_rst,
							rs232_rcv => SCI_RX,
							rs232_xmt => SCI_TX,
							Data => Data,
							Addr => Addr,
							Xrqst => Xrqst,
							XDat => XDat,
							YDat => YDat,
							BusRqst => BusRqst (3),
							BusCtrl => BusCtrl (3)
				);
				
				---Instantiate LED_Ctrl
				LED_Ctrll: LED_Ctrl port map (
							clk => clk,
							rst => System_rst,
							Data => Data,
							Addr => Addr,
							Xrqst => Xrqst,
							XDat => XDat,
							YDat => YDat,
							BusRqst => BusRqst(0),
							BusCtrl => BusCtrl(0),
							LED_En => LED_En,
							LED1_Out => LED_1n,
							LED2_Out => LED_2n,
							LED3_Out => LED_3n,
							LED4_Out => LED_4n,
							LED5_Out => LED_5n,
							LED6_Out => LED_6n,
							LED7_Out => LED_7n,
							LED8_Out => LED_8n
					);
					
				--Instantiagte ADC_Int
				ADC_Int1: ADC_Int Port MAP (
										clk => clk,
										rst => System_rst,
										SPI_Sclk => ADC_SCLK,
										SPI_Din => ADC_DIN,
										SPI_CSn => ADC_CSn,
										SPI_Dout => ADC_DOUT,
										Data => Data,
										Addr => Addr,
										Xrqst => Xrqst,
										XDat => XDat,
										YDat => YDat,
										BusRqst => BusRqst(1),
										BusCtrl => BusCtrl(1)
									);
				
				--Instantiate PI_Buck
				PI_Buck1: PI_Buck PORT MAP (
							clk => clk,
							rst => System_rst,
							Data => Data,
							Addr => Addr,
							Xrqst => Xrqst,
							XDat => XDat,
							YDat => YDat,
							BusRqst => BusRqst (2),
							BusCtrl => BusCtrl (2)
							);
				
				--Instantiate Rest_Cnt_8
				Reset_Cnt: Std_Counter
				generic map
				(
						Width => 8
				)
				port map (
						clk => OSC_Out,
						rst => Reset_Cnt_rst,
						INC => Reset_Cnt_INC,
						Count => Reset_Cnt_Out
				);
				
				
				--Oscillator
				OSC_Stdby <= '0';
				
				--tie unused ports to '0'
				BusRqst (9 downto 4) <= (others => '0');
				--DSP_G1 <= '0';
				DSP_G2 <= '0';
				
				--reset Block1
				Reset_Blk1: process
				begin
								wait until OSC_Out'event and OSC_Out = '1';
										if (PLL_Lock = '0') then
												Reset_Cnt_rst <= '0'; --Active Low
										else
												Reset_Cnt_rst <= '1';
										end if;
				end process;
				
				--reset Block
				Rest_Blk: process
				begin
								wait until OSC_Out'event and OSC_Out ='1';
										if (Reset_Cnt_Out < X"7F") then
												System_rst <= '0'; --Active Low
												Reset_Cnt_Inc <= '1';
										else
												System_rst <= '1';
												Reset_Cnt_Inc <= '0';
										end if;
				end process;
				
				-- LED Invert due to active low configuration on dev board
				LED_Invert : process(LED_1n, LED_2n, LED_3n, LED_4n, LED_5n, LED_6n, LED_7n, LED_8n, SCI_RX, SCI_TX)
				begin
						
						LED_8 <= not(SCI_TX); -- used to show serial comms
						LED_7 <= not(SCI_RX); --- used to show serial coms
						LED_6 <= not(LED_6n);
						LED_5 <= not (LED_5n);
						LED_4 <= not (LED_4n);
						LED_3 <= not (LED_3n);
						LED_2 <= not (LED_2n);
						LED_1 <= not (LED_1n);
						PWM_Test_Out <= LED_1n;
						DSP_G1 <= LED_1n;
			end process;
			
end Behavioral;
		