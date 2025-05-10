----------------------------------------------------------------------------------
-- Module: Arithmetic_Logic_Unit (ALU)
-- Description: 
--   4-bit ALU with debounced input control. Performs 8 operations:
--   [Arithmetic] Addition, Subtraction 
--   [Logical] AND, OR, XOR
--   [Comparison] Greater-than, Less-than 
--   [Shifts] Configurable bit-shifting
--   Generates 4 status flags: Carry, Overflow, Zero, and Sign.
--   Uses 3-stage input capture via a Finite State Machine (FSM).
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Arithmetic_Logic_Unit is
    port (
        -- Input Ports --
        operand_in    : in  STD_LOGIC_VECTOR(3 downto 0); -- Shared bus for operands/opcode
        clock         : in  STD_LOGIC;                    -- System clock (50MHz typical)
        execute_btn   : in  STD_LOGIC;                    -- Debounced button for input capture
        system_reset  : in  STD_LOGIC;                    -- Active-high reset (asynchronous)
        
        -- Output Ports --
        carry_flag    : out STD_LOGIC;                    -- Carry-out from arithmetic ops
        overflow_flag : out STD_LOGIC;                    -- Overflow (signed arithmetic)
        zero_flag     : out STD_LOGIC;                    -- High when result = 0
        sign_flag     : out STD_LOGIC;                    -- MSB of result (signed numbers)
        result_out    : out STD_LOGIC_VECTOR(3 downto 0)  -- ALU output
    );
end Arithmetic_Logic_Unit;

architecture Behavioral of Arithmetic_Logic_Unit is

    -- Debouncer Component --
    component Input_Debouncer
    port(
        clk         : in  STD_LOGIC;     -- Clock for debounce circuit
        noisy_input : in  STD_LOGIC;      -- Raw button signal
        clean_output: out STD_LOGIC       -- Debounced signal (stable for 50ms)
    );
    end component;
     
    -- Internal Registers --
    signal operand_A_reg  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0'); -- First operand storage
    signal operand_B_reg  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0'); -- Second operand storage
    signal opcode_reg     : STD_LOGIC_VECTOR(3 downto 0) := (others => '0'); -- Operation code storage
    signal fsm_state      : STD_LOGIC_VECTOR(2 downto 0) := "000";           -- FSM current state
    signal execute_ready  : STD_LOGIC := '0';                                -- Pulse to trigger ALU operation
    signal stable_button  : STD_LOGIC := '0';                                -- Debounced button signal

    --------------------------------------------------
    -- Function: perform_shift
    -- Purpose: Implements configurable bit-shifting
    -- Parameters:
    --   input_vec: Data to shift
    --   control:  [3:2]=shift_amount, [1]=direction (0=right,1=left), [0]=fill_bit
    -- Returns: Shifted 4-bit result
    --------------------------------------------------
    function perform_shift(input_vec, control: STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
        variable shifted_result : STD_LOGIC_VECTOR(3 downto 0);
        variable shift_count   : integer range 0 to 3;
        variable direction     : STD_LOGIC;
        variable fill_bit      : STD_LOGIC;
    begin 
        -- Extract control bits
        shift_count := to_integer(unsigned(control(3 downto 2))); 
        direction   := control(1);
        fill_bit    := control(0);
        
        shifted_result := input_vec; -- Default value
        
        -- Unrolled shift logic for better timing
        case shift_count is
            when 0 => -- No shift
                shifted_result := input_vec;
            when 1 => -- Shift by 1
                if direction = '0' then  -- Right shift
                    shifted_result := fill_bit & input_vec(3 downto 1);
                else  -- Left shift
                    shifted_result := input_vec(2 downto 0) & fill_bit;
                end if;
            -- ... (Cases for shift counts 2 and 3)
        end case;
        return shifted_result;
    end function;

    -- (Other functions remain with similar detailed comments)

begin
    --------------------------------------------------
    -- Debouncer Instantiation
    -- Purpose: Filters mechanical button bouncing
    -- Debounce period: ~50ms (assuming 50MHz clock)
    --------------------------------------------------
    debouncer_inst: Input_Debouncer
    port map(
        clk         => clock,
        noisy_input => execute_btn,
        clean_output=> stable_button
    );
    
    --------------------------------------------------
    -- Finite State Machine (FSM) Process
    -- Purpose: Sequentially captures 3 inputs:
    --   State 000: Waits for Operand A
    --   State 010: Waits for Operand B
    --   State 100: Waits for Opcode
    --   State 101: Triggers ALU execution (single cycle)
    --------------------------------------------------
    process(clock, system_reset)
    begin
        if system_reset = '1' then -- Asynchronous reset
            fsm_state     <= "000";
            operand_A_reg <= (others => '0');
            operand_B_reg <= (others => '0');
            opcode_reg    <= (others => '0');
            execute_ready <= '0';
        elsif rising_edge(clock) then
            case fsm_state is
                when "000" => -- Capture Operand A
                    if stable_button = '1' then
                        operand_A_reg <= operand_in;
                        fsm_state <= "001"; -- Move to debounce delay
                    end if;
                -- ... (Other states with detailed comments)
                when "101" => -- Execute operation
                    execute_ready <= '1'; -- Single-cycle pulse
                    fsm_state <= "000";   -- Reset FSM
            end case;
        end if;
    end process;

    --------------------------------------------------
    -- ALU Operation Process
    -- Purpose: Performs selected operation when execute_ready=1
    -- Note: All operations complete in 1 clock cycle
    --------------------------------------------------
    process(clock)
        variable alu_result   : SIGNED(4 downto 0); -- 5-bit to detect overflow
        variable output_bus  : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if rising_edge(clock) then
            if execute_ready = '1' then
                case opcode_reg is
                    when "0000" =>  -- Addition
                        alu_result := ('0' & SIGNED(operand_A_reg)) + ('0' & SIGNED(operand_B_reg));
                        output_bus := STD_LOGIC_VECTOR(alu_result(3 downto 0));
                        carry_flag <= alu_result(4); -- Carry-out bit
                        -- Overflow detection for signed addition
                        overflow_flag <= (operand_A_reg(3) xor alu_result(3)) and 
                                        not (operand_A_reg(3) xor operand_B_reg(3));

                    -- ... (Other operations with similar detailed comments)

                    when others =>  -- Default case
                        output_bus := (others => '0');
                        carry_flag <= '0';
                        overflow_flag <= '0';
                end case;

                -- Status Flags Generation --
                zero_flag <= '1' when output_bus = "0000" else '0';  -- Zero detection
                sign_flag <= output_bus(3);                          -- Negative flag
                result_out <= output_bus;                             -- Drive output
            end if;
        end if;
    end process;
end Behavioral;
