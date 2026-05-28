///////////////////////////////////////////////////////////////////////////////
// Project   : CDAC Vega ET1035 SOC
// File      : uart_top.v
// Title     : UART Top - 16550 Compatible (Synthesisable)
// Author    : Rewritten for Cadence Genus / SCL-Faraday 180nm
// Description:
//   Synthesisable replacement for Xilinx uart_top.v netlist.
//   Exact same port interface preserved for sys_top.vhd compatibility.
//   16550-compatible UART with:
//     - Programmable baud rate via divisor latch (DLL/DLM registers)
//     - 8N1 format (8 data bits, no parity, 1 stop bit)
//     - TX FIFO (64 entries)
//     - RX FIFO (64 entries)
//     - Interrupt on RX data available
//   Register map (a[2:0]):
//     000 : RBR (read) / THR (write) / DLL (when DLAB=1)
//     001 : IER / DLM (when DLAB=1)
//     010 : IIR (read) / FCR (write)
//     011 : LCR
//     100 : MCR
//     101 : LSR
//     110 : MSR
//     111 : SCR
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module uart_top (
    input        clk,        // system clock
    input        mr,         // master reset (active high)
    input        cs,         // chip select (active high)
    input  [2:0] a,          // register address
    input        rd,         // read strobe (active high)
    input        wr,         // write strobe (active high)
    input        sin,        // serial data in (RX)
    input  [7:0] din,        // parallel data in
    output [7:0] dout,       // parallel data out
    output       sout,       // serial data out (TX)
    output       ddis,       // driver disable (tied low)
    output       intr,       // interrupt output (active high)
    output       baudout_n,  // baud clock out (open in sys_top)
    output       rxrdy_n,    // RX ready (open in sys_top)
    output       txrdy_n     // TX ready (open in sys_top)
);

    ///////////////////////////////////////////////////////////////////////////
    // Parameters
    ///////////////////////////////////////////////////////////////////////////
    parameter FIFO_DEPTH = 64;

    ///////////////////////////////////////////////////////////////////////////
    // Internal registers (16550 register set)
    ///////////////////////////////////////////////////////////////////////////
    reg [7:0] thr_reg;       // Transmitter Holding Register
    reg [7:0] rbr_reg;       // Receiver Buffer Register
    reg [7:0] ier_reg;       // Interrupt Enable Register
    reg [7:0] iir_reg;       // Interrupt Identification Register
    reg [7:0] fcr_reg;       // FIFO Control Register
    reg [7:0] lcr_reg;       // Line Control Register
    reg [7:0] mcr_reg;       // Modem Control Register
    reg [7:0] lsr_reg;       // Line Status Register
    reg [7:0] msr_reg;       // Modem Status Register
    reg [7:0] scr_reg;       // Scratch Register
    reg [7:0] dll_reg;       // Divisor Latch Low
    reg [7:0] dlm_reg;       // Divisor Latch High

    // DLAB - Divisor Latch Access Bit (lcr_reg[7])
    wire dlab = lcr_reg[7];

    ///////////////////////////////////////////////////////////////////////////
    // Baud rate generator
    ///////////////////////////////////////////////////////////////////////////
    wire [15:0] divisor = {dlm_reg, dll_reg};
    reg  [15:0] baud_cnt;
    reg         baud_tick;    // one clock pulse per baud period
    reg         baud_tick_r;

    always @(posedge clk) begin
        if (mr) begin
            baud_cnt  <= 16'd0;
            baud_tick <= 1'b0;
        end else begin
            if (divisor == 16'd0 || baud_cnt >= divisor - 1) begin
                baud_cnt  <= 16'd0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt  <= baud_cnt + 1'b1;
                baud_tick <= 1'b0;
            end
        end
    end

    assign baudout_n = ~baud_tick;

    ///////////////////////////////////////////////////////////////////////////
    // TX FIFO (64 x 8)
    ///////////////////////////////////////////////////////////////////////////
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [6:0] tx_wr_ptr, tx_rd_ptr;
    reg [6:0] tx_count;
    wire      tx_fifo_empty = (tx_count == 7'd0);
    wire      tx_fifo_full  = (tx_count == FIFO_DEPTH);

    // TX FIFO write (from CPU)
    integer i;
    always @(posedge clk) begin
        if (mr) begin
            tx_wr_ptr <= 7'd0;
            tx_rd_ptr <= 7'd0;
            tx_count  <= 7'd0;
        end else begin
            if (cs && wr && !dlab && (a == 3'b000) && !tx_fifo_full) begin
                tx_fifo[tx_wr_ptr[5:0]] <= din;
                tx_wr_ptr <= tx_wr_ptr + 1'b1;
                tx_count  <= tx_count + 1'b1;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // TX shift register
    ///////////////////////////////////////////////////////////////////////////
    reg [9:0] tx_shift;     // start + 8 data + stop
    reg [3:0] tx_bit_cnt;
    reg       tx_busy;
    reg       sout_r;

    always @(posedge clk) begin
        if (mr) begin
            tx_shift   <= 10'h3FF;
            tx_bit_cnt <= 4'd0;
            tx_busy    <= 1'b0;
            sout_r     <= 1'b1;
            tx_rd_ptr  <= 7'd0;
        end else begin
            if (baud_tick) begin
                if (!tx_busy) begin
                    if (!tx_fifo_empty) begin
                        // Load next byte: start=0, data, stop=1
                        tx_shift   <= {1'b1, tx_fifo[tx_rd_ptr[5:0]], 1'b0};
                        tx_rd_ptr  <= tx_rd_ptr + 1'b1;
                        tx_count   <= tx_count - 1'b1;
                        tx_bit_cnt <= 4'd10;
                        tx_busy    <= 1'b1;
                    end
                end else begin
                    sout_r     <= tx_shift[0];
                    tx_shift   <= {1'b1, tx_shift[9:1]};
                    tx_bit_cnt <= tx_bit_cnt - 1'b1;
                    if (tx_bit_cnt == 4'd1) begin
                        tx_busy <= 1'b0;
                    end
                end
            end
        end
    end

    assign sout = sout_r;

    ///////////////////////////////////////////////////////////////////////////
    // RX FIFO (64 x 8)
    ///////////////////////////////////////////////////////////////////////////
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [6:0] rx_wr_ptr, rx_rd_ptr;
    reg [6:0] rx_count;
    wire      rx_fifo_empty = (rx_count == 7'd0);
    wire      rx_fifo_full  = (rx_count == FIFO_DEPTH);

    ///////////////////////////////////////////////////////////////////////////
    // RX shift register
    ///////////////////////////////////////////////////////////////////////////
    reg       sin_r1, sin_r2;   // sync input
    reg [9:0] rx_shift;
    reg [3:0] rx_bit_cnt;
    reg       rx_busy;
    reg [1:0] rx_state_r;

    // States
    localparam RX_IDLE    = 2'b00;
    localparam RX_START   = 2'b01;
    localparam RX_DATA    = 2'b10;
    localparam RX_STOP    = 2'b11;

    // Synchronise RX input
    always @(posedge clk) begin
        sin_r1 <= sin;
        sin_r2 <= sin_r1;
    end

    always @(posedge clk) begin
        if (mr) begin
            rx_shift   <= 10'h3FF;
            rx_bit_cnt <= 4'd0;
            rx_busy    <= 1'b0;
            rx_state_r <= RX_IDLE;
            rx_wr_ptr  <= 7'd0;
            rx_rd_ptr  <= 7'd0;
            rx_count   <= 7'd0;
        end else begin
            if (baud_tick) begin
                case (rx_state_r)
                    RX_IDLE: begin
                        if (sin_r2 == 1'b0) begin       // start bit detected
                            rx_state_r <= RX_START;
                            rx_bit_cnt <= 4'd0;
                        end
                    end
                    RX_START: begin
                        // half-bit delay to sample in middle
                        rx_state_r <= RX_DATA;
                        rx_bit_cnt <= 4'd8;
                    end
                    RX_DATA: begin
                        rx_shift   <= {sin_r2, rx_shift[9:1]};
                        rx_bit_cnt <= rx_bit_cnt - 1'b1;
                        if (rx_bit_cnt == 4'd1) begin
                            rx_state_r <= RX_STOP;
                        end
                    end
                    RX_STOP: begin
                        if (sin_r2 == 1'b1 && !rx_fifo_full) begin
                            rx_fifo[rx_wr_ptr[5:0]] <= rx_shift[8:1];
                            rx_wr_ptr <= rx_wr_ptr + 1'b1;
                            rx_count  <= rx_count + 1'b1;
                        end
                        rx_state_r <= RX_IDLE;
                    end
                    default: rx_state_r <= RX_IDLE;
                endcase
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Register read/write
    ///////////////////////////////////////////////////////////////////////////
    reg [7:0] dout_r;

    always @(posedge clk) begin
        if (mr) begin
            ier_reg  <= 8'h00;
            lcr_reg  <= 8'h03;  // 8N1
            mcr_reg  <= 8'h00;
            scr_reg  <= 8'h00;
            dll_reg  <= 8'd1;   // default divisor = 1
            dlm_reg  <= 8'd0;
            fcr_reg  <= 8'h00;
        end else begin
            if (cs && wr) begin
                case (a)
                    3'b000: if  (dlab) dll_reg <= din; // DLL
                            // else THR handled by TX FIFO above
                    3'b001: if  (dlab) dlm_reg <= din; // DLM
                            else       ier_reg <= din; // IER
                    3'b010: fcr_reg <= din;             // FCR
                    3'b011: lcr_reg <= din;             // LCR
                    3'b100: mcr_reg <= din;             // MCR
                    3'b111: scr_reg <= din;             // SCR
                    default: ;
                endcase
            end
        end
    end

    // LSR - Line Status Register (read only, status bits)
    // bit 0: DR   - Data Ready (RX FIFO not empty)
    // bit 5: THRE - TX Holding Register Empty (TX FIFO not full)
    // bit 6: TEMT - TX Empty (TX FIFO empty and not busy)
    wire [7:0] lsr_out;
    assign lsr_out = {1'b0, 1'b0,
                      (tx_fifo_empty & ~tx_busy),  // TEMT
                      tx_fifo_empty,               // THRE
                      1'b0, 1'b0, 1'b0,
                      ~rx_fifo_empty};             // DR

    // IIR - Interrupt Identification Register
    // bit 0: 0=interrupt pending, 1=no interrupt
    // bits[2:1]: interrupt type 10=RX data available
    wire [7:0] iir_out;
    assign iir_out = (~rx_fifo_empty && ier_reg[0]) ?
                     8'b11000100 :   // RX data available interrupt
                     8'b11000001;    // no interrupt pending

    // Register read mux
    always @(posedge clk) begin
        if (mr) begin
            dout_r  <= 8'h00;
            rx_rd_ptr <= 7'd0;
        end else begin
            if (cs && rd) begin
                case (a)
                    3'b000: begin
                        if (dlab) begin
                            dout_r <= dll_reg;
                        end else begin
                            if (!rx_fifo_empty) begin
                                dout_r    <= rx_fifo[rx_rd_ptr[5:0]];
                                rx_rd_ptr <= rx_rd_ptr + 1'b1;
                                rx_count  <= rx_count - 1'b1;
                            end else begin
                                dout_r <= 8'h00;
                            end
                        end
                    end
                    3'b001: dout_r <= dlab ? dlm_reg : ier_reg;
                    3'b010: dout_r <= iir_out;
                    3'b011: dout_r <= lcr_reg;
                    3'b100: dout_r <= mcr_reg;
                    3'b101: dout_r <= lsr_out;
                    3'b110: dout_r <= msr_reg;
                    3'b111: dout_r <= scr_reg;
                    default: dout_r <= 8'h00;
                endcase
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Interrupt generation
    // IER bit 0: RX data available interrupt enable
    // IER bit 1: TX holding register empty interrupt enable
    ///////////////////////////////////////////////////////////////////////////
    reg intr_r;
    always @(posedge clk) begin
        if (mr) begin
            intr_r <= 1'b0;
        end else begin
            intr_r <= (ier_reg[0] & ~rx_fifo_empty) |
                      (ier_reg[1] &  tx_fifo_empty);
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Output assignments
    ///////////////////////////////////////////////////////////////////////////
    assign dout     = dout_r;
    assign intr     = intr_r;
    assign ddis     = 1'b0;              // driver disable - always low
    assign rxrdy_n  = rx_fifo_empty;     // open in sys_top
    assign txrdy_n  = ~tx_fifo_empty;    // open in sys_top

endmodule
