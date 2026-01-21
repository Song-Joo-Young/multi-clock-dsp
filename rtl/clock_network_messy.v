//-----------------------------------------------------------------------------
// Module: clock_network_messy
// Description: Intentionally complex clock network
//              Combines feedback clocks and divided clocks
//              Multiple clock domains with cross-domain interactions
//-----------------------------------------------------------------------------

module clock_network_messy (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        enable,

    // Feedback control
    input  wire        feedback_en,

    // Data
    input  wire [63:0] data_in,
    output wire [63:0] data_out
);

    //=========================================================================
    // CLOCK GENERATION SECTION
    //=========================================================================

    //-------------------------------------------------------------------------
    // Regular Clock Divider Chain: clk_in -> div2 -> div4 -> div8
    //-------------------------------------------------------------------------
    reg clk_div2_reg, clk_div4_reg, clk_div8_reg;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) clk_div2_reg <= 1'b0;
        else if (enable) clk_div2_reg <= ~clk_div2_reg;
    end

    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) clk_div4_reg <= 1'b0;
        else if (enable) clk_div4_reg <= ~clk_div4_reg;
    end

    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) clk_div8_reg <= 1'b0;
        else if (enable) clk_div8_reg <= ~clk_div8_reg;
    end

    //-------------------------------------------------------------------------
    // Feedback Clock Divider: MUX -> REG -> MUX -> REG -> MUX -> REG -> feedback
    //-------------------------------------------------------------------------
    wire mux0_out, mux1_out, mux2_out;
    reg  fb_reg0, fb_reg1, fb_reg2;

    // MUX0: clk_in or feedback from fb_reg2
    assign mux0_out = feedback_en ? fb_reg2 : clk_in;

    // FB Stage 0
    always @(posedge mux0_out or negedge rst_n) begin
        if (!rst_n) fb_reg0 <= 1'b0;
        else if (enable) fb_reg0 <= ~fb_reg0;
    end

    // MUX1: fb_reg0 or bypass (clk_div2_reg)
    assign mux1_out = feedback_en ? fb_reg0 : clk_div2_reg;

    // FB Stage 1
    always @(posedge mux1_out or negedge rst_n) begin
        if (!rst_n) fb_reg1 <= 1'b0;
        else if (enable) fb_reg1 <= ~fb_reg1;
    end

    // MUX2: fb_reg1 or bypass (clk_div4_reg)
    assign mux2_out = feedback_en ? fb_reg1 : clk_div4_reg;

    // FB Stage 2 (output feeds back to MUX0)
    always @(posedge mux2_out or negedge rst_n) begin
        if (!rst_n) fb_reg2 <= 1'b0;
        else if (enable) fb_reg2 <= ~fb_reg2;
    end

    //-------------------------------------------------------------------------
    // Additional Mixed Clock: Combining div and feedback
    //-------------------------------------------------------------------------
    wire mixed_clk_a, mixed_clk_b;

    // Mixed clock A: MUX between div4 and fb_reg1
    assign mixed_clk_a = feedback_en ? fb_reg1 : clk_div4_reg;

    // Mixed clock B: MUX between div8 and fb_reg2
    assign mixed_clk_b = feedback_en ? fb_reg2 : clk_div8_reg;

    //=========================================================================
    // LOGIC USING clk_div2_reg (8 registers)
    //=========================================================================
    reg [7:0] d2_r0, d2_r1, d2_r2, d2_r3, d2_r4, d2_r5, d2_r6, d2_r7;

    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r0 <= 8'h0; else d2_r0 <= data_in[7:0];
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r1 <= 8'h0; else d2_r1 <= d2_r0 + 8'h1;
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r2 <= 8'h0; else d2_r2 <= d2_r1 ^ d2_r0;
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r3 <= 8'h0; else d2_r3 <= d2_r2 & d2_r1;
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r4 <= 8'h0; else d2_r4 <= d2_r3 | d2_r2;
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r5 <= 8'h0; else d2_r5 <= d2_r4 + d2_r3;
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r6 <= 8'h0; else d2_r6 <= d2_r5 - d2_r4;
    end
    always @(posedge clk_div2_reg or negedge rst_n) begin
        if (!rst_n) d2_r7 <= 8'h0; else d2_r7 <= d2_r6 ^ d2_r5;
    end

    //=========================================================================
    // LOGIC USING clk_div4_reg (8 registers)
    //=========================================================================
    reg [7:0] d4_r0, d4_r1, d4_r2, d4_r3, d4_r4, d4_r5, d4_r6, d4_r7;

    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r0 <= 8'h0; else d4_r0 <= data_in[15:8];
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r1 <= 8'h0; else d4_r1 <= d4_r0 + 8'h2;
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r2 <= 8'h0; else d4_r2 <= d4_r1 ^ d4_r0;
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r3 <= 8'h0; else d4_r3 <= d4_r2 & d4_r1;
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r4 <= 8'h0; else d4_r4 <= d4_r3 | d4_r2;
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r5 <= 8'h0; else d4_r5 <= d4_r4 + d4_r3;
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r6 <= 8'h0; else d4_r6 <= d4_r5 - d4_r4;
    end
    always @(posedge clk_div4_reg or negedge rst_n) begin
        if (!rst_n) d4_r7 <= 8'h0; else d4_r7 <= d4_r6 ^ d4_r5;
    end

    //=========================================================================
    // LOGIC USING clk_div8_reg (8 registers)
    //=========================================================================
    reg [7:0] d8_r0, d8_r1, d8_r2, d8_r3, d8_r4, d8_r5, d8_r6, d8_r7;

    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r0 <= 8'h0; else d8_r0 <= data_in[23:16];
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r1 <= 8'h0; else d8_r1 <= d8_r0 + 8'h4;
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r2 <= 8'h0; else d8_r2 <= d8_r1 ^ d8_r0;
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r3 <= 8'h0; else d8_r3 <= d8_r2 & d8_r1;
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r4 <= 8'h0; else d8_r4 <= d8_r3 | d8_r2;
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r5 <= 8'h0; else d8_r5 <= d8_r4 + d8_r3;
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r6 <= 8'h0; else d8_r6 <= d8_r5 - d8_r4;
    end
    always @(posedge clk_div8_reg or negedge rst_n) begin
        if (!rst_n) d8_r7 <= 8'h0; else d8_r7 <= d8_r6 ^ d8_r5;
    end

    //=========================================================================
    // LOGIC USING fb_reg0 (feedback clock stage 0) - 8 registers
    //=========================================================================
    reg [7:0] fb0_r0, fb0_r1, fb0_r2, fb0_r3, fb0_r4, fb0_r5, fb0_r6, fb0_r7;

    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r0 <= 8'h0; else fb0_r0 <= data_in[31:24];
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r1 <= 8'h0; else fb0_r1 <= fb0_r0 + 8'h10;
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r2 <= 8'h0; else fb0_r2 <= fb0_r1 ^ fb0_r0;
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r3 <= 8'h0; else fb0_r3 <= fb0_r2 & fb0_r1;
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r4 <= 8'h0; else fb0_r4 <= fb0_r3 | fb0_r2;
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r5 <= 8'h0; else fb0_r5 <= fb0_r4 + fb0_r3;
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r6 <= 8'h0; else fb0_r6 <= fb0_r5 - fb0_r4;
    end
    always @(posedge fb_reg0 or negedge rst_n) begin
        if (!rst_n) fb0_r7 <= 8'h0; else fb0_r7 <= fb0_r6 ^ fb0_r5;
    end

    //=========================================================================
    // LOGIC USING fb_reg1 (feedback clock stage 1) - 8 registers
    //=========================================================================
    reg [7:0] fb1_r0, fb1_r1, fb1_r2, fb1_r3, fb1_r4, fb1_r5, fb1_r6, fb1_r7;

    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r0 <= 8'h0; else fb1_r0 <= data_in[39:32];
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r1 <= 8'h0; else fb1_r1 <= fb1_r0 + 8'h20;
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r2 <= 8'h0; else fb1_r2 <= fb1_r1 ^ fb1_r0;
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r3 <= 8'h0; else fb1_r3 <= fb1_r2 & fb1_r1;
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r4 <= 8'h0; else fb1_r4 <= fb1_r3 | fb1_r2;
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r5 <= 8'h0; else fb1_r5 <= fb1_r4 + fb1_r3;
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r6 <= 8'h0; else fb1_r6 <= fb1_r5 - fb1_r4;
    end
    always @(posedge fb_reg1 or negedge rst_n) begin
        if (!rst_n) fb1_r7 <= 8'h0; else fb1_r7 <= fb1_r6 ^ fb1_r5;
    end

    //=========================================================================
    // LOGIC USING fb_reg2 (feedback clock stage 2, feeds back) - 8 registers
    //=========================================================================
    reg [7:0] fb2_r0, fb2_r1, fb2_r2, fb2_r3, fb2_r4, fb2_r5, fb2_r6, fb2_r7;

    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r0 <= 8'h0; else fb2_r0 <= data_in[47:40];
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r1 <= 8'h0; else fb2_r1 <= fb2_r0 + 8'h40;
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r2 <= 8'h0; else fb2_r2 <= fb2_r1 ^ fb2_r0;
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r3 <= 8'h0; else fb2_r3 <= fb2_r2 & fb2_r1;
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r4 <= 8'h0; else fb2_r4 <= fb2_r3 | fb2_r2;
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r5 <= 8'h0; else fb2_r5 <= fb2_r4 + fb2_r3;
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r6 <= 8'h0; else fb2_r6 <= fb2_r5 - fb2_r4;
    end
    always @(posedge fb_reg2 or negedge rst_n) begin
        if (!rst_n) fb2_r7 <= 8'h0; else fb2_r7 <= fb2_r6 ^ fb2_r5;
    end

    //=========================================================================
    // LOGIC USING mixed_clk_a (mux between div4 and fb_reg1) - 8 registers
    //=========================================================================
    reg [7:0] ma_r0, ma_r1, ma_r2, ma_r3, ma_r4, ma_r5, ma_r6, ma_r7;

    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r0 <= 8'h0; else ma_r0 <= data_in[55:48];
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r1 <= 8'h0; else ma_r1 <= ma_r0 + 8'h80;
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r2 <= 8'h0; else ma_r2 <= ma_r1 ^ ma_r0;
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r3 <= 8'h0; else ma_r3 <= ma_r2 & ma_r1;
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r4 <= 8'h0; else ma_r4 <= ma_r3 | ma_r2;
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r5 <= 8'h0; else ma_r5 <= ma_r4 + ma_r3;
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r6 <= 8'h0; else ma_r6 <= ma_r5 - ma_r4;
    end
    always @(posedge mixed_clk_a or negedge rst_n) begin
        if (!rst_n) ma_r7 <= 8'h0; else ma_r7 <= ma_r6 ^ ma_r5;
    end

    //=========================================================================
    // LOGIC USING mixed_clk_b (mux between div8 and fb_reg2) - 8 registers
    //=========================================================================
    reg [7:0] mb_r0, mb_r1, mb_r2, mb_r3, mb_r4, mb_r5, mb_r6, mb_r7;

    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r0 <= 8'h0; else mb_r0 <= data_in[63:56];
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r1 <= 8'h0; else mb_r1 <= mb_r0 + 8'hFF;
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r2 <= 8'h0; else mb_r2 <= mb_r1 ^ mb_r0;
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r3 <= 8'h0; else mb_r3 <= mb_r2 & mb_r1;
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r4 <= 8'h0; else mb_r4 <= mb_r3 | mb_r2;
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r5 <= 8'h0; else mb_r5 <= mb_r4 + mb_r3;
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r6 <= 8'h0; else mb_r6 <= mb_r5 - mb_r4;
    end
    always @(posedge mixed_clk_b or negedge rst_n) begin
        if (!rst_n) mb_r7 <= 8'h0; else mb_r7 <= mb_r6 ^ mb_r5;
    end

    //=========================================================================
    // OUTPUT: Combine all domains
    //=========================================================================
    assign data_out = {mb_r7, ma_r7, fb2_r7, fb1_r7, fb0_r7, d8_r7, d4_r7, d2_r7};

endmodule


//-----------------------------------------------------------------------------
// Module: messy_clk_with_icg
// Description: Even messier clock network with ICG on divided/feedback clocks
//-----------------------------------------------------------------------------

module messy_clk_with_icg (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        scan_enable,
    input  wire        enable,
    input  wire        feedback_en,

    // Per-domain enables
    input  wire        en_div2,
    input  wire        en_div4,
    input  wire        en_fb0,
    input  wire        en_fb1,
    input  wire        en_mixed,

    // Data
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    //=========================================================================
    // Clock Dividers
    //=========================================================================
    reg clk_div2, clk_div4;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) clk_div2 <= 1'b0;
        else if (enable) clk_div2 <= ~clk_div2;
    end

    always @(posedge clk_div2 or negedge rst_n) begin
        if (!rst_n) clk_div4 <= 1'b0;
        else if (enable) clk_div4 <= ~clk_div4;
    end

    //=========================================================================
    // Feedback Clock Chain
    //=========================================================================
    wire fb_mux0_out, fb_mux1_out;
    reg  fb_clk0, fb_clk1;

    assign fb_mux0_out = feedback_en ? fb_clk1 : clk_in;

    always @(posedge fb_mux0_out or negedge rst_n) begin
        if (!rst_n) fb_clk0 <= 1'b0;
        else if (enable) fb_clk0 <= ~fb_clk0;
    end

    assign fb_mux1_out = feedback_en ? fb_clk0 : clk_div2;

    always @(posedge fb_mux1_out or negedge rst_n) begin
        if (!rst_n) fb_clk1 <= 1'b0;
        else if (enable) fb_clk1 <= ~fb_clk1;
    end

    //=========================================================================
    // Mixed Clock (MUX of div4 and fb_clk1)
    //=========================================================================
    wire mixed_clk;
    assign mixed_clk = feedback_en ? fb_clk1 : clk_div4;

    //=========================================================================
    // ICG for each clock domain
    //=========================================================================
    wire clk_div2_gated, clk_div4_gated;
    wire clk_fb0_gated, clk_fb1_gated;
    wire clk_mixed_gated;

    clock_gating_cell u_icg_div2 (
        .clk_in(clk_div2), .enable(en_div2), .scan_enable(scan_enable), .clk_out(clk_div2_gated)
    );

    clock_gating_cell u_icg_div4 (
        .clk_in(clk_div4), .enable(en_div4), .scan_enable(scan_enable), .clk_out(clk_div4_gated)
    );

    clock_gating_cell u_icg_fb0 (
        .clk_in(fb_clk0), .enable(en_fb0), .scan_enable(scan_enable), .clk_out(clk_fb0_gated)
    );

    clock_gating_cell u_icg_fb1 (
        .clk_in(fb_clk1), .enable(en_fb1), .scan_enable(scan_enable), .clk_out(clk_fb1_gated)
    );

    clock_gating_cell u_icg_mixed (
        .clk_in(mixed_clk), .enable(en_mixed), .scan_enable(scan_enable), .clk_out(clk_mixed_gated)
    );

    //=========================================================================
    // Registers using gated clocks
    //=========================================================================
    reg [7:0] r_div2_0, r_div2_1, r_div2_2, r_div2_3;
    reg [7:0] r_div4_0, r_div4_1, r_div4_2, r_div4_3;
    reg [7:0] r_fb0_0, r_fb0_1, r_fb0_2, r_fb0_3;
    reg [7:0] r_fb1_0, r_fb1_1, r_fb1_2, r_fb1_3;
    reg [7:0] r_mix_0, r_mix_1, r_mix_2, r_mix_3;

    // DIV2 domain
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) r_div2_0 <= 8'h0; else r_div2_0 <= data_in[7:0];
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) r_div2_1 <= 8'h0; else r_div2_1 <= r_div2_0 + 8'h1;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) r_div2_2 <= 8'h0; else r_div2_2 <= r_div2_1 ^ r_div2_0;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) r_div2_3 <= 8'h0; else r_div2_3 <= r_div2_2 & r_div2_1;
    end

    // DIV4 domain
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) r_div4_0 <= 8'h0; else r_div4_0 <= data_in[15:8];
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) r_div4_1 <= 8'h0; else r_div4_1 <= r_div4_0 + 8'h2;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) r_div4_2 <= 8'h0; else r_div4_2 <= r_div4_1 ^ r_div4_0;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) r_div4_3 <= 8'h0; else r_div4_3 <= r_div4_2 & r_div4_1;
    end

    // FB0 domain
    always @(posedge clk_fb0_gated or negedge rst_n) begin
        if (!rst_n) r_fb0_0 <= 8'h0; else r_fb0_0 <= data_in[23:16];
    end
    always @(posedge clk_fb0_gated or negedge rst_n) begin
        if (!rst_n) r_fb0_1 <= 8'h0; else r_fb0_1 <= r_fb0_0 + 8'h4;
    end
    always @(posedge clk_fb0_gated or negedge rst_n) begin
        if (!rst_n) r_fb0_2 <= 8'h0; else r_fb0_2 <= r_fb0_1 ^ r_fb0_0;
    end
    always @(posedge clk_fb0_gated or negedge rst_n) begin
        if (!rst_n) r_fb0_3 <= 8'h0; else r_fb0_3 <= r_fb0_2 & r_fb0_1;
    end

    // FB1 domain
    always @(posedge clk_fb1_gated or negedge rst_n) begin
        if (!rst_n) r_fb1_0 <= 8'h0; else r_fb1_0 <= data_in[31:24];
    end
    always @(posedge clk_fb1_gated or negedge rst_n) begin
        if (!rst_n) r_fb1_1 <= 8'h0; else r_fb1_1 <= r_fb1_0 + 8'h8;
    end
    always @(posedge clk_fb1_gated or negedge rst_n) begin
        if (!rst_n) r_fb1_2 <= 8'h0; else r_fb1_2 <= r_fb1_1 ^ r_fb1_0;
    end
    always @(posedge clk_fb1_gated or negedge rst_n) begin
        if (!rst_n) r_fb1_3 <= 8'h0; else r_fb1_3 <= r_fb1_2 & r_fb1_1;
    end

    // MIXED domain
    always @(posedge clk_mixed_gated or negedge rst_n) begin
        if (!rst_n) r_mix_0 <= 8'h0; else r_mix_0 <= r_div2_3 ^ r_fb0_3;
    end
    always @(posedge clk_mixed_gated or negedge rst_n) begin
        if (!rst_n) r_mix_1 <= 8'h0; else r_mix_1 <= r_div4_3 ^ r_fb1_3;
    end
    always @(posedge clk_mixed_gated or negedge rst_n) begin
        if (!rst_n) r_mix_2 <= 8'h0; else r_mix_2 <= r_mix_0 + r_mix_1;
    end
    always @(posedge clk_mixed_gated or negedge rst_n) begin
        if (!rst_n) r_mix_3 <= 8'h0; else r_mix_3 <= r_mix_2 ^ r_mix_0;
    end

    //=========================================================================
    // Output
    //=========================================================================
    assign data_out = {r_mix_3, r_fb1_3, r_fb0_3, r_div4_3};

endmodule
