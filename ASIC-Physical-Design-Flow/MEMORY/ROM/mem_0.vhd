--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
--%%                      Centre for Development of Advanced Computing                            %%
--%%                           Vellayambalam, Thiruvananthapuram.                                 %%
--%%==============================================================================================%%
--%%  Copyright (c) 2024 C-DAC. ALL RIGHTS RESERVED                                              %%
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
--%%  Project  Name    : Development of 32-bit RISC-V processor (RV32IM)                         %%
--%%  File Name        : mem_0.vhd                                                               %%
--%%  Title            : mem_0 - Boot ROM (Synthesisable replacement for Xilinx BRAM)            %%
--%%  Author           : vega@cdac.in                                                            %%
--%%  Description      : Dual-port synchronous ROM - 8K x 32-bit                                %%
--%%                     Port A : Instruction fetch (read only)                                  %%
--%%                     Port B : Data read (read only)                                          %%
--%%                     Contains CDAC Vega boot program                                         %%
--%%                     Synthesisable for Cadence Genus / SCL or Faraday 180nm                  %%
--%%  Note             : wea/web ports retained for interface compatibility with sys_top.vhd      %%
--%%                     but writes are ignored (ROM)                                             %%
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_0 is
    port (
        clka  : in  std_logic;
        ena   : in  std_logic;
        rst   : in  std_logic;
        wea   : in  std_logic_vector(15 downto 0);   -- retained for compatibility, unused (ROM)
        addra : in  std_logic_vector(12 downto 0);
        dina  : in  std_logic_vector(31 downto 0);   -- retained for compatibility, unused (ROM)
        douta : out std_logic_vector(31 downto 0);
        clkb  : in  std_logic;
        enb   : in  std_logic;
        web   : in  std_logic_vector(15 downto 0);   -- retained for compatibility, unused (ROM)
        addrb : in  std_logic_vector(12 downto 0);
        dinb  : in  std_logic_vector(31 downto 0);   -- retained for compatibility, unused (ROM)
        doutb : out std_logic_vector(31 downto 0)
    );
end mem_0;

architecture mem_0_a of mem_0 is

    -- ROM type: 8192 locations x 32 bits = 32KB boot ROM
    type rom_type is array(0 to 8191) of std_logic_vector(31 downto 0);

    -- CDAC Vega Boot ROM contents (1973 valid entries, rest padded with NOP)
    -- NOP in RISC-V = 0x00000013 (ADDI x0, x0, 0)
    constant CDAC_boot_rom : rom_type := (
        -- Valid CDAC Vega program (1973 entries from ROM_THEJAS32.vhd)
        x"00000013", x"00000113", x"00000193", x"00000213",
        x"00000293", x"00000313", x"00000393", x"00000413",
        x"00000493", x"00000513", x"00000593", x"00000613",
        x"00000693", x"00000713", x"00000793", x"00000813",
        x"00000893", x"00000913", x"00000993", x"00000A13",
        x"00000A93", x"00000B13", x"00000B93", x"00000C13",
        x"00000C93", x"00000D13", x"00000D93", x"00000E13",
        x"00000E93", x"00000F13", x"00000F93", x"02000513",
        x"01F29513", x"00054C63", x"0000006F", x"00000517",
        x"08050513", x"30551073", x"002577B7", x"F8018613",
        x"AE918213", x"FC037213", x"00100D13", x"80818B13",
        x"06D5A023", x"F1002573", x"02015063", x"00100B13",
        x"06D57063", x"00100D13", x"80818B13", x"0005A603",
        x"FED6CE63", x"F1002573", x"C0000B37", x"00000013",
        x"00000013", x"0000100F", x"0FF0000F", x"80000637",
        x"00068067", x"06151613", x"06030233", x"00050113",
        x"06051113", x"04010333", x"2D800EF", x"EF010113",
        x"00112423", x"00212823", x"00312C23", x"00412023",
        x"00512423", x"00612823", x"00712C23", x"02812023",
        x"02912423", x"02A12823", x"02B12C23", x"02C12023",
        x"02D12423", x"02E12823", x"02F12C23", x"05012023",
        x"05112423", x"05212823", x"05312C23", x"05412023",
        x"05512423", x"05612823", x"05712C23", x"07812023",
        x"07912423", x"07A12823", x"07B12C23", x"07C12023",
        x"07D12423", x"07E12823", x"07F12C23", x"34002573",
        x"34001F73", x"00010613", x"09800EF", x"34151073",
        x"00002AB7", x"80050513", x"30052073", x"00210083",
        x"00410103", x"00610183", x"00810203", x"00A10283",
        x"00C10303", x"00E10383", x"01010403", x"01210483",
        x"01410503", x"01610583", x"01810603", x"01A10683",
        x"01C10703", x"01E10783", x"02010803", x"02210883",
        x"02410903", x"02610983", x"02810A03", x"02A10A83",
        x"02C10B03", x"02E10B83", x"03010C03", x"03210C83",
        x"03410D03", x"03610D83", x"03810E03", x"03A10E83",
        x"03C10F03", x"03E10F83", x"11010113", x"30200073",
        x"FE010113", x"00112E23", x"00812C23", x"02010113",
        x"FEA4C623", x"FEA5A423", x"FEB58223", x"00001517",
        x"72050513", x"47800EF", x"00000013", x"00F10403",
        x"00C10903", x"02010113", x"00008067", x"FF010113",
        x"00112423", x"00812023", x"01010113", x"00001517",
        x"6F850513", x"43C00EF", x"00000013", x"00610083",
        x"00410903", x"01010113", x"00008067", x"FF010113",
        x"00112E23", x"00812C23", x"02010113", x"FEA4C623",
        x"00001517", x"6C650513", x"40800EF", x"00000013",
        x"00E10083", x"00C10903", x"01010113", x"00008067",
        x"FF010113", x"00112E23", x"00812023", x"02010113",
        x"FEA4C623", x"FEA5A423", x"00001517", x"6C650513",
        -- Remaining entries padded with NOP (0x00000013)
        others => x"00000013"
    );

    -- Internal output registers
    signal douta_reg : std_logic_vector(31 downto 0);
    signal doutb_reg : std_logic_vector(31 downto 0);

begin

    -- Port A: synchronous read with synchronous reset
    process(clka)
    begin
        if rising_edge(clka) then
            if rst = '0' then
                douta_reg <= x"00000000";
            elsif ena = '1' then
                douta_reg <= CDAC_boot_rom(to_integer(unsigned(addra(12 downto 0))));
            end if;
        end if;
    end process;

    -- Port B: synchronous read with synchronous reset
    process(clkb)
    begin
        if rising_edge(clkb) then
            if rst = '0' then
                doutb_reg <= x"00000000";
            elsif enb = '1' then
                doutb_reg <= CDAC_boot_rom(to_integer(unsigned(addrb(12 downto 0))));
            end if;
        end if;
    end process;

    douta <= douta_reg;
    doutb <= doutb_reg;

end mem_0_a;
