library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lib_vhdl;
use lib_vhdl.phelmino_definitions.all;

entity decoder is

  port (
    instruction           : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    instruction_valid     : out std_logic;
    read_address_a        : out std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
    read_address_b        : out std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
    alu_operator          : out std_logic_vector(ALU_OPERATOR_WIDTH-1 downto 0);
    mux_controller_a      : out std_logic_vector(1 downto 0);
    mux_controller_b      : out std_logic_vector(1 downto 0);
    mux_controller_branch : out std_logic_vector(2 downto 0);
    is_requisition        : out std_logic;
    destination_register  : out std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
    immediate_extension   : out std_logic_vector(WORD_WIDTH-1 downto 0));

end entity decoder;

architecture behavioural of decoder is
begin  -- architecture behavioural

  -- purpose: decodes an instruction
  -- type   : combinational
  -- inputs : instruction
  decoder_process : process (instruction) is
    alias opcode is instruction(OPCODE_BEGIN downto OPCODE_END);
    alias func7 is instruction(FUNC7_BEGIN downto FUNC7_END);
    alias func3 is instruction(FUNC3_BEGIN downto FUNC3_END);
    alias rsource1 is instruction(RSOURCE1_BEGIN downto RSOURCE1_END);
    alias rsource2 is instruction(RSOURCE2_BEGIN downto RSOURCE2_END);
    alias rdestination is instruction(RDESTINATION_BEGIN downto RDESTINATION_END);
  begin  -- process decoder_process 
    case opcode is
      when OPCODE_ALU_REGISTER_REGISTER =>
        read_address_a        <= rsource1;
        read_address_b        <= rsource2;
        mux_controller_a      <= ALU_SOURCE_FROM_REGISTER;
        mux_controller_b      <= ALU_SOURCE_FROM_REGISTER;
        mux_controller_branch <= BRANCH_MUX_NOT_IN_A_BRANCH;
        instruction_valid     <= '1';
        is_requisition        <= '0';
        destination_register  <= rdestination;
        alu_operator          <= ALU_ADD;

        case func3 is
          when "000" =>
            case func7 is
              when "0000000" => alu_operator      <= ALU_ADD;
              when "0100000" => alu_operator      <= ALU_SUB;
              when others    => instruction_valid <= '0';
            end case;

          when "100" =>
            case func7 is
              when "0000000" => alu_operator      <= ALU_XOR;
              when others    => instruction_valid <= '0';
            end case;

          when "110" =>
            case func7 is
              when "0000000" => alu_operator      <= ALU_OR;
              when others    => instruction_valid <= '0';
            end case;

          when "111" =>
            case func7 is
              when "0000000" => alu_operator      <= ALU_AND;
              when others    => instruction_valid <= '0';
            end case;

          when others =>
            instruction_valid <= '0';
        end case;

      when OPCODE_BRANCH =>
        -- adds rs1 and rs2 and stores in rs0. this has no effect on the gpr.
        read_address_a       <= rsource1;
        alu_operator         <= ALU_ADD;
        read_address_b       <= rsource2;
        destination_register <= (others => '0');
        mux_controller_a     <= ALU_SOURCE_FROM_REGISTER;
        mux_controller_b     <= ALU_SOURCE_FROM_REGISTER;
        instruction_valid    <= '1';
        is_requisition       <= '0';

        case func3 is
          when "000" => mux_controller_branch <= BRANCH_MUX_EQUAL;
          when "001" => mux_controller_branch <= BRANCH_MUX_UNEQUAL;
          when "100" => mux_controller_branch <= BRANCH_MUX_LESS_THAN;
          when "101" => mux_controller_branch <= BRANCH_MUX_GREATER_OR_EQUAL;
          when others =>
            mux_controller_branch <= BRANCH_MUX_NOT_IN_A_BRANCH;
            instruction_valid     <= '0';
        end case;

      when others =>
        instruction_valid     <= '0';
        mux_controller_a      <= ALU_SOURCE_ZERO;
        mux_controller_b      <= ALU_SOURCE_ZERO;
        mux_controller_branch <= BRANCH_MUX_NOT_IN_A_BRANCH;
        read_address_a        <= (others => '0');
        read_address_b        <= (others => '0');
        alu_operator          <= ALU_ADD;
        destination_register  <= (others => '0');
    end case;
  end process decoder_process;

  -- purpose: sign extension of immediates
  -- type   : combinational
  signextension : process (instruction) is
    alias sign_bit is instruction(WORD_WIDTH-1);
    alias opcode is instruction(OPCODE_BEGIN downto OPCODE_END);
    alias immediate_type_i is instruction(IMMEDIATE_I_BEGIN downto IMMEDIATE_I_END);
    variable immediate_type_sb : std_logic_vector(IMMEDIATE_SB_LENGTH-1 downto 0);

    constant filled_one  : std_logic_vector(WORD_WIDTH-13 downto 0) := (others => '1');
    constant filled_zero : std_logic_vector(WORD_WIDTH-13 downto 0) := (others => '0');
  begin  -- process signextension
    immediate_type_sb := instruction(31) & instruction(7) & instruction(30 downto 25) & instruction(11 downto 8) & '0';

    case opcode is
      when opcode_alu_immediate_register =>
        if sign_bit = '0' then
          immediate_extension <= filled_zero & immediate_type_i;
        else
          immediate_extension <= filled_one & immediate_type_i;
        end if;

      when OPCODE_BRANCH =>
        if sign_bit = '0' then
          immediate_extension <= filled_zero(WORD_WIDTH-13 downto 1) & immediate_type_sb;
        else
          immediate_extension <= filled_one(WORD_WIDTH-13 downto 1) & immediate_type_sb;
        end if;

      when others => immediate_extension <= (others => '0');
    end case;
  end process signextension;

end architecture behavioural;
