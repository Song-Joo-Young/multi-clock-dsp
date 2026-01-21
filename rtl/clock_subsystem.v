//-----------------------------------------------------------------------------
// Module: clock_subsystem
// Description: Top-level Clock Subsystem for Multi-Clock DSP
//              Integrates all clock generation, muxing, and DFT control
//-----------------------------------------------------------------------------

module clock_subsystem #(
    parameter IDCODE_VALUE = 32'h4D43_4453  // "MCDS" - Multi Clock DSP
)(
    //=========================================================================
    // External Clock Inputs
    //=========================================================================
    input  wire        ext_clk,           // External reference clock
    input  wire        pll_clk,           // PLL output clock (faster)

    //=========================================================================
    // Reset
    //=========================================================================
    input  wire        rst_n,             // Global async reset (active low)
    input  wire        por_n,             // Power-on reset

    //=========================================================================
    // Clock Source Selection
    //=========================================================================
    input  wire        clk_src_sel,       // 0: ext_clk, 1: pll_clk

    //=========================================================================
    // Clock Divider Control
    //=========================================================================
    input  wire        div_enable,        // Enable clock dividers
    input  wire [1:0]  int_div_sel,       // Integer divider: 00=/2, 01=/4, 10=/8, 11=/16
    input  wire [7:0]  frac_div_ratio,    // Fractional divider ratio {N[3:0], F[3:0]}
    input  wire        frac_div_enable,   // Enable fractional divider

    //=========================================================================
    // Functional Clock Selection
    //=========================================================================
    input  wire [1:0]  func_clk_sel,      // 00: sys_clk, 01: div_clk, 10: frac_clk, 11: bypass

    //=========================================================================
    // DFT Interface
    //=========================================================================
    input  wire [1:0]  test_mode,         // 00: func, 01: scan, 10: jtag, 11: bist
    input  wire        scan_clk,          // External scan clock
    input  wire        scan_enable,       // Scan enable

    //=========================================================================
    // JTAG Interface
    //=========================================================================
    input  wire        tck,               // JTAG test clock
    input  wire        tms,               // JTAG test mode select
    input  wire        tdi,               // JTAG test data in
    input  wire        trst_n,            // JTAG test reset
    output wire        tdo,               // JTAG test data out
    output wire        tdo_en,            // TDO output enable

    //=========================================================================
    // BIST Control
    //=========================================================================
    input  wire        bist_enable,       // Enable BIST mode
    input  wire        bist_start,        // Start BIST
    input  wire [7:0]  bist_max_count,    // BIST pattern count

    //=========================================================================
    // Clock Gating Control
    //=========================================================================
    input  wire        dsp_clk_en,        // DSP clock enable
    input  wire        periph_clk_en,     // Peripheral clock enable

    //=========================================================================
    // Output Clocks
    //=========================================================================
    output wire        sys_clk,           // System clock (source selected)
    output wire        div_clk,           // Integer divided clock
    output wire        frac_clk,          // Fractional divided clock
    output wire        core_clk,          // Core clock (func or DFT)
    output wire        dsp_gated_clk,     // Gated DSP clock
    output wire        periph_gated_clk,  // Gated peripheral clock

    //=========================================================================
    // Status Outputs
    //=========================================================================
    output wire        is_test_mode,      // Test mode active
    output wire        bist_done,         // BIST complete
    output wire        bist_active,       // BIST running
    output wire [7:0]  bist_count         // BIST pattern count
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    wire        sys_clk_src;      // Selected source clock
    wire        func_clk;         // Functional clock (muxed)
    wire        dft_clk;          // DFT clock output
    wire        bist_clk;         // BIST generated clock
    wire        bist_clk_en;      // BIST clock enable
    wire        scan_en_sync;     // Synchronized scan enable

    // TAP controller outputs
    wire        tap_reset;
    wire        tap_shift_dr;
    wire        tap_shift_ir;

    // Combined reset
    wire        combined_rst_n;
    assign combined_rst_n = rst_n & por_n;

    //=========================================================================
    // Clock Source MUX (ext_clk or pll_clk)
    //=========================================================================
    clk_mux_2to1 u_src_mux (
        .clk_a   (ext_clk),
        .clk_b   (pll_clk),
        .sel     (clk_src_sel),
        .rst_n   (combined_rst_n),
        .clk_out (sys_clk_src)
    );

    assign sys_clk = sys_clk_src;

    //=========================================================================
    // Integer Clock Divider
    //=========================================================================
    clk_div_integer u_int_divider (
        .clk_in  (sys_clk_src),
        .rst_n   (combined_rst_n),
        .enable  (div_enable),
        .div_sel (int_div_sel),
        .clk_out (div_clk)
    );

    //=========================================================================
    // Fractional Clock Divider
    //=========================================================================
    clk_div_fractional u_frac_divider (
        .clk_in    (sys_clk_src),
        .rst_n     (combined_rst_n),
        .enable    (frac_div_enable),
        .div_ratio (frac_div_ratio),
        .clk_out   (frac_clk)
    );

    //=========================================================================
    // Functional Clock MUX (4:1)
    //=========================================================================
    clk_mux_4to1 u_func_mux (
        .clk_0   (sys_clk_src),    // 00: System clock (no division)
        .clk_1   (div_clk),        // 01: Integer divided clock
        .clk_2   (frac_clk),       // 10: Fractional divided clock
        .clk_3   (ext_clk),        // 11: Bypass (external clock directly)
        .sel     (func_clk_sel),
        .rst_n   (combined_rst_n),
        .clk_out (func_clk)
    );

    //=========================================================================
    // JTAG TAP Controller
    //=========================================================================
    jtag_tap #(
        .IDCODE_VALUE (IDCODE_VALUE)
    ) u_jtag_tap (
        .tck          (tck),
        .tms          (tms),
        .tdi          (tdi),
        .trst_n       (trst_n),
        .tdo          (tdo),
        .tdo_en       (tdo_en),
        .tap_reset    (tap_reset),
        .tap_idle     (),
        .tap_shift_dr (tap_shift_dr),
        .tap_shift_ir (tap_shift_ir),
        .tap_capture_dr (),
        .tap_update_dr  (),
        .tap_update_ir  ()
    );

    //=========================================================================
    // BIST Clock Controller
    //=========================================================================
    bist_clock_ctrl #(
        .BIST_PATTERN_WIDTH (8),
        .BIST_CLOCK_DIV     (2)
    ) u_bist_ctrl (
        .clk_in         (sys_clk_src),
        .rst_n          (combined_rst_n),
        .bist_enable    (bist_enable),
        .bist_start     (bist_start),
        .bist_hold      (1'b0),           // Not used in basic config
        .bist_max_count (bist_max_count),
        .bist_clk_out   (bist_clk),
        .bist_active    (bist_active),
        .bist_done      (bist_done),
        .bist_count     (bist_count),
        .bist_clk_en    (bist_clk_en)
    );

    //=========================================================================
    // DFT Clock Controller
    //=========================================================================
    dft_clock_ctrl u_dft_ctrl (
        .func_clk     (func_clk),
        .scan_clk     (scan_clk),
        .tck          (tck),
        .bist_clk     (bist_clk),
        .rst_n        (combined_rst_n),
        .test_mode    (test_mode),
        .scan_enable  (scan_enable),
        .dft_bypass   (1'b0),             // DFT bypass not used
        .dft_clk_out  (dft_clk),
        .core_clk_out (core_clk),
        .is_test_mode (is_test_mode),
        .is_scan_mode (),
        .is_jtag_mode (),
        .is_bist_mode (),
        .scan_en_sync (scan_en_sync)
    );

    //=========================================================================
    // Clock Gating Cells (using Nangate ICG)
    //=========================================================================

    // DSP Clock Gating
    clock_gating_cell u_dsp_icg (
        .clk_in      (core_clk),
        .enable      (dsp_clk_en),
        .scan_enable (scan_en_sync),
        .clk_out     (dsp_gated_clk)
    );

    // Peripheral Clock Gating
    clock_gating_cell u_periph_icg (
        .clk_in      (core_clk),
        .enable      (periph_clk_en),
        .scan_enable (scan_en_sync),
        .clk_out     (periph_gated_clk)
    );

endmodule


//-----------------------------------------------------------------------------
// Module: multi_clock_dsp_top
// Description: Top-level integrating clock subsystem with DSP core
//              Complete Multi-Clock DSP system
//-----------------------------------------------------------------------------

module multi_clock_dsp_top #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter FIR_TAPS     = 8,
    parameter IDCODE_VALUE = 32'h4D43_4453
)(
    //=========================================================================
    // Clock and Reset
    //=========================================================================
    input  wire        ext_clk,
    input  wire        pll_clk,
    input  wire        rst_n,

    //=========================================================================
    // Clock Control
    //=========================================================================
    input  wire        clk_src_sel,
    input  wire [1:0]  int_div_sel,
    input  wire [7:0]  frac_div_ratio,
    input  wire [1:0]  func_clk_sel,

    //=========================================================================
    // DFT Interface
    //=========================================================================
    input  wire [1:0]  test_mode,
    input  wire        scan_clk,
    input  wire        scan_enable,

    //=========================================================================
    // JTAG Interface
    //=========================================================================
    input  wire        tck,
    input  wire        tms,
    input  wire        tdi,
    input  wire        trst_n,
    output wire        tdo,
    output wire        tdo_en,

    //=========================================================================
    // BIST Control
    //=========================================================================
    input  wire        bist_enable,
    input  wire        bist_start,
    output wire        bist_done,

    //=========================================================================
    // DSP Data Interface (slow ADC clock domain)
    //=========================================================================
    input  wire [DATA_WIDTH-1:0]  adc_data,
    input  wire                   adc_valid,

    //=========================================================================
    // DSP Control
    //=========================================================================
    input  wire                   fir_start,
    input  wire                   coeff_load,
    input  wire [$clog2(FIR_TAPS)-1:0] coeff_addr,
    input  wire [COEFF_WIDTH-1:0] coeff_data,

    //=========================================================================
    // DSP Output
    //=========================================================================
    output wire [DATA_WIDTH-1:0]  dsp_out,
    output wire                   dsp_valid,
    output wire                   dsp_busy,

    //=========================================================================
    // Status
    //=========================================================================
    output wire        is_test_mode
);

    //=========================================================================
    // Internal Clocks
    //=========================================================================
    wire sys_clk;
    wire div_clk;
    wire frac_clk;
    wire core_clk;
    wire dsp_gated_clk;
    wire periph_gated_clk;

    wire bist_active;
    wire [7:0] bist_count;

    //=========================================================================
    // Clock Subsystem
    //=========================================================================
    clock_subsystem #(
        .IDCODE_VALUE (IDCODE_VALUE)
    ) u_clk_subsys (
        // Clocks
        .ext_clk          (ext_clk),
        .pll_clk          (pll_clk),

        // Reset
        .rst_n            (rst_n),
        .por_n            (1'b1),

        // Clock control
        .clk_src_sel      (clk_src_sel),
        .div_enable       (1'b1),
        .int_div_sel      (int_div_sel),
        .frac_div_ratio   (frac_div_ratio),
        .frac_div_enable  (1'b1),
        .func_clk_sel     (func_clk_sel),

        // DFT
        .test_mode        (test_mode),
        .scan_clk         (scan_clk),
        .scan_enable      (scan_enable),

        // JTAG
        .tck              (tck),
        .tms              (tms),
        .tdi              (tdi),
        .trst_n           (trst_n),
        .tdo              (tdo),
        .tdo_en           (tdo_en),

        // BIST
        .bist_enable      (bist_enable),
        .bist_start       (bist_start),
        .bist_max_count   (8'd255),

        // Clock gating
        .dsp_clk_en       (1'b1),         // Always enabled for now
        .periph_clk_en    (1'b1),

        // Output clocks
        .sys_clk          (sys_clk),
        .div_clk          (div_clk),
        .frac_clk         (frac_clk),
        .core_clk         (core_clk),
        .dsp_gated_clk    (dsp_gated_clk),
        .periph_gated_clk (periph_gated_clk),

        // Status
        .is_test_mode     (is_test_mode),
        .bist_done        (bist_done),
        .bist_active      (bist_active),
        .bist_count       (bist_count)
    );

    //=========================================================================
    // Data Interface (Clock Domain Crossing: div_clk -> dsp_gated_clk)
    //=========================================================================
    wire [DATA_WIDTH-1:0] dsp_data;
    wire                  dsp_data_valid;
    wire                  dsp_ready;

    dsp_data_interface #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (8)
    ) u_data_if (
        // Slow domain (ADC)
        .slow_clk     (div_clk),          // Use divided clock for ADC
        .slow_rst_n   (rst_n),
        .adc_data_in  (adc_data),
        .adc_valid    (adc_valid),

        // Fast domain (DSP)
        .fast_clk     (dsp_gated_clk),
        .fast_rst_n   (rst_n),
        .dsp_data_out (dsp_data),
        .dsp_valid    (dsp_data_valid),
        .dsp_ready    (dsp_ready),

        // Status
        .fifo_empty   (),
        .fifo_full    ()
    );

    //=========================================================================
    // FIR Filter Engine
    //=========================================================================
    assign dsp_ready = ~dsp_busy;

    dsp_fir_engine #(
        .DATA_WIDTH  (DATA_WIDTH),
        .COEFF_WIDTH (COEFF_WIDTH),
        .TAP_COUNT   (FIR_TAPS),
        .ACC_WIDTH   (40)
    ) u_fir (
        .clk        (dsp_gated_clk),
        .rst_n      (rst_n),
        .clk_en     (1'b1),

        // Control
        .start      (fir_start | dsp_data_valid),
        .load_coeff (coeff_load),
        .coeff_addr (coeff_addr),
        .coeff_data (coeff_data),

        // Data
        .sample_in  (dsp_data),
        .sample_out (dsp_out),
        .valid_out  (dsp_valid),
        .busy       (dsp_busy)
    );

endmodule
