//-----------------------------------------------------------------------------
// Module: clock_subsystem
// Description: Top-level Clock Subsystem for Multi-Clock DSP
//-----------------------------------------------------------------------------

module clock_subsystem #(
    parameter IDCODE_VALUE = 32'h4D43_4453
)(
    input  wire        ext_clk,
    input  wire        pll_clk,
    input  wire        rst_n,
    input  wire        por_n,
    input  wire        clk_src_sel,
    input  wire        div_enable,
    input  wire [1:0]  int_div_sel,
    input  wire [7:0]  frac_div_ratio,
    input  wire        frac_div_enable,
    input  wire [1:0]  func_clk_sel,
    input  wire [1:0]  test_mode,
    input  wire        scan_clk,
    input  wire        scan_enable,
    input  wire        tck,
    input  wire        tms,
    input  wire        tdi,
    input  wire        trst_n,
    output wire        tdo,
    output wire        tdo_en,
    input  wire        bist_enable,
    input  wire        bist_start,
    input  wire [7:0]  bist_max_count,
    input  wire        dsp_clk_en,
    input  wire        periph_clk_en,
    output wire        sys_clk,
    output wire        div_clk,
    output wire        frac_clk,
    output wire        core_clk,
    output wire        dsp_gated_clk,
    output wire        periph_gated_clk,
    output wire        is_test_mode,
    output wire        bist_done,
    output wire        bist_active,
    output wire [7:0]  bist_count
);

    wire sys_clk_src, func_clk, dft_clk, bist_clk, bist_clk_en, scan_en_sync;
    wire tap_reset, tap_shift_dr, tap_shift_ir;
    wire combined_rst_n = rst_n & por_n;

    clk_mux_2to1 u_src_mux (
        .clk_a(ext_clk), .clk_b(pll_clk), .sel(clk_src_sel),
        .rst_n(combined_rst_n), .clk_out(sys_clk_src)
    );
    assign sys_clk = sys_clk_src;

    clk_div_integer u_int_divider (
        .clk_in(sys_clk_src), .rst_n(combined_rst_n),
        .enable(div_enable), .div_sel(int_div_sel), .clk_out(div_clk)
    );

    clk_div_fractional u_frac_divider (
        .clk_in(sys_clk_src), .rst_n(combined_rst_n),
        .enable(frac_div_enable), .div_ratio(frac_div_ratio), .clk_out(frac_clk)
    );

    clk_mux_4to1 u_func_mux (
        .clk_0(sys_clk_src), .clk_1(div_clk), .clk_2(frac_clk), .clk_3(ext_clk),
        .sel(func_clk_sel), .rst_n(combined_rst_n), .clk_out(func_clk)
    );

    jtag_tap #(.IDCODE_VALUE(IDCODE_VALUE)) u_jtag_tap (
        .tck(tck), .tms(tms), .tdi(tdi), .trst_n(trst_n),
        .tdo(tdo), .tdo_en(tdo_en), .tap_reset(tap_reset), .tap_idle(),
        .tap_shift_dr(tap_shift_dr), .tap_shift_ir(tap_shift_ir),
        .tap_capture_dr(), .tap_update_dr(), .tap_update_ir()
    );

    bist_clock_ctrl #(.BIST_PATTERN_WIDTH(8), .BIST_CLOCK_DIV(2)) u_bist_ctrl (
        .clk_in(sys_clk_src), .rst_n(combined_rst_n),
        .bist_enable(bist_enable), .bist_start(bist_start), .bist_hold(1'b0),
        .bist_max_count(bist_max_count), .bist_clk_out(bist_clk),
        .bist_active(bist_active), .bist_done(bist_done),
        .bist_count(bist_count), .bist_clk_en(bist_clk_en)
    );

    dft_clock_ctrl u_dft_ctrl (
        .func_clk(func_clk), .scan_clk(scan_clk), .tck(tck), .bist_clk(bist_clk),
        .rst_n(combined_rst_n), .test_mode(test_mode), .scan_enable(scan_enable),
        .dft_bypass(1'b0), .dft_clk_out(dft_clk), .core_clk_out(core_clk),
        .is_test_mode(is_test_mode), .is_scan_mode(), .is_jtag_mode(), .is_bist_mode(),
        .scan_en_sync(scan_en_sync)
    );

    clock_gating_cell u_dsp_icg (
        .clk_in(core_clk), .enable(dsp_clk_en),
        .scan_enable(scan_en_sync), .clk_out(dsp_gated_clk)
    );

    clock_gating_cell u_periph_icg (
        .clk_in(core_clk), .enable(periph_clk_en),
        .scan_enable(scan_en_sync), .clk_out(periph_gated_clk)
    );

endmodule


//-----------------------------------------------------------------------------
// Module: multi_clock_dsp_top
//-----------------------------------------------------------------------------

module multi_clock_dsp_top #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter FIR_TAPS     = 8,
    parameter IDCODE_VALUE = 32'h4D43_4453
)(
    input  wire        ext_clk,
    input  wire        pll_clk,
    input  wire        rst_n,
    input  wire        clk_src_sel,
    input  wire [1:0]  int_div_sel,
    input  wire [7:0]  frac_div_ratio,
    input  wire [1:0]  func_clk_sel,
    input  wire [1:0]  test_mode,
    input  wire        scan_clk,
    input  wire        scan_enable,
    input  wire        tck,
    input  wire        tms,
    input  wire        tdi,
    input  wire        trst_n,
    output wire        tdo,
    output wire        tdo_en,
    input  wire        bist_enable,
    input  wire        bist_start,
    output wire        bist_done,
    input  wire [DATA_WIDTH-1:0]  adc_data,
    input  wire                   adc_valid,
    input  wire                   fir_start,
    input  wire                   coeff_load,
    input  wire [$clog2(FIR_TAPS)-1:0] coeff_addr,
    input  wire [COEFF_WIDTH-1:0] coeff_data,
    output wire [DATA_WIDTH-1:0]  dsp_out,
    output wire                   dsp_valid,
    output wire                   dsp_busy,
    output wire        is_test_mode,
    // Messy network
    input  wire        messy_clk_en,
    input  wire        messy_feedback_en,
    input  wire [63:0] messy_data_in,
    output wire [63:0] messy_data_out,
    output wire        messy_gclk_out,
    // Test interfaces
    input  wire [3:0]  test_sel,
    output wire [31:0] test_reconv_out,
    output wire [31:0] test_corner_out,
    output wire [31:0] test_cross_out,
    output wire [31:0] test_hier_out,
    output wire [31:0] test_multi_out,
    output wire [31:0] test_gen_out,
    output wire [31:0] test_wire_out,
    output wire [31:0] test_latch_out,
    output wire [31:0] test_chain_out,
    output wire [31:0] test_pattern_out
);

    wire sys_clk, div_clk, frac_clk, core_clk, dsp_gated_clk, periph_gated_clk;
    wire bist_active;
    wire [7:0] bist_count;

    clock_subsystem #(.IDCODE_VALUE(IDCODE_VALUE)) u_clk_subsys (
        .ext_clk(ext_clk), .pll_clk(pll_clk),
        .rst_n(rst_n), .por_n(1'b1),
        .clk_src_sel(clk_src_sel),
        .div_enable(1'b1), .int_div_sel(int_div_sel),
        .frac_div_ratio(frac_div_ratio), .frac_div_enable(1'b1),
        .func_clk_sel(func_clk_sel),
        .test_mode(test_mode), .scan_clk(scan_clk), .scan_enable(scan_enable),
        .tck(tck), .tms(tms), .tdi(tdi), .trst_n(trst_n),
        .tdo(tdo), .tdo_en(tdo_en),
        .bist_enable(bist_enable), .bist_start(bist_start), .bist_max_count(8'd255),
        .dsp_clk_en(1'b1), .periph_clk_en(1'b1),
        .sys_clk(sys_clk), .div_clk(div_clk), .frac_clk(frac_clk),
        .core_clk(core_clk), .dsp_gated_clk(dsp_gated_clk), .periph_gated_clk(periph_gated_clk),
        .is_test_mode(is_test_mode), .bist_done(bist_done),
        .bist_active(bist_active), .bist_count(bist_count)
    );

    wire [DATA_WIDTH-1:0] dsp_data;
    wire dsp_data_valid, dsp_ready;

    dsp_data_interface #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(8)) u_data_if (
        .slow_clk(div_clk), .slow_rst_n(rst_n),
        .adc_data_in(adc_data), .adc_valid(adc_valid),
        .fast_clk(dsp_gated_clk), .fast_rst_n(rst_n),
        .dsp_data_out(dsp_data), .dsp_valid(dsp_data_valid), .dsp_ready(dsp_ready),
        .fifo_empty(), .fifo_full()
    );

    assign dsp_ready = ~dsp_busy;

    dsp_fir_engine #(
        .DATA_WIDTH(DATA_WIDTH), .COEFF_WIDTH(COEFF_WIDTH),
        .TAP_COUNT(FIR_TAPS), .ACC_WIDTH(40)
    ) u_fir (
        .clk(dsp_gated_clk), .rst_n(rst_n), .clk_en(1'b1),
        .start(fir_start | dsp_data_valid),
        .load_coeff(coeff_load), .coeff_addr(coeff_addr), .coeff_data(coeff_data),
        .sample_in(dsp_data), .sample_out(dsp_out),
        .valid_out(dsp_valid), .busy(dsp_busy)
    );

    clock_network_messy u_messy_clk (
        .clk_in(sys_clk), .rst_n(rst_n), .scan_enable(scan_enable),
        .enable(1'b1), .main_clk_en(messy_clk_en), .feedback_en(messy_feedback_en),
        .data_in(messy_data_in), .data_out(messy_data_out), .gclk_main(messy_gclk_out)
    );

    // Test modules
    clock_reconvergence u_reconv (
        .clk_in(sys_clk), .rst_n(rst_n),
        .sel_a(test_sel[0]), .sel_b(test_sel[1]), .sel_final(test_sel[2]),
        .data_in(messy_data_in[31:0]), .data_out(test_reconv_out)
    );

    clock_diamond u_diamond (
        .clk_in(sys_clk), .rst_n(rst_n), .sel(test_sel[0]),
        .data_in(messy_data_in[15:0]), .data_out()
    );

    clock_corner_cases u_corner (
        .clk_in(sys_clk), .rst_n(rst_n), .sel(test_sel),
        .data_in(messy_data_in[31:0]), .data_out(test_corner_out)
    );

    clock_cross_primary u_cross (
        .clk_ext(ext_clk), .clk_pll(pll_clk), .rst_n(rst_n),
        .sel(test_sel[1:0]), .data_in(messy_data_in[31:0]), .data_out(test_cross_out)
    );

    clock_hierarchical_dup u_hier (
        .clk_in(sys_clk), .rst_n(rst_n), .sel(test_sel[2:0]),
        .data_in(messy_data_in[31:0]), .data_out(test_hier_out)
    );

    clock_multi_path u_multi (
        .clk_in(sys_clk), .rst_n(rst_n), .path_sel(test_sel[1:0]),
        .data_in(messy_data_in[31:0]), .data_out(test_multi_out)
    );

    clock_generate_array #(.NUM_PATHS(4)) u_gen (
        .clk_in(sys_clk), .rst_n(rst_n), .path_sel(test_sel),
        .data_in(messy_data_in[31:0]), .data_out(test_gen_out)
    );

    clock_wire_conflict u_wire (
        .clk_a(ext_clk), .clk_b(pll_clk), .rst_n(rst_n),
        .sel(test_sel[1:0]), .data_in(messy_data_in[31:0]), .data_out(test_wire_out)
    );

    clock_latch_gen u_latch (
        .clk_in(sys_clk), .rst_n(rst_n), .gate_en(test_sel[0]),
        .sel(test_sel[1:0]), .data_in(messy_data_in[31:0]), .data_out(test_latch_out)
    );

    clock_long_chain u_chain (
        .clk_in(sys_clk), .rst_n(rst_n),
        .data_in(messy_data_in[31:0]), .data_out(test_chain_out)
    );

    clock_test_patterns u_patterns (
        .clk_a(ext_clk), .clk_b(pll_clk), .rst_n(rst_n),
        .sel(test_sel), .data_in(messy_data_in[31:0]), .data_out(test_pattern_out)
    );

endmodule
