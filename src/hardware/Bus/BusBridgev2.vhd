--------------------------------------------------------------------------------
-- Title       : Bus interface module for HyHeMPS
-- Project     : HyHeMPS
--------------------------------------------------------------------------------
-- File        : BusBridgev2.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : 
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Initial implementation
--------------------------------------------------------------------------------
-- TODO        :
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library HyHeMPS;
    use HyHeMPS.HyHeMPS_PKG.all;

--library work;
	--use work.HyHeMPS_PKG.all; 


entity BusBridge is

	generic(
		BufferSize : integer
	);
	port(

		-- Basic
		Clock    : in std_logic;
		Reset    : in std_logic;

		-- PE Interface
		ClockRx  : in std_logic;
		Rx       : in std_logic;
		DataIn   : in DataWidth_t;
		CreditO  : out std_logic;

		-- Bus Interface
		ClockTx  : out std_logic;
		Tx       : out std_logic;
		DataOut  : out DataWidth_t;
		CreditI  : in std_logic;

		-- Arbiter Interface
		ACK      : out std_logic;
		Request  : out std_logic;
		Grant    : in std_logic

	);

end BusBridge;


architecture RTL of BusBridge is

	type state_t is (Sstandby, SwaitForGrant, Stransmit);
	signal currentState: state_t;
	
	signal flitCounter: unsigned(DataWidth - 1 downto 0);
    signal flitCounterFilled: std_logic;

	signal bufferDataOut: DataWidth_t;
    signal bufferReadyFlag: std_logic;
	signal bufferAVFlag: std_logic;
    signal bufferReadConfirm: std_logic;

begin

	-- Instantiates a bisynchronous FIFO
	FIFO: entity work.CircularBuffer

		generic map (
			BufferSize => BufferSize,
			DataWidth  => DataWidth
		)
		port map (
			
			-- Basic
			Reset               => Reset,

			-- PE Interface (Input)
			ClockIn             => ClockRx,
			DataIn              => DataIn,
			DataInAV            => Rx,
			WriteACK            => open,

			-- Bus interface (Output)
			ClockOut            => Clock,
			DataOut             => bufferDataOut,
			--ReadConfirm         => CreditI,
            ReadConfirm         => bufferReadConfirm,
			ReadACK             => open,
			
			-- Status flags
			BufferEmptyFlag     => open,
			BufferFullFlag      => open,
			BufferReadyFlag     => CreditO,
            --BufferReadyFlag     => bufferReadyFlag,
			BufferAvailableFlag => bufferAVFlag

		);


	-- Same as struct clock (clock domain crossing occurs at InjBuffer)
	ClockTx <= ClockRx;
	Tx <= bufferAVFlag when currentState = Stransmit else 'Z';
	DataOut <= bufferDataOut when currentState = Stransmit else (others => 'Z');
    --CreditO <= bufferReadyFlag when currentState = Stransmit else 'Z';

    bufferReadConfirm <= CreditI when currentState = Stransmit else '0';

	-- 
	ControlFSM: process(Reset, ClockRx) begin

        if Reset = '1' then

            ACK <= 'Z';
			Request <= '0';

            flitCounter <= to_unsigned(0, DataWidth);
            flitCounterFilled <= '0';

			currentState <= Sstandby;

		elsif rising_edge(ClockRx) then

			case currentState is

				-- Sets default values
				--when Sreset => 

					--ACK <= 'Z';
					--Request <= '0';

				-- Waits for a new message
				when Sstandby => 
                    
                    ACK <= 'Z';
			        Request <= '0';

					if Rx = '1' then
					--if bufferAVFlag = '1' then

						Request <= '1';

						currentState <= SwaitForGrant;

					else
						currentState <= Sstandby;

					end if;

				-- Waits for arbiter grant signal
				when SwaitForGrant => 

                    if flitCounterFilled = '0' then
					    flitCounter <= unsigned(DataIn) + 2;
                        flitCounterFilled <= '1';
                    end if;

					if Grant = '1' then

						ACK <= '0';
						Request <= '0';

						currentState <= Stransmit;

					else

						currentState <= SwaitForGrant;

					end if;

				-- Transmits message through bus
				when Stransmit => 

					--ACK <= 'Z';
                    flitCounterFilled <= '0';

					if CreditI = '1' and bufferAVFlag = '1' then
					    flitCounter <= flitCounter - 1;
				    end if;

					-- Determines if this is the last flit of msg
					if flitCounter = 0 then
					--if flitCounter = 0 and CreditI = '1' and bufferAVFlag = '1' then
					--if bufferAVFlag = '0' then
						ACK <= '1';
						currentState <= Sstandby;

					else
						currentState <= Stransmit;

					end if;

			end case;

		end if;

	end process ControlFSM;
	
end architecture RTL;
