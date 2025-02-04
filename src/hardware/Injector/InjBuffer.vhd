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


entity InjBuffer is

	generic(
		BufferSize : integer;
		MaxAmountOfBufferedMessages : integer  := 4;
		PEPos: integer
	);
	port(

		-- Basic
		Clock   : in std_logic;
		Reset   : in std_logic;

		-- Injector Interface
		ClockRx : in std_logic;
		Rx      : in std_logic;
		DataIn  : in DataWidth_t;
		CreditO : out std_logic;

		-- Bus Interface
		ClockTx : out std_logic;
		Tx      : out std_logic;
		DataOut : out DataWidth_t;
		CreditI : in std_logic;

		-- Arbiter Interface
		ACK     : out std_logic;
		Request : out std_logic;
		Grant   : in std_logic

	);

end InjBuffer;


architecture RTL of InjBuffer is

	type rxState_t is (Sstandby, Ssize, Sfill);
	signal rxState: rxState_t;

	type txState_t is (Sstandby, SwaitForGrant, Stransmit);
	signal txState: txState_t;
	
	signal rxCounter: unsigned(DataWidth - 1 downto 0) := (others => '1');
	signal txCounter: unsigned(DataWidth - 1 downto 0) := (others => '1');

	signal sizeTemp: DataWidth_t;

	--shared variable txEnable: std_logic;

	signal MessagesFIFODataOut: DataWidth_t;
    signal MessagesFIFOCreditI: std_logic;
	signal MessagesFIFOAVFlag: std_logic;
	signal MessagesFIFOReadyFlag: std_logic;

	signal SizesFIFODataOut: DataWidth_t;
	signal SizesFIFOEnable: std_logic;
	signal SizesFIFOCreditI: std_logic;
	signal SizesFIFOAVFlag: std_logic;
	signal SizesFIFOReadyFlag: std_logic;

begin

	-- Instantiates a bisynchronous FIFO for storing whole messages
	MessagesFIFO: entity work.CircularBuffer

		generic map(
			BufferSize => BufferSize,
			DataWidth  => DataWidth
		)
		port map(
			
			-- Basic
			Reset               => Reset,

			-- PE Interface (Input)
			ClockIn             => ClockRx,
			DataIn              => DataIn,
			DataInAV            => Rx,
			WriteACK            => open,

			-- Bus interface (Output)
			ClockOut            => Clock,
			DataOut             => MessagesFIFODataOut,
			--ReadConfirm         => CreditI,
            ReadConfirm         => MessagesFIFOCreditI,
			ReadACK             => open,
			
			-- Status flags
			--DataCount           => FIFODataCount,
			BufferEmptyFlag     => open,
			BufferFullFlag      => open,
			--BufferReadyFlag     => CreditO,
			BufferReadyFlag     => MessagesFIFOReadyFlag,
			BufferAvailableFlag => MessagesFIFOAVFlag

		);


	-- Instantiates a bisynchronous FIFO for storing only message sizes
	SizesFIFO: entity work.CircularBuffer

		generic map(
			BufferSize => MaxAmountOfBufferedMessages,
			DataWidth  => DataWidth
		)
		port map(
			
			-- Basic
			Reset               => Reset,

			-- PE Interface (Input)
			ClockIn             => ClockRx,
			DataIn              => sizeTemp,
			DataInAV            => SizesFIFOEnable,
			WriteACK            => open,

			-- Bus interface (Output)
			ClockOut            => Clock,
			DataOut             => SizesFIFODataOut,
			--ReadConfirm         => CreditI,
            ReadConfirm         => SizesFIFOCreditI,
			ReadACK             => open,
			
			-- Status flags
			--DataCount           => FIFODataCount,
			BufferEmptyFlag     => open,
			BufferFullFlag      => open,
			--BufferReadyFlag     => CreditO,
			BufferReadyFlag     => SizesFIFOReadyFlag,
			BufferAvailableFlag => SizesFIFOAVFlag

		);


	-- 
	ClockTx <= Clock;


	-- 
	--Tx <= bufferAVFlag when currentState = Stransmit else 'Z';
	Tx <= MessagesFIFOAVFlag when txState = Stransmit else 'Z';
	--Tx <= FIFOAVFlag when FIFODataCount > 0 and txEnable = '1' else 'Z';
	--Tx <= FIFOAVFlag when txEnable = '1' else 'Z';


	-- 
	--DataOut <= dataTristate when currentState = Stransmit else (others => 'Z');
	DataOut <= MessagesFIFODataOut when txState = Stransmit else (others => 'Z');
	--DataOut <= FIFODataOut when FIFODataCount > 0 and txEnable = '1' else (others => 'Z');
	--DataOut <= FIFODataOut when txEnable = '1' else (others => 'Z');

    --FIFOCreditI <= CreditI when txEnable = '1' else '0';
    MessagesFIFOCreditI <= CreditI when txState = Stransmit else '0';


	-- 
	--CreditO <= '0' when currentState = Stransmit or currentState = SwaitForGrant else bufferReadyFlag;
	CreditO <= MessagesFIFOReadyFlag;
	--injSideCreditI <= '0' when currentState = Stransmit or currentState = SwaitForGrant else structSideReadyFlag;


	-- 
	RxFSM: process(ClockRx, Reset) begin

        if Reset = '1' then

            rxCounter <= (others => '0');
            sizeTemp <= (others => '0');

            SizesFIFOEnable <= '0';

			rxState <= Sstandby;

		elsif rising_edge(ClockRx) then

			case rxState is

				-- Waits for a new message
				when Sstandby => 

					SizesFIFOEnable <= '0';

					-- New message with ADDR flit @ data in
					if Rx = '1' and MessagesFIFOReadyFlag = '1'then
						rxState <= Ssize;
					else
						rxState <= Sstandby;

					end if;

				-- Captures message size from dataIn
				when Ssize => 

					--if Rx = '1' and bufferReadyFlag = '1' then
					if Rx = '1' and MessagesFIFOReadyFlag = '1' then

						rxCounter <= unsigned(DataIn);
						--txCounter <= unsigned(DataIn) + 2;

						sizeTemp <= std_logic_vector(unsigned(DataIn) + to_unsigned(2, DataWidth));

						rxState <= Sfill;

					else
						rxState <= Ssize;
					end if;

				-- Fills buffer with payload
				when Sfill => 

					if Rx = '1' and MessagesFIFOReadyFlag = '1' then
					--if structSideReadyFlag = '1' and injSideAVFlag = '1' then
						rxCounter <= rxCounter - 1;
					
						-- Done filling buffer, ready to transmit
						if rxCounter = 1 then

							SizesFIFOEnable <= '1';

							if SizesFIFOReadyFlag = '0' then

								report "No available slot on sizes FIFO at PEPos <" & integer'image(PEPos) & ">" severity error;
								rxState <= Sfill;

							else
								rxState <= Sstandby;
							end if;
							
						else
							rxState <= Sfill;
						end if;

					end if;

			end case;

		end if;

	end process RxFSM;


	TxFSM: process(Clock, Reset) begin

        if Reset = '1' then 

            txCounter <= (others => '0');            

        	SizesFIFOCreditI <= '0';

        	Request <= '0';
        	ACK <= 'Z';

        	txState <= Sstandby;

        elsif rising_edge(Clock) then

            case txState is

                when Sstandby => 

                	-- Default values
                	Request <= '0';
        			ACK <= 'Z'; 

                    if SizesFIFOAVFlag = '1' then

                    	SizesFIFOCreditI <= '1';
                    	Request <= '1';
                    	txCounter <= unsigned(SizesFIFODataOut);

                        txState <= SwaitForGrant;
                    else
                        txState <= Sstandby;
                    end if;

                when SwaitForGrant => 

                	SizesFIFOCreditI <= '0';

                	if Grant = '1' then
                		txState <= Stransmit;
                	else
                		txState <= SwaitForGrant;
                	end if;

                when Stransmit =>

                	Request <= '0';

                	if CreditI = '1' and txCounter > 0 then
                		txCounter <= txCounter - 1;
                	end if;

                    --if FIFOAVFlag = '1' then
                    if CreditI = '1' and txCounter = 1 then
                    	ACK <= '1';
                        txState <= Sstandby;
                    else    
                        txState <= Stransmit;
                    end if; 

            end case;

        end if;

    end process TxFSM;
	
end architecture RTL;
