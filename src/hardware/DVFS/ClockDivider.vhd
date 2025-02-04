
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library HyHeMPS;
    use HyHeMPS.HyHeMPS_PKG.all;

--library work;
	--use work.HyHeMPS_PKG.all;


entity ClockDivider is

	generic(
		CounterBitWidth: integer
	);

	port(

		Clock: in std_logic;
		Reset: in std_logic;

		N: in std_logic_vector(CounterBitWidth - 1 downto 0);
		M: in std_logic_vector(CounterBitWidth - 1 downto 0);
		WriteEnable: in std_logic;

		ClockGated: out std_logic

	);
	
end entity ClockDivider;


architecture RTL of ClockDivider is

	signal NReg, MReg, CounterReg: unsigned(CounterBitWidth - 1 downto 0);
	signal ComparatorReg: std_logic;

begin

	-- Propagates clock when N < M
	GatedClock: ClockGated <= Clock when ComparatorReg = '1' else '0';


	-- Control writing to N and M registers
	process(Clock, Reset) begin

		if Reset = '1' then

			-- Defaults to slowest possible clock
            NReg <= (others => '0');
            Nreg(0) <= '1';
			MReg <= (others => '1');

		elsif rising_edge(Clock) then

			if WriteEnable = '1' then

				NReg <= unsigned(N);
				MReg <= unsigned(M);

			end if;

		end if;

	end process;


	-- Counts from 0 to M - 1 
	Counter: process(Clock, Reset) begin

		if Reset = '1' then

			CounterReg <= (others => '0');

		elsif rising_edge(Clock) then

			-- Counter++ mod M
			--incr(value: integer ; maxValue: in integer ; minValue: in integer)
			CounterReg <= to_unsigned(incr(to_integer(CounterReg), to_integer(M) - 1, 0), CounterBitWidth);

		end if;

	end process;


	-- Compares CounterReg to N
	Comparator: process(Clock, Reset) begin

		if Reset = '1' then

			ComparatorReg <= '0';

		elsif rising_edge(Clock) then

			if NReg < MReg then
				ComparatorReg <= '1';
			else
				ComparatorReg <= '0';
			end if; 

		end if;

	end process;

end architecture RTL;
