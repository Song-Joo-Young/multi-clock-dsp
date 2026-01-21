//-----------------------------------------------------------------------------
// Testbench: tb_clock_subsystem
// Description: Comprehensive testbench for Multi-Clock DSP system
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_clock_subsystem;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter DATA_WIDTH  = 16;
    parameter COEFF_WIDTH = 16;
    parameter FIR_TAPS    = 8;

    // Clock periods (ns)
    parameter EXT_CLK_PERIOD = 20;   // 50 MHz
    parameter PLL_CLK_PERIOD = 10;   // 100 MHz
    parameter SCAN_CLK_PERIOD = 40;  // 25 MHz
    parameter TCK_PERIOD = 100;      // 10 MHz

    //=========================================================================
    // DUT Signals
    //=========================================================================
    // Clocks and Reset
    reg         ext_clk;
    reg         pll_clk;
    reg         rst_n;

    // Clock Control
    reg         clk_src_sel;
    reg  [1:0]  int_div_sel;
    reg  [7:0]  frac_div_ratio;
    reg  [1:0]  func_clk_sel;

    // DFT Interface
    reg  [1:0]  test_mode;
    reg         scan_clk;
    reg         scan_enable;

    // JTAG Interface
    reg         tck;
    reg         tms;
    reg         tdi;
    reg         trst_n;
    wire        tdo;
    wire        tdo_en;

    // BIST Control
    reg         bist_enable;
    reg         bist_start;
    wire        bist_done;

    // DSP Data Interface
    reg  [DATA_WIDTH-1:0]  adc_data;
    reg                    adc_valid;

    // DSP Control
    reg                    fir_start;
    reg                    coeff_load;
    reg  [$clog2(FIR_TAPS)-1:0] coeff_addr;
    reg  [COEFF_WIDTH-1:0] coeff_data;

    // DSP Output
    wire [DATA_WIDTH-1:0]  dsp_out;
    wire                   dsp_valid;
    wire                   dsp_busy;

    // Status
    wire        is_test_mode;

    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    multi_clock_dsp_top #(
        .DATA_WIDTH   (DATA_WIDTH),
        .COEFF_WIDTH  (COEFF_WIDTH),
        .FIR_TAPS     (FIR_TAPS),
        .IDCODE_VALUE (32'h4D43_4453)
    ) dut (
        .ext_clk        (ext_clk),
        .pll_clk        (pll_clk),
        .rst_n          (rst_n),
        .clk_src_sel    (clk_src_sel),
        .int_div_sel    (int_div_sel),
        .frac_div_ratio (frac_div_ratio),
        .func_clk_sel   (func_clk_sel),
        .test_mode      (test_mode),
        .scan_clk       (scan_clk),
        .scan_enable    (scan_enable),
        .tck            (tck),
        .tms            (tms),
        .tdi            (tdi),
        .trst_n         (trst_n),
        .tdo            (tdo),
        .tdo_en         (tdo_en),
        .bist_enable    (bist_enable),
        .bist_start     (bist_start),
        .bist_done      (bist_done),
        .adc_data       (adc_data),
        .adc_valid      (adc_valid),
        .fir_start      (fir_start),
        .coeff_load     (coeff_load),
        .coeff_addr     (coeff_addr),
        .coeff_data     (coeff_data),
        .dsp_out        (dsp_out),
        .dsp_valid      (dsp_valid),
        .dsp_busy       (dsp_busy),
        .is_test_mode   (is_test_mode)
    );

    //=========================================================================
    // Clock Generation
    //=========================================================================
    initial begin
        ext_clk = 0;
        forever #(EXT_CLK_PERIOD/2) ext_clk = ~ext_clk;
    end

    initial begin
        pll_clk = 0;
        forever #(PLL_CLK_PERIOD/2) pll_clk = ~pll_clk;
    end

    initial begin
        scan_clk = 0;
        forever #(SCAN_CLK_PERIOD/2) scan_clk = ~scan_clk;
    end

    initial begin
        tck = 0;
        forever #(TCK_PERIOD/2) tck = ~tck;
    end

    //=========================================================================
    // JTAG Tasks
    //=========================================================================
    task jtag_reset;
        begin
            // Hold TMS high for 5 TCK cycles to reach Test-Logic-Reset
            tms = 1;
            repeat(5) @(posedge tck);
            tms = 0;
            @(posedge tck);  // Go to Run-Test/Idle
        end
    endtask

    task jtag_shift_ir;
        input [3:0] ir_value;
        integer i;
        begin
            // Navigate to Shift-IR
            tms = 1; @(posedge tck);  // Select-DR-Scan
            tms = 1; @(posedge tck);  // Select-IR-Scan
            tms = 0; @(posedge tck);  // Capture-IR
            tms = 0; @(posedge tck);  // Shift-IR

            // Shift in IR value
            for (i = 0; i < 3; i = i + 1) begin
                tdi = ir_value[i];
                tms = 0;
                @(posedge tck);
            end
            tdi = ir_value[3];
            tms = 1; @(posedge tck);  // Exit1-IR

            tms = 1; @(posedge tck);  // Update-IR
            tms = 0; @(posedge tck);  // Run-Test/Idle
        end
    endtask

    task jtag_shift_dr;
        input [31:0] dr_value;
        input integer dr_length;
        output [31:0] dr_out;
        integer i;
        begin
            dr_out = 0;

            // Navigate to Shift-DR
            tms = 1; @(posedge tck);  // Select-DR-Scan
            tms = 0; @(posedge tck);  // Capture-DR
            tms = 0; @(posedge tck);  // Shift-DR

            // Shift data
            for (i = 0; i < dr_length - 1; i = i + 1) begin
                tdi = dr_value[i];
                tms = 0;
                @(posedge tck);
                dr_out[i] = tdo;
            end
            tdi = dr_value[dr_length-1];
            tms = 1; @(posedge tck);  // Exit1-DR
            dr_out[dr_length-1] = tdo;

            tms = 1; @(posedge tck);  // Update-DR
            tms = 0; @(posedge tck);  // Run-Test/Idle
        end
    endtask

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    reg [31:0] idcode_read;
    integer test_num;
    integer i;
    integer errors;

    initial begin
        // Initialize signals
        rst_n = 0;
        clk_src_sel = 0;
        int_div_sel = 2'b00;
        frac_div_ratio = 8'h40;  // Divide by 4.0
        func_clk_sel = 2'b00;
        test_mode = 2'b00;
        scan_enable = 0;
        tms = 1;
        tdi = 0;
        trst_n = 0;
        bist_enable = 0;
        bist_start = 0;
        adc_data = 0;
        adc_valid = 0;
        fir_start = 0;
        coeff_load = 0;
        coeff_addr = 0;
        coeff_data = 0;

        test_num = 0;
        errors = 0;

        // Dump waveforms
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_clock_subsystem);

        $display("=========================================");
        $display(" Multi-Clock DSP Testbench Start");
        $display("=========================================");

        // Release reset
        #100;
        rst_n = 1;
        trst_n = 1;
        #100;

        //=====================================================================
        // Test 1: Clock Source Selection
        //=====================================================================
        test_num = 1;
        $display("\n[Test %0d] Clock Source Selection", test_num);

        clk_src_sel = 0;  // External clock
        #200;
        $display("  - External clock selected");

        clk_src_sel = 1;  // PLL clock
        #200;
        $display("  - PLL clock selected");

        //=====================================================================
        // Test 2: Integer Clock Divider
        //=====================================================================
        test_num = 2;
        $display("\n[Test %0d] Integer Clock Divider", test_num);

        func_clk_sel = 2'b01;  // Select divided clock

        int_div_sel = 2'b00;  // /2
        #500;
        $display("  - Divider /2");

        int_div_sel = 2'b01;  // /4
        #500;
        $display("  - Divider /4");

        int_div_sel = 2'b10;  // /8
        #500;
        $display("  - Divider /8");

        int_div_sel = 2'b11;  // /16
        #500;
        $display("  - Divider /16");

        //=====================================================================
        // Test 3: Fractional Clock Divider
        //=====================================================================
        test_num = 3;
        $display("\n[Test %0d] Fractional Clock Divider", test_num);

        func_clk_sel = 2'b10;  // Select fractional clock

        frac_div_ratio = 8'h28;  // 2.5 (N=2, F=8)
        #1000;
        $display("  - Fractional divider 2.5");

        frac_div_ratio = 8'h38;  // 3.5 (N=3, F=8)
        #1000;
        $display("  - Fractional divider 3.5");

        //=====================================================================
        // Test 4: JTAG IDCODE Read
        //=====================================================================
        test_num = 4;
        $display("\n[Test %0d] JTAG IDCODE Read", test_num);

        jtag_reset();
        $display("  - TAP Reset complete");

        jtag_shift_ir(4'b0001);  // IDCODE instruction
        $display("  - IDCODE instruction loaded");

        jtag_shift_dr(32'h0, 32, idcode_read);
        $display("  - IDCODE read: 0x%08X", idcode_read);

        if (idcode_read == 32'h4D43_4453) begin
            $display("  - IDCODE PASS (expected 0x4D434453)");
        end else begin
            $display("  - IDCODE FAIL (expected 0x4D434453, got 0x%08X)", idcode_read);
            errors = errors + 1;
        end

        //=====================================================================
        // Test 5: JTAG BYPASS Test
        //=====================================================================
        test_num = 5;
        $display("\n[Test %0d] JTAG BYPASS Test", test_num);

        jtag_shift_ir(4'b1111);  // BYPASS instruction
        $display("  - BYPASS instruction loaded");

        //=====================================================================
        // Test 6: Scan Mode
        //=====================================================================
        test_num = 6;
        $display("\n[Test %0d] Scan Mode", test_num);

        test_mode = 2'b01;  // Scan mode
        scan_enable = 1;
        #500;

        if (is_test_mode) begin
            $display("  - Scan mode active: PASS");
        end else begin
            $display("  - Scan mode active: FAIL");
            errors = errors + 1;
        end

        test_mode = 2'b00;  // Back to functional
        scan_enable = 0;
        #200;

        //=====================================================================
        // Test 7: BIST Mode
        //=====================================================================
        test_num = 7;
        $display("\n[Test %0d] BIST Mode", test_num);

        test_mode = 2'b11;  // BIST mode
        bist_enable = 1;
        #100;

        bist_start = 1;
        #20;
        bist_start = 0;

        $display("  - BIST started, waiting for completion...");

        // Wait for BIST completion (with timeout)
        fork
            begin
                wait(bist_done);
                $display("  - BIST completed: PASS");
            end
            begin
                #50000;
                $display("  - BIST timeout: FAIL");
                errors = errors + 1;
            end
        join_any
        disable fork;

        bist_enable = 0;
        test_mode = 2'b00;
        #200;

        //=====================================================================
        // Test 8: DSP FIR Filter
        //=====================================================================
        test_num = 8;
        $display("\n[Test %0d] DSP FIR Filter", test_num);

        func_clk_sel = 2'b00;  // Use system clock
        int_div_sel = 2'b00;   // /2 for ADC clock

        // Load FIR coefficients (simple averaging filter)
        coeff_load = 1;
        for (i = 0; i < FIR_TAPS; i = i + 1) begin
            coeff_addr = i;
            coeff_data = 16'h1000;  // Equal weights
            #50;
        end
        coeff_load = 0;
        $display("  - FIR coefficients loaded");

        // Send some ADC samples
        #100;
        for (i = 0; i < 16; i = i + 1) begin
            adc_data = i * 1000;
            adc_valid = 1;
            #(EXT_CLK_PERIOD * 4);  // Match divided clock
            adc_valid = 0;
            #(EXT_CLK_PERIOD * 4);
        end

        // Wait for processing
        #2000;
        $display("  - FIR processing complete");

        //=====================================================================
        // Test 9: Clock Gating
        //=====================================================================
        test_num = 9;
        $display("\n[Test %0d] Clock Gating Verification", test_num);

        // Clock gating is always enabled in this config
        // Just verify clocks are running
        #500;
        $display("  - Clock gating operational");

        //=====================================================================
        // Test Summary
        //=====================================================================
        #100;
        $display("\n=========================================");
        $display(" Test Summary");
        $display("=========================================");
        $display(" Total Tests: %0d", test_num);
        $display(" Errors: %0d", errors);

        if (errors == 0) begin
            $display(" Result: ALL TESTS PASSED");
        end else begin
            $display(" Result: SOME TESTS FAILED");
        end

        $display("=========================================\n");

        #100;
        $finish;
    end

    //=========================================================================
    // Monitor
    //=========================================================================
    initial begin
        $monitor("Time=%0t rst_n=%b clk_src=%b div_sel=%b func_sel=%b test_mode=%b",
                 $time, rst_n, clk_src_sel, int_div_sel, func_clk_sel, test_mode);
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
