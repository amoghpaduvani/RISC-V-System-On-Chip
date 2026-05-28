///////////////////////////////////////////////////////////////////////////////
// Project   : CDAC Vega ET1035 SOC
// File      : clk_wiz_0.v
// Title     : clk_wiz_0 - Clock Wizard (Synthesisable ASIC replacement)
// Description:
//   Synthesisable replacement for Xilinx MMCM-based clk_wiz_0.
//   Original: 100MHz input → MMCM (x10/25) → 40MHz clk_out1, clk_out2
//   ASIC replacement: clock passed through directly.
//   PLL/clock generation is NOT done in RTL for ASIC flow.
//   Innovus handles clock distribution via CTS automatically.
//
//   Port interface 100% identical to original clk_wiz_0.v:
//     clk_in1  → input clock from pad
//     clk_out1 → clock to processor (clk_p in sys_top)
//     clk_out2 → secondary clock (open in sys_top - tied to clk_out1)
//     reset    → active high reset input (ignored in ASIC)
//     locked   → lock indicator (tied high - always locked in ASIC)
///////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module clk_wiz_0 (
    input  clk_in1,     // clock input from pad
    output clk_out1,    // primary clock output (to clk_p)
    output clk_out2,    // secondary clock output (open in sys_top)
    input  reset,       // reset input (retained for port compatibility)
    output locked       // lock indicator
);

    // In ASIC flow: clock passes directly through
    // No MMCM, no IBUF, no BUFG — Innovus inserts buffers during CTS
    assign clk_out1 = clk_in1;
    assign clk_out2 = clk_in1;

    // locked always asserted — no PLL lock wait needed
    assign locked   = 1'b1;

endmodule

///////////////////////////////////////////////////////////////////////////////
// clk_wiz_0_clk_wiz - inner implementation module
// In original Xilinx flow this contained the MMCM primitive.
// For ASIC: simply passes clock through, matching port interface exactly.
///////////////////////////////////////////////////////////////////////////////
module clk_wiz_0_clk_wiz (
    input  clk_in1,
    output clk_out1,
    output clk_out2,
    input  reset,
    output locked
);

    assign clk_out1 = clk_in1;
    assign clk_out2 = clk_in1;
    assign locked   = 1'b1;

endmodule
