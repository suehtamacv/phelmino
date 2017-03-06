library ieee;
use ieee.std_logic_1164.all;

library lib_vhdl;
use lib_vhdl.all;
use lib_vhdl.phelmino_definitions.all;

entity phelmino_core is

  port (
    -- clock and reset signals
    clk   : in std_logic;
    rst_n : in std_logic;

    -- instruction memory interface
    instr_requisition_output : out std_logic;
    instr_address_output     : out std_logic_vector(WORD_WIDTH-1 downto 0);
    instr_grant_input        : in  std_logic;
    instr_reqvalid_input     : in  std_logic;
    instr_reqdata_input      : in  std_logic_vector(WORD_WIDTH-1 downto 0));

end entity phelmino_core;

architecture behavioural of phelmino_core is
  component if_stage is
    port (
      clk                             : in  std_logic;
      rst_n                           : in  std_logic;
      instr_requisition_output        : out std_logic;
      instr_address_output            : out std_logic_vector(WORD_WIDTH-1 downto 0);
      instr_grant_input               : in  std_logic;
      instr_reqvalid_input            : in  std_logic;
      instr_reqdata_input             : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      instr_reqvalid_id_output        : out std_logic;
      instr_reqdata_id_output         : out std_logic_vector(WORD_WIDTH-1 downto 0);
      instr_program_counter_id_output : out std_logic_vector(WORD_WIDTH-1 downto 0);
      branch_active_input             : in  std_logic;
      branch_destination_input        : in  std_logic_vector(WORD_WIDTH-1 downto 0));
  end component if_stage;
  signal instr_reqvalid_id_output        : std_logic;
  signal instr_reqdata_id_output         : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal instr_program_counter_id_output : std_logic_vector(WORD_WIDTH-1 downto 0);

  component id_stage is
    port (
      clk                            : in  std_logic;
      rst_n                          : in  std_logic;
      instr_reqvalid_input           : in  std_logic;
      instr_reqdata_input            : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      ex_alu_input_a_output          : out std_logic_vector(WORD_WIDTH-1 downto 0);
      ex_alu_input_b_output          : out std_logic_vector(WORD_WIDTH-1 downto 0);
      ex_alu_operator_output         : out std_logic_vector(ALU_OPERATOR_WIDTH-1 downto 0);
      ex_destination_register_output : out std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
      branch_active_if_output        : out std_logic;
      branch_destination_if_output   : out std_logic_vector(WORD_WIDTH-1 downto 0);
      write_enable_z_input           : in  std_logic;
      write_address_z_input          : in  std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
      write_data_z_input             : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      write_enable_y_input           : in  std_logic;
      write_address_y_input          : in  std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
      write_data_y_input             : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      pc_id_input                    : in  std_logic_vector(31 downto 0)); 
  end component id_stage;
  signal ex_alu_input_a_output          : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal ex_alu_input_b_output          : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal ex_alu_operator_output         : std_logic_vector(ALU_OPERATOR_WIDTH-1 downto 0);
  signal ex_destination_register_output : std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
  signal branch_active_if_output        : std_logic;
  signal branch_destination_if_output   : std_logic_vector(WORD_WIDTH-1 downto 0);

  component ex_stage is
    port (
      clk                        : in  std_logic;
      rst_n                      : in  std_logic;
      alu_input_a_input          : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      alu_input_b_input          : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      alu_operator_input         : in  std_logic_vector(ALU_OPERATOR_WIDTH-1 downto 0);
      write_enable_z_output      : out std_logic;
      write_address_z_output     : out std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
      write_data_z_output        : out std_logic_vector(WORD_WIDTH-1 downto 0);
      destination_register_input : in  std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0));
  end component ex_stage;
  signal alu_input_a_input          : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal alu_input_b_input          : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal alu_operator_input         : std_logic_vector(ALU_OPERATOR_WIDTH-1 downto 0);
  signal destination_register_input : std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
  signal write_enable_z_output      : std_logic;
  signal write_address_z_output     : std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
  signal write_data_z_output        : std_logic_vector(WORD_WIDTH-1 downto 0);


  signal write_enable_y_output      : std_logic;
  signal write_address_y_output     : std_logic_vector(GPR_ADDRESS_WIDTH-1 downto 0);
  signal write_data_y_output        : std_logic_vector(WORD_WIDTH-1 downto 0);

begin  -- architecture behavioural

  stage_if : entity lib_vhdl.if_stage
    port map (
      clk                             => clk,
      rst_n                           => rst_n,
      instr_requisition_output        => instr_requisition_output,
      instr_address_output            => instr_address_output,
      instr_grant_input               => instr_grant_input,
      instr_reqvalid_input            => instr_reqvalid_input,
      instr_reqdata_input             => instr_reqdata_input,
      instr_reqvalid_id_output        => instr_reqvalid_id_output,
      instr_reqdata_id_output         => instr_reqdata_id_output,
      instr_program_counter_id_output => instr_program_counter_id_output,
      branch_active_input             => branch_active_if_output,
      branch_destination_input        => branch_destination_if_output);

  stage_id : entity lib_vhdl.id_stage
    port map (
      clk                            => clk,
      rst_n                          => rst_n,
      instr_reqvalid_input           => instr_reqvalid_id_output,
      instr_reqdata_input            => instr_reqdata_id_output,
      ex_alu_input_a_output          => ex_alu_input_a_output,
      ex_alu_input_b_output          => ex_alu_input_b_output,
      ex_alu_operator_output         => ex_alu_operator_output,
      ex_destination_register_output => ex_destination_register_output,
      branch_active_if_output        => branch_active_if_output,
      branch_destination_if_output   => branch_destination_if_output,
      write_enable_z_input           => write_enable_z_output,
      write_address_z_input          => write_address_z_output,
      write_data_z_input             => write_data_z_output,
      write_enable_y_input           => write_enable_y_output,
      write_address_y_input          => write_address_y_output,
      write_data_y_input             => write_data_y_output,
      pc_id_input                    => instr_program_counter_id_output);

  stage_ex : entity lib_vhdl.ex_stage
    port map (
      clk                        => clk,
      rst_n                      => rst_n,
      alu_input_a_input          => ex_alu_input_a_output,
      alu_input_b_input          => ex_alu_input_b_output,
      alu_operator_input         => ex_alu_operator_output,
      write_enable_z_output      => write_enable_z_output,
      write_address_z_output     => write_address_z_output,
      write_data_z_output        => write_data_z_output,
      destination_register_input => ex_destination_register_output);

end architecture behavioural;
