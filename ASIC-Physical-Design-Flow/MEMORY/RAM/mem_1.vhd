--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
--%%                      Centre for Development of Advanced Computing                            %%
--%%                           Vellayambalam, Thiruvananthapuram.                                 %%
--%%==============================================================================================%%
--%%  Copyright (c) 2024 C-DAC. ALL RIGHTS RESERVED                                              %%
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
--%%  Project  Name    : Development of 32-bit RISC-V processor (RV32IM)                         %%
--%%  File Name        : mem_1.vhd                                                               %%
--%%  Title            : mem_1 - Program Memory (Synthesisable replacement for Xilinx block_mem) %%
--%%  Author           : vega@cdac.in                                                            %%
--%%  Description      : True dual-port synchronous RAM - 128K x 32-bit = 512KB                 %%
--%%                     Port A : Instruction fetch (read/write)                                 %%
--%%                     Port B : Data read/write                                                %%
--%%                     addra/addrb are 19-bit from sys_top but only [18:2] used                %%
--%%                     (word-addressed, matches original block_mem_1 port map)                 %%
--%%                     Byte write enable via wea[3:0] / web[3:0]                               %%
--%%                     Synthesisable for Cadence Genus / SCL or Faraday 180nm                  %%
--%%                     Genus will infer this as flip-flop array or map to SRAM if available    %%
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_1 is
    port (
        clka  : in  std_logic;
        ena   : in  std_logic;
        wea   : in  std_logic_vector(3 downto 0);
        addra : in  std_logic_vector(18 downto 0);
        dina  : in  std_logic_vector(31 downto 0);
        douta : out std_logic_vector(31 downto 0);
        clkb  : in  std_logic;
        enb   : in  std_logic;
        web   : in  std_logic_vector(3 downto 0);
        addrb : in  std_logic_vector(18 downto 0);
        dinb  : in  std_logic_vector(31 downto 0);
        doutb : out std_logic_vector(31 downto 0)
    );
end mem_1;

architecture mem_1_a of mem_1 is

    -- 128K words x 32 bits = 512KB program memory
    -- Address bits [18:2] are used (word addressed), giving 2^17 = 131072 locations
    constant MEM_DEPTH : integer := 131072;

    type ram_type is array(0 to MEM_DEPTH-1) of std_logic_vector(31 downto 0);

    -- Shared RAM array (true dual-port)
    shared variable mem : ram_type := (others => (others => '0'));

    -- Internal address signals (word addressed - strip byte offset bits [1:0])
    signal addr_a_word : std_logic_vector(16 downto 0);
    signal addr_b_word : std_logic_vector(16 downto 0);

begin

    -- Word address = addra[18:2]
    addr_a_word <= addra(18 downto 2);
    addr_b_word <= addrb(18 downto 2);

    ---------------------------------------------------------------------------
    -- Port A: synchronous read/write with byte enables
    ---------------------------------------------------------------------------
    process(clka)
    begin
        if rising_edge(clka) then
            if ena = '1' then
                -- Byte write enables
                if wea(0) = '1' then
                    mem(to_integer(unsigned(addr_a_word)))(7 downto 0)
                        := dina(7 downto 0);
                end if;
                if wea(1) = '1' then
                    mem(to_integer(unsigned(addr_a_word)))(15 downto 8)
                        := dina(15 downto 8);
                end if;
                if wea(2) = '1' then
                    mem(to_integer(unsigned(addr_a_word)))(23 downto 16)
                        := dina(23 downto 16);
                end if;
                if wea(3) = '1' then
                    mem(to_integer(unsigned(addr_a_word)))(31 downto 24)
                        := dina(31 downto 24);
                end if;
                -- Read (read-first mode)
                douta <= mem(to_integer(unsigned(addr_a_word)));
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Port B: synchronous read/write with byte enables
    ---------------------------------------------------------------------------
    process(clkb)
    begin
        if rising_edge(clkb) then
            if enb = '1' then
                -- Byte write enables
                if web(0) = '1' then
                    mem(to_integer(unsigned(addr_b_word)))(7 downto 0)
                        := dinb(7 downto 0);
                end if;
                if web(1) = '1' then
                    mem(to_integer(unsigned(addr_b_word)))(15 downto 8)
                        := dinb(15 downto 8);
                end if;
                if web(2) = '1' then
                    mem(to_integer(unsigned(addr_b_word)))(23 downto 16)
                        := dinb(23 downto 16);
                end if;
                if web(3) = '1' then
                    mem(to_integer(unsigned(addr_b_word)))(31 downto 24)
                        := dinb(31 downto 24);
                end if;
                -- Read (read-first mode)
                doutb <= mem(to_integer(unsigned(addr_b_word)));
            end if;
        end if;
    end process;

end mem_1_a;
