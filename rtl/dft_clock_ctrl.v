//-----------------------------------------------------------------------------
// Module: dft_clock_ctrl
// Description: DFT Clock Controller
//              Manages clock selection for different test modes
//              (Functional, Scan, JTAG, BIST)
//-----------------------------------------------------------------------------

module dft_clock_ctrl (
    // Reference clocks
    input  wire        func_clk,       // Functional clock
    input  wire        scan_clk,       // Scan test clock (external)
    input  wire        tck,            // JTAG TCK
    input  wire        bist_clk,       // BIST clock (from bist_clock_ctrl)

    // Reset
    input  wire        rst_n,          // Async reset (active low)

    // DFT mode control
    input  wire [1:0]  test_mode,      // Test mode select
                                       // 00: Functional
                                       // 01: Scan
                                       // 10: JTAG
                                       // 11: BIST
    input  wire        scan_enable,    // Scan enable signal
    input  wire        dft_bypass,     // Bypass all DFT (use func_clk directly)

    // Output clock
    output wire        dft_clk_out,    // Selected DFT clock output
    output wire        core_clk_out,   // Final core clock (func or dft)

    // Status outputs
    output wire        is_test_mode,   // Indicates any test mode active
    output wire        is_scan_mode,   // Scan mode active
    output wire        is_jtag_mode,   // JTAG mode active
    output wire        is_bist_mode,   // BIST mode active
    output wire        scan_en_sync    // Synchronized scan enable
);

    //=========================================================================
    // Test Mode Encoding
    //=========================================================================
    localparam [1:0]
        MODE_FUNCTIONAL = 2'b00,
        MODE_SCAN       = 2'b01,
        MODE_JTAG       = 2'b10,
        MODE_BIST       = 2'b11;

    //=========================================================================
    // Mode decode
    //=========================================================================
    assign is_test_mode = (test_mode != MODE_FUNCTIONAL);
    assign is_scan_mode = (test_mode == MODE_SCAN);
    assign is_jtag_mode = (test_mode == MODE_JTAG);
    assign is_bist_mode = (test_mode == MODE_BIST);

    //=========================================================================
    // Scan Enable Synchronizer (sync to func_clk domain)
    //=========================================================================
    reg [1:0] scan_en_sync_reg;

    always @(posedge func_clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_en_sync_reg <= 2'b00;
        end else begin
            scan_en_sync_reg <= {scan_en_sync_reg[0], scan_enable};
        end
    end

    assign scan_en_sync = scan_en_sync_reg[1];

    //=========================================================================
    // DFT Clock MUX (4:1 selection)
    //=========================================================================
    // Using simple mux here since test mode changes only during reset/idle
    // For production, may need glitch-free switching

    reg dft_clk_mux;

    always @(*) begin
        case (test_mode)
            MODE_FUNCTIONAL: dft_clk_mux = func_clk;
            MODE_SCAN:       dft_clk_mux = scan_clk;
            MODE_JTAG:       dft_clk_mux = tck;
            MODE_BIST:       dft_clk_mux = bist_clk;
            default:         dft_clk_mux = func_clk;
        endcase
    end

    assign dft_clk_out = dft_clk_mux;

    //=========================================================================
    // Final Core Clock Selection
    // - Use func_clk when in functional mode or DFT bypass
    // - Use dft_clk_out when in test mode
    //=========================================================================
    assign core_clk_out = (dft_bypass || !is_test_mode) ? func_clk : dft_clk_out;

endmodule


//-----------------------------------------------------------------------------
// Module: dft_clock_ctrl_glitchfree
// Description: DFT Clock Controller with glitch-free switching
//              Use when test mode may change during operation
//-----------------------------------------------------------------------------

module dft_clock_ctrl_glitchfree (
    // Reference clocks
    input  wire        func_clk,
    input  wire        scan_clk,
    input  wire        tck,
    input  wire        bist_clk,

    // Reset
    input  wire        rst_n,

    // DFT mode control
    input  wire [1:0]  test_mode,
    input  wire        scan_enable,
    input  wire        dft_bypass,

    // Output clock
    output wire        dft_clk_out,
    output wire        core_clk_out,

    // Status outputs
    output wire        is_test_mode,
    output wire        is_scan_mode,
    output wire        is_jtag_mode,
    output wire        is_bist_mode,
    output wire        scan_en_sync
);

    //=========================================================================
    // Mode decode
    //=========================================================================
    localparam [1:0]
        MODE_FUNCTIONAL = 2'b00,
        MODE_SCAN       = 2'b01,
        MODE_JTAG       = 2'b10,
        MODE_BIST       = 2'b11;

    assign is_test_mode = (test_mode != MODE_FUNCTIONAL);
    assign is_scan_mode = (test_mode == MODE_SCAN);
    assign is_jtag_mode = (test_mode == MODE_JTAG);
    assign is_bist_mode = (test_mode == MODE_BIST);

    //=========================================================================
    // Scan Enable Synchronizer
    //=========================================================================
    reg [1:0] scan_en_sync_reg;

    always @(posedge func_clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_en_sync_reg <= 2'b00;
        end else begin
            scan_en_sync_reg <= {scan_en_sync_reg[0], scan_enable};
        end
    end

    assign scan_en_sync = scan_en_sync_reg[1];

    //=========================================================================
    // Glitch-free 4:1 Clock MUX
    //=========================================================================
    clk_mux_4to1 u_dft_clk_mux (
        .clk_0   (func_clk),
        .clk_1   (scan_clk),
        .clk_2   (tck),
        .clk_3   (bist_clk),
        .sel     (test_mode),
        .rst_n   (rst_n),
        .clk_out (dft_clk_out)
    );

    //=========================================================================
    // Final Core Clock Selection (glitch-free)
    //=========================================================================
    wire bypass_sel;
    assign bypass_sel = dft_bypass | ~is_test_mode;

    clk_mux_2to1 u_core_clk_mux (
        .clk_a   (dft_clk_out),
        .clk_b   (func_clk),
        .sel     (bypass_sel),
        .rst_n   (rst_n),
        .clk_out (core_clk_out)
    );

endmodule


//-----------------------------------------------------------------------------
// Module: scan_clock_gate
// Description: Scan-aware clock gating with DFT control
//              Wraps ICG with scan enable bypass
//-----------------------------------------------------------------------------

module scan_clock_gate (
    input  wire clk_in,       // Input clock
    input  wire rst_n,        // Async reset
    input  wire enable,       // Functional enable
    input  wire scan_mode,    // Scan mode indicator
    input  wire scan_enable,  // Scan enable (bypasses gating)
    output wire clk_out       // Gated clock
);

    // In scan mode, bypass clock gating via scan_enable
    wire gate_enable;
    assign gate_enable = enable | (scan_mode & scan_enable);

    // Instantiate ICG cell
    clock_gating_cell u_icg (
        .clk_in      (clk_in),
        .enable      (gate_enable),
        .scan_enable (scan_enable),
        .clk_out     (clk_out)
    );

endmodule
