--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
--%%                      Centre for Development of Advanced Computing                            %%
--%%                           Vellayambalam, Thiruvananthapuram.                                 %%
--%%==============================================================================================%%
--%%  Copyright (c) 2024 C-DAC. ALL RIGHTS RESERVED                                              %%
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
--%%  Project  Name    : Development of 32-bit RISC-V processor (RV32IM)                         %%
--%%  File Name        : sys_top.vhd                                                              %%
--%%  Title            : System Top - ASIC Synthesisable Version                                 %%
--%%  Author           : vega@cdac.in                                                             %%
--%%  Description      : Integrates ET1035 RISC-V processor with:                                %%
--%%                     UART, GPIO, SPI, I2C, PWM peripherals                                   %%
--%%                     Boot ROM (mem_0), Program Memory (mem_1)                                %%
--%%                     PLIC interrupt controller                                                %%
--%%                     Rewritten for Cadence Genus / Innovus / SCL-Faraday 180nm               %%
--%%  Changes from original:                                                                      %%
--%%    1. Removed ieee.std_logic_arith, std_logic_unsigned → numeric_std only                   %%
--%%    2. Removed ieee.std_logic_textio, STD.textio (simulation only)                           %%
--%%    3. Removed file write signals (simulation only)                                           %%
--%%    4. clk_wiz_0 replaced with synthesisable pass-through version                            %%
--%%    5. SDN_INV_S_16 replaced with synthesisable inverter version                             %%
--%%    6. work.constants package removed (inlined constants below)                              %%
--%%    7. st_pin15 process made clocked properly                                                 %%
--%%    8. All signal declarations preserved exactly                                              %%
--%%    9. All address decode, port maps preserved exactly                                        %%
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sys_top is
    port (
        clk_in_p              : in    std_logic;
        rst                   : in    std_logic;
        proc_beat             : out   std_logic;
        -- UART
        RX                    : in    std_logic;
        TX                    : out   std_logic;
        -- GPIO
        st_pin0               : inout std_logic;
        st_pin1               : inout std_logic;
        st_pin2               : inout std_logic;
        st_pin3               : inout std_logic;
        st_pin4               : inout std_logic;
        st_pin5               : inout std_logic;
        st_pin6               : inout std_logic;
        st_pin7               : inout std_logic;
        st_pin8               : inout std_logic;
        st_pin9               : inout std_logic;
        st_pin10              : inout std_logic;
        st_pin11              : inout std_logic;
        st_pin12              : inout std_logic;
        st_pin13              : inout std_logic;
        st_pin14              : inout std_logic;
        st_pin15              : inout std_logic;
        -- SPI
        miso                  : in    std_logic;
        sck                   : out   std_logic;
        mosi                  : out   std_logic;
        ss                    : out   std_logic;
        -- I2C
        scl                   : inout std_logic;
        sda                   : inout std_logic
    );
end sys_top;

architecture sys_top_a of sys_top is

    ---------------------------------------------------------------------------
    -- Component Declarations
    ---------------------------------------------------------------------------

    component ET1035_top
    port (
        clk                   : in  std_logic;
        rst                   : in  std_logic;
        wait_n                : in  std_logic;
        reset_addr            : in  std_logic_vector(31 downto 0);
        imem_req              : out std_logic;
        imem_seq              : out std_logic;
        imem_addr             : out std_logic_vector(31 downto 0);
        imem_data_in          : in  std_logic_vector(31 downto 0);
        imem_access_fault     : in  std_logic;
        dmem_req              : out std_logic;
        dmem_rw               : out std_logic;
        dmem_size             : out std_logic_vector(2 downto 0);
        dmem_addr             : out std_logic_vector(31 downto 0);
        dmem_data_in          : in  std_logic_vector(31 downto 0);
        dmem_data_out         : out std_logic_vector(31 downto 0);
        load_access_fault     : in  std_logic;
        load_addr_mis_align   : in  std_logic;
        store_access_fault    : in  std_logic;
        store_addr_mis_align  : in  std_logic;
        timer_interrupt       : in  std_logic;
        ext_interrupt         : in  std_logic
    );
    end component;

    component uart_top
    port (
        clk                   : in  std_logic;
        mr                    : in  std_logic;
        cs                    : in  std_logic;
        a                     : in  std_logic_vector(2 downto 0);
        rd                    : in  std_logic;
        wr                    : in  std_logic;
        sin                   : in  std_logic;
        din                   : in  std_logic_vector(7 downto 0);
        dout                  : out std_logic_vector(7 downto 0);
        sout                  : out std_logic;
        ddis                  : out std_logic;
        intr                  : out std_logic;
        baudout_n             : out std_logic;
        rxrdy_n               : out std_logic;
        txrdy_n               : out std_logic
    );
    end component;

    component gpio_chip
    port (
        PCLK                  : in    std_logic;
        PRESETn               : in    std_logic;
        PSEL                  : in    std_logic;
        PWrite                : in    std_logic;
        PADDR                 : in    std_logic_vector(7 downto 0);
        PWDATA                : in    std_logic_vector(15 downto 0);
        PRDATA                : out   std_logic_vector(15 downto 0);
        pin0                  : inout std_logic;
        pin1                  : inout std_logic;
        pin2                  : inout std_logic;
        pin3                  : inout std_logic;
        pin4                  : inout std_logic;
        pin5                  : inout std_logic;
        pin6                  : inout std_logic;
        pin7                  : inout std_logic;
        pin8                  : inout std_logic;
        pin9                  : inout std_logic;
        pin10                 : inout std_logic;
        pin11                 : inout std_logic;
        pin12                 : inout std_logic;
        pin13                 : inout std_logic;
        pin14                 : inout std_logic;
        pin15                 : inout std_logic
    );
    end component;

    component spi_top
    port (
        PCLK                  : in  std_logic;
        PRESETn               : in  std_logic;
        PSEL                  : in  std_logic;
        PENABLE               : in  std_logic;
        PWrite                : in  std_logic;
        PADDR                 : in  std_logic_vector(7 downto 0);
        PWDATA                : in  std_logic_vector(31 downto 0);
        miso                  : in  std_logic;
        PRDATA                : out std_logic_vector(31 downto 0);
        ss                    : out std_logic;
        sclk                  : out std_logic;
        mosi                  : out std_logic
    );
    end component;

    component i2c_top
    port (
        PCLK                  : in    std_logic;
        PRESETn               : in    std_logic;
        PSEL                  : in    std_logic;
        PENABLE               : in    std_logic;
        PWRITE                : in    std_logic;
        PADDR                 : in    std_logic_vector(7 downto 0);
        PWDATA                : in    std_logic_vector(7 downto 0);
        PRDATA                : out   std_logic_vector(7 downto 0);
        i2c_sda               : inout std_logic;
        i2c_scl               : inout std_logic
    );
    end component;

    component pwm
    port (
        PCLK                  : in  std_logic;
        PRESETn               : in  std_logic;
        PSEL                  : in  std_logic;
        PWrite                : in  std_logic;
        PADDR                 : in  std_logic_vector(7 downto 0);
        PWDATA                : in  std_logic_vector(7 downto 0);
        PWM_OUT               : out std_logic
    );
    end component;

    component mem_0
    port (
        clka                  : in  std_logic;
        ena                   : in  std_logic;
        rst                   : in  std_logic;
        wea                   : in  std_logic_vector(15 downto 0);
        addra                 : in  std_logic_vector(12 downto 0);
        dina                  : in  std_logic_vector(31 downto 0);
        douta                 : out std_logic_vector(31 downto 0);
        clkb                  : in  std_logic;
        enb                   : in  std_logic;
        web                   : in  std_logic_vector(15 downto 0);
        addrb                 : in  std_logic_vector(12 downto 0);
        dinb                  : in  std_logic_vector(31 downto 0);
        doutb                 : out std_logic_vector(31 downto 0)
    );
    end component;

    component mem_1
    port (
        clka                  : in  std_logic;
        ena                   : in  std_logic;
        wea                   : in  std_logic_vector(3 downto 0);
        addra                 : in  std_logic_vector(18 downto 0);
        dina                  : in  std_logic_vector(31 downto 0);
        douta                 : out std_logic_vector(31 downto 0);
        clkb                  : in  std_logic;
        enb                   : in  std_logic;
        web                   : in  std_logic_vector(3 downto 0);
        addrb                 : in  std_logic_vector(18 downto 0);
        dinb                  : in  std_logic_vector(31 downto 0);
        doutb                 : out std_logic_vector(31 downto 0)
    );
    end component;

    -- Synthesisable clock inverter (replaces Xilinx SDN_INV_S_16)
    component SDN_INV_S_16
    port (
        A                     : in  std_logic;
        X                     : out std_logic
    );
    end component;

    -- Synthesisable clock pass-through (replaces Xilinx MMCM clk_wiz_0)
    component clk_wiz_0
    port (
        clk_out1              : out std_logic;
        clk_out2              : out std_logic;
        reset                 : in  std_logic;
        locked                : out std_logic;
        clk_in1               : in  std_logic
    );
    end component;

    ---------------------------------------------------------------------------
    -- Signal Declarations — preserved exactly from original
    ---------------------------------------------------------------------------
    signal dmem_size          : std_logic_vector(2 downto 0);
    signal web_rw             : std_logic;
    signal addra              : std_logic_vector(31 downto 0);
    signal douta              : std_logic_vector(31 downto 0);
    signal inst_data          : std_logic_vector(31 downto 0);
    signal web                : std_logic_vector(15 downto 0);
    signal addrb              : std_logic_vector(31 downto 0);
    signal dinb               : std_logic_vector(31 downto 0);
    signal doutb              : std_logic_vector(31 downto 0);
    signal din_mux            : std_logic_vector(31 downto 0);
    signal data_out           : std_logic_vector(31 downto 0);
    signal dmem_cs            : std_logic;
    signal plic_cs            : std_logic;
    signal rom_cs             : std_logic;
    signal pm_mem_cs          : std_logic;
    signal clk_n              : std_logic;
    signal wait_n             : std_logic;
    signal uart_intr0         : std_logic;
    signal mtime_intr         : std_logic;
    signal ena                : std_logic;
    signal enb                : std_logic;
    signal pm_web             : std_logic_vector(3 downto 0);
    signal pm_douta           : std_logic_vector(31 downto 0);
    signal pm_doutb           : std_logic_vector(31 downto 0);
    signal prdata_plic        : std_logic_vector(31 downto 0);
    signal ext_intr           : std_logic;
    signal raw_interrupt      : std_logic_vector(31 downto 0);
    signal enable_interrupt   : std_logic_vector(31 downto 0);
    signal status_interrupt   : std_logic_vector(31 downto 0);
    signal mtime_ext          : std_logic_vector(63 downto 0);
    signal mtimecmp_ext       : std_logic_vector(63 downto 0);
    signal mtime_count        : std_logic_vector(11 downto 0);
    signal reset              : std_logic;
    signal fromhost_rd        : std_logic;
    signal reset_n            : std_logic;
    signal reset_signal       : std_logic;
    signal proc_beat_signal   : std_logic;
    signal proc_beat_count    : std_logic_vector(23 downto 0);
    signal prdata_bootreg     : std_logic_vector(31 downto 0);
    signal port_boot_signal   : std_logic_vector(3 downto 0);
    signal load_addr_mis_align_s  : std_logic;
    signal load_access_fault_s    : std_logic;
    signal store_access_fault_s   : std_logic;
    signal store_addr_mis_align_s : std_logic;
    signal imem_access_fault_s    : std_logic;
    signal fromhost_wr        : std_logic;
    signal tohost_wr          : std_logic;
    signal clk_p              : std_logic;
    signal reset_inv          : std_logic;
    signal rst_in             : std_logic;
    -- UART signals
    signal uart_dout0         : std_logic_vector(7 downto 0);
    signal uart_cs0           : std_logic;
    signal uart_rd0           : std_logic;
    signal uart_wr0           : std_logic;
    -- GPIO signals
    signal gpio_dout          : std_logic_vector(15 downto 0);
    signal gpio_cs            : std_logic;
    signal gpio_rw            : std_logic;
    -- SPI signals
    signal spi_dout           : std_logic_vector(31 downto 0);
    signal spi_cs             : std_logic;
    signal spi_rw             : std_logic;
    -- I2C signals
    signal i2c_dout           : std_logic_vector(7 downto 0);
    signal i2c_cs             : std_logic;
    signal i2c_rw             : std_logic;
    -- PWM signals
    signal pwm_cs             : std_logic;
    signal pwm_rw             : std_logic;
    signal st_pin15_mux       : std_logic;
    signal gpio_pin15         : std_logic;
    signal pwm_pin            : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Processor instantiation
    ---------------------------------------------------------------------------
    u_processor: ET1035_top port map (
        clk                   => clk_p,
        rst                   => reset,
        wait_n                => wait_n,
        reset_addr            => x"00010000",
        imem_req              => ena,
        imem_seq              => open,
        imem_addr             => addra,
        imem_data_in          => inst_data,
        imem_access_fault     => '0',
        dmem_req              => enb,
        dmem_rw               => web_rw,
        dmem_size             => dmem_size,
        dmem_addr             => addrb,
        dmem_data_in          => din_mux,
        dmem_data_out         => data_out,
        load_access_fault     => '0',
        load_addr_mis_align   => load_addr_mis_align_s,
        store_access_fault    => '0',
        store_addr_mis_align  => store_addr_mis_align_s,
        timer_interrupt       => mtime_intr,
        ext_interrupt         => ext_intr
    );

    ---------------------------------------------------------------------------
    -- UART instantiation
    ---------------------------------------------------------------------------
    u_uart_0: uart_top port map (
        clk                   => clk_n,
        mr                    => reset,
        cs                    => uart_cs0,
        a                     => addrb(4 downto 2),
        rd                    => uart_rd0,
        wr                    => uart_wr0,
        sin                   => RX,
        din                   => dinb(7 downto 0),
        dout                  => uart_dout0,
        sout                  => TX,
        ddis                  => open,
        intr                  => uart_intr0,
        baudout_n             => open,
        rxrdy_n               => open,
        txrdy_n               => open
    );

    ---------------------------------------------------------------------------
    -- GPIO instantiation
    ---------------------------------------------------------------------------
    gpio_top: gpio_chip port map (
        PCLK                  => clk_n,
        PRESETn               => reset,
        PSEL                  => gpio_cs,
        PADDR                 => addrb(7 downto 0),
        PWrite                => gpio_rw,
        PWDATA                => dinb(15 downto 0),
        PRDATA                => gpio_dout,
        pin0                  => st_pin0,
        pin1                  => st_pin1,
        pin2                  => st_pin2,
        pin3                  => st_pin3,
        pin4                  => st_pin4,
        pin5                  => st_pin5,
        pin6                  => st_pin6,
        pin7                  => st_pin7,
        pin8                  => st_pin8,
        pin9                  => st_pin9,
        pin10                 => st_pin10,
        pin11                 => st_pin11,
        pin12                 => st_pin12,
        pin13                 => st_pin13,
        pin14                 => st_pin14,
        pin15                 => gpio_pin15
    );

    ---------------------------------------------------------------------------
    -- SPI instantiation
    ---------------------------------------------------------------------------
    u_spi: spi_top port map (
        PRESETn               => reset,
        PCLK                  => clk_n,
        PENABLE               => enb,
        PSEL                  => spi_cs,
        PADDR                 => addrb(7 downto 0),
        PWrite                => spi_rw,
        PWDATA                => dinb,
        miso                  => miso,
        PRDATA                => spi_dout,
        ss                    => ss,
        sclk                  => sck,
        mosi                  => mosi
    );

    ---------------------------------------------------------------------------
    -- I2C instantiation
    ---------------------------------------------------------------------------
    u_i2c: i2c_top port map (
        PCLK                  => clk_n,
        PRESETn               => reset,
        PSEL                  => i2c_cs,
        PADDR                 => addrb(7 downto 0),
        PWrite                => i2c_rw,
        PWDATA                => dinb(7 downto 0),
        PRDATA                => i2c_dout,
        PENABLE               => enb,
        i2c_scl               => scl,
        i2c_sda               => sda
    );

    ---------------------------------------------------------------------------
    -- PWM instantiation
    ---------------------------------------------------------------------------
    u_pwm: pwm port map (
        PCLK                  => clk_n,
        PRESETn               => reset,
        PSEL                  => pwm_cs,
        PADDR                 => addrb(7 downto 0),
        PWrite                => pwm_rw,
        PWDATA                => dinb(7 downto 0),
        PWM_OUT               => pwm_pin
    );

    ---------------------------------------------------------------------------
    -- Boot ROM (mem_0)
    ---------------------------------------------------------------------------
    boot_mem: mem_0 port map (
        clka                  => clk_n,
        wea                   => "0000000000000000",
        rst                   => reset_n,
        ena                   => rom_cs,
        addra                 => addra(14 downto 2),
        dina                  => x"00000000",
        douta                 => douta,
        clkb                  => clk_n,
        web                   => "0000000000000000",
        enb                   => dmem_cs,
        addrb                 => addrb(14 downto 2),
        dinb                  => x"00000000",
        doutb                 => doutb
    );

    ---------------------------------------------------------------------------
    -- Program Memory (mem_1)
    ---------------------------------------------------------------------------
    program_mem: mem_1 port map (
        clka                  => clk_n,
        ena                   => ena,
        wea                   => "0000",
        addra                 => addra(18 downto 0),
        dina                  => x"00000000",
        douta                 => pm_douta,
        clkb                  => clk_n,
        enb                   => pm_mem_cs,
        web                   => pm_web,
        addrb                 => addrb(18 downto 0),
        dinb                  => data_out,
        doutb                 => pm_doutb
    );

    ---------------------------------------------------------------------------
    -- Clock inverter (synthesisable SDN_INV_S_16)
    ---------------------------------------------------------------------------
    clock_inv: SDN_INV_S_16 port map (
        A                     => clk_p,
        X                     => clk_n
    );

    ---------------------------------------------------------------------------
    -- Clock wizard (synthesisable clk_wiz_0 - pass-through for ASIC)
    ---------------------------------------------------------------------------
    u_mmcm: clk_wiz_0 port map (
        clk_out1              => clk_p,
        clk_out2              => open,
        reset                 => reset_inv,
        locked                => rst_in,
        clk_in1               => clk_in_p
    );

    ---------------------------------------------------------------------------
    -- Concurrent signal assignments — preserved exactly from original
    ---------------------------------------------------------------------------
    reset_inv   <= not rst;
    wait_n      <= '1';
    reset_n     <= not reset;
    dinb        <= data_out;

    rom_cs      <= '1' when ((addra(31 downto 16) = "0000000000000001") and (ena = '1')) else '0';

    inst_data   <= pm_douta when addra(31 downto 19) = "0000000000100" else douta;

    pm_web      <= "1111" when web_rw = '1' and dmem_size = "010" else
                   "0011" when web_rw = '1' and dmem_size = "001" and addrb(1 downto 0) = "00" else
                   "1100" when web_rw = '1' and dmem_size = "001" and addrb(1 downto 0) = "10" else
                   "0001" when web_rw = '1' and dmem_size = "000" and addrb(1 downto 0) = "00" else
                   "0010" when web_rw = '1' and dmem_size = "000" and addrb(1 downto 0) = "01" else
                   "0100" when web_rw = '1' and dmem_size = "000" and addrb(1 downto 0) = "10" else
                   "1000" when web_rw = '1' and dmem_size = "000" and addrb(1 downto 0) = "11" else
                   "0000";

    din_mux     <= pm_doutb                                            when pm_mem_cs = '1'  else
                   uart_dout0 & uart_dout0 & uart_dout0 & uart_dout0  when uart_rd0   = '1'  else
                   gpio_dout  & gpio_dout                              when gpio_cs    = '1'  else
                   spi_dout                                            when spi_cs     = '1'  else
                   i2c_dout   & i2c_dout   & i2c_dout   & i2c_dout    when i2c_cs     = '1'  else
                   prdata_plic                                         when plic_cs    = '1'  else
                   doutb                                               when dmem_cs    = '1'  else
                   (others => '0');

    -- Address decode — preserved exactly
    pm_mem_cs   <= '1' when (addrb(31 downto 19) = "0000000000100")  and enb = '1' else '0';
    uart_cs0    <= '1' when  addrb(31 downto 8)  = x"100001"         and enb = '1' else '0';
    gpio_cs     <= '1' when  addrb(31 downto 8)  = x"100800"         and enb = '1' else '0';
    spi_cs      <= '1' when  addrb(31 downto 8)  = x"100006"         and enb = '1' else '0';
    i2c_cs      <= '1' when  addrb(31 downto 8)  = x"100008"         and enb = '1' else '0';
    pwm_cs      <= '1' when  addrb(31 downto 8)  = x"104000"         and enb = '1' else '0';
    dmem_cs     <= '1' when  addrb(31 downto 16) = x"0001"           and enb = '1' else '0';
    plic_cs     <= '1' when  addrb(31 downto 16) = x"2001"           and enb = '1' else '0';

    uart_rd0    <= '1' when uart_cs0 = '1' and web_rw = '0' else '0';
    uart_wr0    <= '1' when uart_cs0 = '1' and web_rw = '1' else '0';
    gpio_rw     <= '1' when gpio_cs  = '1' and web_rw = '1' else '0';
    spi_rw      <= '1' when spi_cs   = '1' and web_rw = '1' else '0';
    i2c_rw      <= '1' when i2c_cs   = '1' and web_rw = '1' else '0';
    pwm_rw      <= '1' when pwm_cs   = '1' and web_rw = '1' else '0';

    fromhost_rd <= '1' when addrb = x"80001040" and enb = '1' and web_rw = '0' else '0';

    raw_interrupt <= "0000000000000000000000000000000" & uart_intr0;
    ext_intr      <= '0' when status_interrupt = x"00000000" else '1';

    -- st_pin15 mux: GPIO or PWM
    st_pin15    <= st_pin15_mux;

    ---------------------------------------------------------------------------
    -- Fault detection — preserved exactly
    ---------------------------------------------------------------------------
    imem_access_fault_s   <= '1' when
        ((ena = '1') and (addra(31 downto 15) /= "00000000000000010")) and
        ((ena = '1') and (addra(31 downto 19) /= "0000000000100"))
        else '0';

    load_addr_mis_align_s <= '1' when
        ((enb='1') and (web_rw='0') and (dmem_size="010") and (addrb(1 downto 0) /= "00")) or
        ((enb='1') and (web_rw='0') and (dmem_size="001") and
         ((addrb(1 downto 0) = "01") or (addrb(1 downto 0) = "11")))
        else '0';

    store_addr_mis_align_s <= '1' when
        ((enb='1') and (web_rw='1') and (dmem_size="010") and (addrb(1 downto 0) /= "00")) or
        ((enb='1') and (web_rw='1') and (dmem_size="001") and
         ((addrb(1 downto 0) = "01") or (addrb(1 downto 0) = "11")))
        else '0';

    load_access_fault_s   <= '1' when
        ((enb='1') and (web_rw='0') and
         (addrb(31 downto 18) /= "00000000001000") and
         (addrb(31 downto 8)  /= x"100001") and
         (addrb(31 downto 16) /= x"2001") and
         (addrb(31 downto 16) /= x"0001"))
        else '0';

    store_access_fault_s  <= '1' when
        ((enb='1') and (web_rw='1') and
         (addrb(31 downto 18) /= "00000000001000") and
         (addrb(31 downto 8)  /= x"100001") and
         (addrb(31 downto 16) /= x"2001"))
        else '0';

    ---------------------------------------------------------------------------
    -- Reset generator process
    ---------------------------------------------------------------------------
    reset_genr: process(clk_p, rst_in)
    begin
        if rst_in = '0' then
            reset        <= '1';
            reset_signal <= '1';
        elsif rising_edge(clk_p) then
            reset_signal <= '0';
            reset        <= reset_signal;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Processor heartbeat process
    ---------------------------------------------------------------------------
    proc_beat_gen: process(clk_p, rst_in)
    begin
        if rst_in = '0' then
            proc_beat_signal <= '0';
            proc_beat_count  <= (others => '0');
        elsif rising_edge(clk_p) then
            if ena = '1' then
                proc_beat_count <= std_logic_vector(
                    unsigned(proc_beat_count) + 1);
                if proc_beat_count = x"ffffff" then
                    proc_beat_signal <= not proc_beat_signal;
                end if;
            end if;
        end if;
    end process;

    proc_beat <= proc_beat_signal;

    ---------------------------------------------------------------------------
    -- st_pin15 mux process (clocked — fixes latch from original)
    ---------------------------------------------------------------------------
    pin15_mux: process(clk_n)
    begin
        if rising_edge(clk_n) then
            if addrb(31 downto 8) = x"100800" then
                st_pin15_mux <= gpio_pin15;
            else
                st_pin15_mux <= pwm_pin;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Interrupt controller / PLIC process
    ---------------------------------------------------------------------------
    int_controller: process(clk_n, reset)
    begin
        if reset = '1' then
            enable_interrupt  <= (others => '0');
            status_interrupt  <= (others => '0');
            prdata_plic       <= (others => '0');
            mtime_ext         <= (others => '0');
            mtimecmp_ext      <= (others => '1');
            mtime_count       <= (others => '0');
            mtime_intr        <= '0';
        elsif rising_edge(clk_n) then

            mtime_count <= std_logic_vector(unsigned(mtime_count) + 1);

            if mtime_count = x"f9f" then
                mtime_ext   <= std_logic_vector(unsigned(mtime_ext) + 1);
                mtime_count <= (others => '0');
            end if;

            if unsigned(mtime_ext) > unsigned(mtimecmp_ext) then
                mtime_intr <= '1';
            else
                mtime_intr <= '0';
            end if;

            -- PLIC writes
            if plic_cs = '1' and enb = '1' and web_rw = '1' then
                if    addrb = x"20010008" then enable_interrupt          <= data_out;
                elsif addrb = x"20010580" then mtime_ext(31 downto 0)   <= data_out;
                elsif addrb = x"20010584" then mtime_ext(63 downto 32)  <= data_out;
                elsif addrb = x"20010480" then mtimecmp_ext(31 downto 0)<= data_out;
                elsif addrb = x"20010484" then mtimecmp_ext(63 downto 32)<= data_out;
                end if;
            end if;

            status_interrupt <= enable_interrupt and raw_interrupt;

            -- PLIC reads
            if plic_cs = '1' and enb = '1' and web_rw = '0' then
                if    addrb = x"20010000" then prdata_plic <= raw_interrupt;
                elsif addrb = x"20010008" then prdata_plic <= enable_interrupt;
                elsif addrb = x"20010010" then prdata_plic <= status_interrupt;
                elsif addrb = x"20010580" then prdata_plic <= mtime_ext(31 downto 0);
                elsif addrb = x"20010584" then prdata_plic <= mtime_ext(63 downto 32);
                elsif addrb = x"20010480" then prdata_plic <= mtimecmp_ext(31 downto 0);
                elsif addrb = x"20010484" then prdata_plic <= mtimecmp_ext(63 downto 32);
                end if;
            end if;

        end if;
    end process;

end sys_top_a;
