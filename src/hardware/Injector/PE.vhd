--------------------------------------------------------------------------------
-- Title       : PE
-- Project     : HyHeMPS
--------------------------------------------------------------------------------
-- File        : PE.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Container for a single msg injector and receiver
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Initial implementation
--             : v1.0 - Verified
--------------------------------------------------------------------------------
-- TODO        :
--------------------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.HyHeMPS_PKG.all;
    use work.Injector_PKG.all;
    use work.JSON.all;


entity PE is 

    generic(
        -- Path to JSON file containing PE and APP parameters
        PEConfigFile       : string;
        PlatformConfigFile : string;
        ConfigPath         : string := "./flow/";
        LogPath            : string := "./log/"
    );

    port(

        -- Basic
	    --Clock   : in  std_logic;
        Reset   : in  std_logic;

	    -- Output Interface (Injector)
        ClockTx : out std_logic;
        Tx      : out std_logic;
        DataOut : out DataWidth_t;
        CreditI : in  std_logic;

        -- Input Interface (Receiver)
        ClockRx : in  std_logic;        
        Rx      : in  std_logic;
        DataIn  : in  DataWidth_t;
        CreditO : out std_logic

    );

end entity PE;


architecture Injector of PE is

    -- JSON config files
    constant PEJSONConfig: T_JSON := jsonLoad(PEConfigFile);

    constant PEPos: integer := jsonGetInteger(PEJSONConfig, "PEPos");
    constant BusArbiter: string(1 to 2) := jsonGetString(PEJSONConfig, "BusArbiter");
    constant BusBridgeBufferSize: integer := jsonGetInteger(PEJSONConfig, "BridgeBufferSize");

    --
    constant AmountOfThreads: integer := jsonGetInteger(PEJSONConfig, "AmountOfThreads");
    constant AmountOfFlows: integer := jsonGetInteger(PEJSONConfig, "AmountOfFlows");
    constant MaxAmountOfFlows: integer := jsonGetInteger(PEJSONConfig, "LargestAmountOfFlows");
    constant AmountOfFlowsInThread: integer_vector(0 to AmountOfThreads - 1) := jsonGetIntegerArray(PEJSONConfig, "AmountOfFlowsInThread");

    constant ThreadID: integer_vector(0 to AmountOfThreads - 1) := jsonGetIntegerArray(PEJSONConfig, "ThreadID");
    constant AppID: integer_vector(0 to AmountOfThreads - 1) := jsonGetIntegerArray(PEJSONConfig, "AppID");

    -- Injector/Trigger signals
    type InjectorInterface_2vector is array(0 to AmountOfThreads - 1, 0 to MaxAmountOfFlows - 1) of InjectorInterface;
    signal InjectorInterfaces_2D: InjectorInterface_2vector;

    function InjectorInterfaceTo1D(InjectorInterfaces_2D: InjectorInterface_2vector; AmountOfFlows: integer) return InjectorInterface_vector is 
        variable i: integer := 0;
        variable InjectorInterfaces_1D: InjectorInterface_vector(0 to AmountOfFlows - 1);
    begin

        -- Instantiates Injectors
        InjectorGenThread: for ThreadNum in 0 to AmountOfThreads - 1 loop

            InjectorGenFlow: for FlowNum in 0 to AmountOfFlowsInThread(ThreadNum) - 1 loop

                InjectorInterfaces_1D(i) := InjectorInterfaces_2D(ThreadNum, FlowNum);
                i := i + 1;

            end loop InjectorGenFlow;

        end loop InjectorGenThread;

        return InjectorInterfaces_1D;

    end function InjectorInterfaceTo1D;

    --signal InjectorInterfaces_1D: InjectorInterface_vector(0 to AmountOfFlows - 1) := InjectorInterfaceTo1D(InjectorInterfaces_2D, AmountOfFlows);
    signal InjectorInterfaces_1D: InjectorInterface_vector(0 to AmountOfFlows - 1);
    
begin 

    InjectorInterfaces_1D <= InjectorInterfaceTo1D(InjectorInterfaces_2D, AmountOfFlows);

    -- Instantiates Injectors
  	InjectorGenThread: for ThreadNum in 0 to AmountOfThreads - 1 generate

        InjectorGenFlow: for FlowNum in 0 to AmountOfFlowsInThread(ThreadNum) - 1 generate

            Injector: entity work.Injector

                generic map(
                    InjectorConfigFile => ConfigPath & "PE " & integer'image(PEPos) & "/Thread " & integer'image(ThreadNum) & "/Flow " & integer'image(FlowNum) & ".json",                 
                    PlatformConfigFile => PlatformConfigFile,
                    OutboundLogFilename => LogPath & "PE " & integer'image(PEPos) & "/OutLog" & integer'image(PEPos) & "_" & integer'image(ThreadNum) & "_" & integer'image(FlowNum) & ".txt"
                )
                port map(
                    Clock => InjectorInterfaces_2D(ThreadNum, FlowNum).Clock,
                    Reset => InjectorInterfaces_2D(ThreadNum, FlowNum).Reset,
                    Enable => InjectorInterfaces_2D(ThreadNum, FlowNum).Enable,
                    DataOut => InjectorInterfaces_2D(ThreadNum, FlowNum).DataOut,
                    DataOutAV => InjectorInterfaces_2D(ThreadNum, FlowNum).DataOutAV,
                    OutputBufferAvailableFlag => InjectorInterfaces_2D(ThreadNum, FlowNum).OutputBufferAvailableFlag
                );

        end generate InjectorGenFlow;

    end generate InjectorGenThread;


    -- Instantiates Triggers for each Injector
    TriggerGenThread: for ThreadNum in 0 to AmountOfThreads - 1 generate

        TriggerGenFlow: for FlowNum in 0 to AmountOfFlowsInThread(ThreadNum) - 1 generate

            Trigger: entity work.Trigger

                generic map(
                    InjectorConfigFile => ConfigPath & "PE " & integer'image(PEPos) & "/Thread " & integer'image(ThreadNum) & "/Flow " & integer'image(FlowNum) & ".json",
                    PlatformConfigFile => PlatformConfigFile
                )
                port map(
                    Reset => InjectorInterfaces_2D(ThreadNum, FlowNum).Reset,
                    Enable => InjectorInterfaces_2D(ThreadNum, FlowNum).Enable,
                    InjectorClock => InjectorInterfaces_2D(ThreadNum, FlowNum).Clock,
                    OutputBufferAvailableFlag => InjectorInterfaces_2D(ThreadNum, FlowNum).OutputBufferAvailableFlag
                );

        end generate TriggerGenFlow;

    end generate TriggerGenThread;


    DirectConnectGen: if AmountOfFlows = 1 generate

        Bridge: entity work.BusBridge

            generic map(
                BufferSize => BusBridgeBufferSize
            )
            port map(

                -- Basic
		        Clock => InjectorInterfaces_1D(0).Clock,
		        Reset => Reset,

		        -- PE Interface
		        ClockRx => InjectorInterfaces_1D(0).Clock,
		        Rx => InjectorInterfaces_1D(0).DataOutAV,
		        DataIn => InjectorInterfaces_1D(0).DataOut,
		        CreditO => InjectorInterfaces_1D(0).OutputBufferAvailableFlag,

		        -- Bus Interface
		        ClockTx => open,
		        Tx => Tx,
		        DataOut => DataOut,
		        CreditI => CreditI,

		        -- Arbiter Interface
		        Ack => open,
		        Request => open,
		        Grant => '1'

            );

    end generate DirectConnectGen;


    PEBusGen: if AmountOfFlows > 1 generate

        PEBus: entity work.PEBus

            generic map(
                Arbiter => BusArbiter,
                AmountOfInjectors => AmountOfFlows,
                BridgeBufferSize => BusBridgeBufferSize
            ) 
            port map(

                -- Basic
                Clock => ClockRx,
                Reset => Reset,

                -- Input Interface (from Injectors)
                InjectorInterfaces => InjectorInterfaces_1D,

                -- Output Interface (to comm structure)
                DataOut => DataOut,
                DataOutAV => Tx,
                CreditI => CreditI,
                ClockTx => ClockTx

            );

    end generate PEBusGen;


    -- Instantiates a receiver, which generate a log of all incoming messages
    Receiver: entity work.Receiver

      	generic map(
      		InboundLogFilename => LogPath & "PE " & integer'image(PEPos) & "/InLog" & integer'image(PEPos) & ".txt"
      	)
      	port map(

      		Clock   => ClockRx,
      		Reset   => Reset,
      		DataIn  => DataIn,
      		Rx      => Rx,
      		CreditO => CreditO

      	);
    
    CreditO <= '1';

end architecture Injector;
