library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lib_vhdl;
use lib_vhdl.phelmino_definitions.all;

entity if_stage is

  port (
    -- clock and reset signals
    clk   : in std_logic;
    rst_n : in std_logic;

    -- instruction interface signals
    instr_requisition : out std_logic;
    instr_address     : out std_logic_vector(WORD_WIDTH-1 downto 0);
    instr_grant       : in  std_logic;
    instr_reqvalid    : in  std_logic;
    instr_reqdata     : in  std_logic_vector(WORD_WIDTH-1 downto 0);

    -- data output to id stage
    instruction_id : out std_logic_vector(WORD_WIDTH-1 downto 0);
    pc_id          : out std_logic_vector(WORD_WIDTH-1 downto 0);

    -- branch signals
    branch_active      : in std_logic;
    branch_destination : in std_logic_vector(WORD_WIDTH-1 downto 0);

    -- pipeline control signals
    ready : in std_logic);

end entity if_stage;

architecture behavioural of if_stage is
  signal current_pc                 : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal current_waiting_pc         : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal current_branch_destination : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal write_enable               : std_logic;
  signal read_enable                : std_logic;

  signal next_pc                : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal next_waiting_pc        : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal next_instr_requisition : std_logic;

  signal current_waiting_for_memory : std_logic;
  signal next_waiting_for_memory    : std_logic;

  signal empty : std_logic;
  signal full  : std_logic;

  type origin_instruction is (from_fifo, bubble);
  signal current_origin_instruction : origin_instruction;
  signal next_origin_instruction    : origin_instruction;

  component fifo is
    generic (
      addr_width : natural;
      data_width : natural);
    port (
      clk          : in  std_logic;
      enable       : in  std_logic;
      rst_n        : in  std_logic;
      clear        : in  std_logic;
      write_enable : in  std_logic;
      data_input   : in  std_logic_vector(data_width-1 downto 0);
      read_enable  : in  std_logic;
      data_output  : out std_logic_vector(data_width-1 downto 0);
      empty        : out std_logic;
      full         : out std_logic);
  end component fifo;

  -- fifo should store the instruction and its pc.
  signal fifo_input  : std_logic_vector(2*WORD_WIDTH-1 downto 0);
  signal fifo_output : std_logic_vector(2*WORD_WIDTH-1 downto 0);

  signal next_instruction_id : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal next_pc_id          : std_logic_vector(WORD_WIDTH-1 downto 0);

begin  -- architecture behavioural
  instr_address <= current_pc;
  fifo_input    <= current_waiting_pc & instr_reqdata;

  -- instance "prefetch_buffer"
  prefetch_buffer : entity lib_vhdl.fifo
    generic map (
      addr_width => PREFETCH_ADDRESS_WIDTH,
      data_width => 2 * WORD_WIDTH)
    port map (
      clk          => clk,
      enable       => ready,
      rst_n        => rst_n,
      clear        => branch_active,
      write_enable => write_enable,
      data_input   => fifo_input,
      read_enable  => read_enable,
      data_output  => fifo_output,
      empty        => empty,
      full         => full);

  interface_memory : process (clk, rst_n) is
  begin  -- process sequential
    if rst_n = '0' then                 -- asynchronous reset (active low)
      current_pc                 <= (others => '0');
      current_waiting_pc         <= (others => '0');
      current_waiting_for_memory <= '0';
      instr_requisition          <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      current_pc                 <= next_pc;
      current_waiting_pc         <= next_waiting_pc;
      current_waiting_for_memory <= next_waiting_for_memory;
      instr_requisition          <= next_instr_requisition;
    end if;
  end process interface_memory;

  interface_id : process (clk, ready, rst_n) is
  begin  -- process interface_id
    if rst_n = '0' then                 -- asynchronous reset (active low)
      pc_id                      <= (others => '0');
      instruction_id             <= NOP;
      current_branch_destination <= (others => '0');
      current_origin_instruction <= bubble;
    elsif clk'event and clk = '1' and ready = '1' then  -- rising clock edge
      pc_id                      <= next_pc_id;
      instruction_id             <= next_instruction_id;
      current_branch_destination <= branch_destination;
      current_origin_instruction <= next_origin_instruction;
    end if;
  end process interface_id;

  combinational : process (branch_active, current_branch_destination,
                           current_origin_instruction, current_pc,
                           current_waiting_for_memory, current_waiting_pc,
                           empty,
                           fifo_output(2*WORD_WIDTH-1 downto WORD_WIDTH),
                           fifo_output(WORD_WIDTH-1 downto 0), full,
                           instr_grant, instr_reqvalid, ready) is
  begin  -- process combinational
    -- output to stage id
    case current_origin_instruction is
      when bubble =>
        next_instruction_id <= NOP;
        next_pc_id          <= (others => '0');

      when from_fifo =>
        next_pc_id          <= fifo_output(2*WORD_WIDTH-1 downto WORD_WIDTH);
        next_instruction_id <= fifo_output(WORD_WIDTH-1 downto 0);
    end case;

    case branch_active is
      when '1' =>
        next_pc                 <= current_branch_destination;
        next_waiting_pc         <= current_branch_destination;
        next_origin_instruction <= bubble;
        next_instr_requisition  <= '1';
        read_enable             <= '0';
        write_enable            <= '0';
        next_waiting_for_memory <= '0';
      when others =>
        next_instr_requisition <= '1';

        -- received a grant, starts new requisition after a cycle
        if (full = '0' and instr_grant = '1') then
          next_pc                 <= std_logic_vector(unsigned(current_pc) + WORD_WIDTH_IN_BYTES);
          next_waiting_for_memory <= '1';
        -- still no grant, maintains request
        else
          next_pc                 <= current_pc;
          next_waiting_for_memory <= current_waiting_for_memory;
        end if;

        -- received valid, can store new instruction in fifo
        if (full = '0' and instr_reqvalid = '1' and current_waiting_for_memory = '1') then
          next_waiting_pc <= current_pc;
          write_enable    <= '1';
        -- still waiting for a valid, maintains counter.
        else
          next_waiting_pc <= current_waiting_pc;
          write_enable    <= '0';
        end if;

        -- stage id is ready and fifo is not empty. 
        if (empty = '0') then
          read_enable             <= '1';
          next_origin_instruction <= from_fifo;
        -- stage id is ready, but fifo is empty. sends a bubble.
        else
          read_enable             <= '0';
          next_origin_instruction <= bubble;
        end if;
    end case;

  end process combinational;
end architecture behavioural;
