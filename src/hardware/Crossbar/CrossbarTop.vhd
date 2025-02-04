--------------------------------------------------------------------------------
-- Title       : Crossbar
-- Project     : HyHeMPS
--------------------------------------------------------------------------------
-- File        : Crossbar.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Implements a Crossbar interconnect, in which PEs have a direct
--               connection to each another, but still must compete for access 
--               to target's input buffer.
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


entity Crossbar is

	generic(
		ArbiterType: string := "RR";
		AmountOfPEs: integer;
		PEAddresses: HalfDataWidth_vector; -- := HyHeMPS_PKG.GetDefaultPEAddresses(AmountOfPEs);  -- As XY coordinates
		BridgeBufferSize: integer;
		IsStandalone: boolean
	);
	port(
		Clock: in std_logic;
		Reset: in std_logic;
		--PEInterfaces: inout PEInterface_vector
		PEInputs: out PEInputs_vector(0 to AmountOfPEs - 1);
		PEOutputs: in PEOutputs_vector(0 to AmountOfPEs - 1)
	);
	
end entity Crossbar;


architecture RTL of Crossbar is

	--constant PEAddresses: HalfDataWidth_vector(0 to AmountOfPEs - 1) := SetPEAddresses(PEAddressesFromTop, UseDefaultPEAddresses, AmountOfPEs);

	-- CrossbarControl input interface
	subtype CtrlDataIn_t is DataWidth_vector(0 to AmountOfPEs - 1);
	type CtrlDataIn_vector is array(0 to AmountOfPEs - 1) of CtrlDataIn_t;
	signal controlDataIn: CtrlDataIn_vector;

	subtype slv_t is std_logic_vector(0 to AmountOfPEs - 1);
	type slv_vector is array(0 to AmountOfPEs - 1) of slv_t;
	signal controlRx: slv_vector;
	--signal controlCreditO: slv_vector;
	signal controlCreditO: std_logic_vector(0 to AmountOfPEs - 1);

	-- Arbiter interface
	signal arbiterRequest: slv_vector;
	signal arbiterACK: slv_vector;
	signal arbiterGrant: slv_vector;
	signal arbiterNewGrant: std_logic_vector(0 to AmountOfPEs - 1);

    -- Bridge output interface
	signal bridgeTx: std_logic_vector(0 to AmountOfPEs - 1);
	signal bridgeDataOut: DataWidth_vector(0 to AmountOfPEs - 1);
	--signal bridgeCredit: slv_vector;

	-- Bridge to Arbiter interface
	signal bridgeACK: slv_vector;
	signal bridgeRequest: slv_vector;
	signal bridgeGrant: slv_vector;

    -- Performs "or" operation between all elements of a given std_logic_vector
	function OrReduce(inputArray: std_logic_vector) return std_logic is
		variable orReduced: std_logic := '0';
	begin

		for i in inputArray'range loop 

			orReduced := orReduced or inputArray(i);

		end loop;

		return orReduced;
		
	end function OrReduce;

begin

	-- Instantiates bridges
	CrossbarBridgeGen: for i in 0 to AmountOfPEs - 1 generate

        --PEInterfaces(i).ClockTx <= Clock;
        PEInputs(i).ClockRx <= Clock;

		CrossbarBridge: entity work.CrossbarBridge

			generic map(
				BufferSize  => BridgeBufferSize,
				AmountOfPEs => AmountOfPEs,
				PEAddresses => PEAddresses,
                SelfIndex   => i,
				SelfAddress => PEAddresses(i)
			)

			port map(

				-- Basic
				Clock => Clock,
				Reset => Reset,

				-- PE interface (Bridge input)
				--ClockRx => PEInterfaces(i).ClockTx,
				--Rx      => PEInterfaces(i).Tx,
				--DataIn  => PEInterfaces(i).DataOut,
				--CreditO => PEInterfaces(i).CreditI,
				ClockRx => PEOutputs(i).ClockTx,
				Rx      => PEOutputs(i).Tx,
				DataIn  => PEOutputs(i).DataOut,
				CreditO => PEInputs(i).CreditI,

				-- Crossbar interface (Bridge output)
				ClockTx => open,
				Tx      => bridgeTx(i),
				DataOut => bridgeDataOut(i),
				--CreditI => bridgeCredit(i),
				CreditI => controlCreditO,

				-- Arbiter interface
				--ACK     => bridgeACK,
				ACK     => bridgeACK(i),
				--Request => bridgeRequest,
				Request => bridgeRequest(i),
				--Grant   => bridgeGrant
				Grant   => orReduce(bridgeGrant(i))

			);

	end generate CrossbarBridgeGen;


	-- Instantiates input controllers
	CrossbarControlGen: for i in 0 to AmountOfPEs - 1 generate

		CrossbarControl: entity work.CrossbarControl

			generic map(
				PEAddresses => PEAddresses,
				SelfAddress => PEAddresses(i),
                SelfIndex => i,
				IsStandalone => IsStandalone
			)
			port map(
				
				-- Basic
				Clock => Clock,
				Reset => Reset,

				-- Input interface (Crossbar)
				DataInMux => controlDataIn(i),
				RxMux     => controlRx(i),
				CreditO   => controlCreditO(i),

				-- Output interface (PE input)
				--PEDataIn  => PEInterfaces(i).DataIn,
				--PERx      => PEInterfaces(i).Rx,
				--PECreditO => PEInterfaces(i).CreditO,
				PEDataIn  => PEInputs(i).DataIn,
				PERx      => PEInputs(i).Rx,
				--PECreditO => PEInputs(i).CreditO,
				PECreditO => PEOutputs(i).CreditO,
				
				-- Arbiter interface
				NewGrant  => arbiterNewGrant(i),
				Grant => arbiterGrant(i)

			);

			ControlConnectGen: for j in 0 to AmountOfPEs - 1 generate

				ControlMap: if i /= j generate

					controlDataIn(i)(j) <= bridgeDataOut(j);
					controlRx(i)(j) <= bridgeTx(j);
					--bridgeCredit(i) <= controlCreditO(i)(j);  -- MOVED TO CrossbarControl

				end generate ControlMap;

				ControlGround: if i = j generate

					controlDataIn(i)(j) <= (others => '0');
					controlRx(i)(j) <= '0';
					--bridgeCredit(i) <= '0';  -- MOVED TO CrossbarControl

				end generate ControlGround;

			end generate ControlConnectGen;

	end generate CrossbarControlGen;


	-- Instantiates arbiters as given by "Arbiter" generic
	ArbiterGen: for Arbiter in 0 to AmountOfPEs - 1 generate

		RoundRobinArbiterGen: if ArbiterType = "RR" generate

			RoundRobinArbiter: entity work.CrossbarRRArbiter

				generic map(
					AmountOfPEs => AmountOfPEs
				)
				port map(
					Clock => Clock,
					Reset => Reset,
					Ack   => arbiterACK(Arbiter),
					Grant => arbiterGrant(Arbiter),
					Req   => arbiterRequest(Arbiter),
					NewGrant => arbiterNewGrant(Arbiter)
				);

		end generate RoundRobinArbiterGen;
		
--		DaisyChainArbiterGen: if ArbiterType = "DC" generate
		
--            DaisyChainArbiter: entity work.CrossbarDCArbiter

--				generic map(
--					AmountOfPEs => AmountOfPEs
--				)
--				port map(
--					Clock => Clock,
--					Reset => Reset,
--					Ack   => arbiterACK(Arbiter),
--					Grant => arbiterGrant(Arbiter),
--					Req   => arbiterRequest(Arbiter)
--				);
		
--		end generate DaisyChainArbiterGen;

		ArbConnectGen: for Bridge in 0 to AmountOfPEs - 1 generate

			ArbMap: if Bridge /= Arbiter generate

				--arbiterACK(Arbiter)(Bridge) <= bridgeACK(Bridge);
				arbiterACK(Arbiter)(Bridge) <= bridgeACK(Bridge)(Arbiter);
				--arbiterGrant(Arbiter)(Bridge) <= bridgeGrant(Bridge);
				bridgeGrant(Bridge)(Arbiter) <= arbiterGrant(Arbiter)(Bridge);
				--bridgeRequest(Bridge) <= arbiterRequest(Arbiter)(Bridge);
				arbiterRequest(Arbiter)(Bridge) <= bridgeRequest(Bridge)(Arbiter);

                -- TODO: bridgeGrant(Bridge) <= orReduce(arbiterGrant(Bridge)(Arbiter));
                -- TODO: do orReduce on ACKs here, instead of in arbiter

			end generate ArbMap;

			ArbGround: if Bridge = Arbiter generate

				arbiterACK(Arbiter)(Bridge) <= '0';
				--arbiterGrant(Arbiter)(Bridge) <= '0';
                bridgeGrant(Bridge)(Arbiter) <= '0';
				--bridgeRequest(Bridge) <= '0';
                arbiterRequest(Arbiter)(Bridge) <= '0';

			end generate ArbGround;

		end generate ArbConnectGen;

	end generate ArbiterGen;

end architecture RTL;
