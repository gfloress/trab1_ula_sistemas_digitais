----------------------------------------------------------------------------------
-- Company:  
-- Engineer:  
--  
-- Modified Date: 05/05/2025  
-- Module Name: Signal_Stabilizer - Behavioral  
-- Description: Debounces a noisy button input using a finite state machine (FSM)  
--              and a delay counter to ensure a clean output signal.  
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_STD.ALL;

entity Signal_Stabilizer is
    port(
        sys_clk      : in  STD_LOGIC;       -- System clock input
        raw_input    : in  STD_LOGIC;       -- Noisy button signal
        clean_output: out STD_LOGIC        -- Stabilized output
    );
end Signal_Stabilizer;

architecture Behavioral of Signal_Stabilizer is
    constant DEBOUNCE_DELAY : integer := 29999999;  -- Adjust for clock frequency
    signal delay_counter     : integer := 0;          -- Time delay counter
    signal stable_signal     : STD_LOGIC := '0';      -- Holds the stabilized state
    signal initialization    : STD_LOGIC := '1';      -- First-run flag
    
    type fsm_states is (WAIT_FOR_CHANGE, COUNT_DELAY);  -- FSM states
    signal current_state : fsm_states := WAIT_FOR_CHANGE;
    
begin
    stabilization_process: process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            case current_state is 
                when WAIT_FOR_CHANGE => 
                    if initialization = '1' then          -- Skip check on first run
                        current_state <= COUNT_DELAY;
                    else
                        if raw_input /= stable_signal then -- Input changed, reset counter
                            delay_counter <= 0;
                            stable_signal <= raw_input;
                            current_state <= COUNT_DELAY;
                        end if;
                    end if;
                    
                when COUNT_DELAY =>
                    if delay_counter < DEBOUNCE_DELAY then
                        delay_counter <= delay_counter + 1;  -- Increment until max
                        stable_signal <= '0';               -- Hold output low during delay
                    else
                        if initialization = '1' then         -- Clear first-run flag
                            initialization <= '0';
                            current_state <= WAIT_FOR_CHANGE;
                        end if;
                        current_state <= WAIT_FOR_CHANGE;   -- Return to waiting state
                    end if;
            end case;
            
            clean_output <= stable_signal;  -- Update output
                
        end if;
    end process;

end Behavioral;
