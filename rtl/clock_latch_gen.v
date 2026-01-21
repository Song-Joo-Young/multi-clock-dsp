//-----------------------------------------------------------------------------
// Module: clock_latch_gen
// Description: Latch-based clock gating
//-----------------------------------------------------------------------------

module clock_latch_gen (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        gate_en,
    input  wire [1:0]  sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    reg clk_div2, clk_div4;

    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_div2 <= 1'b0; else clk_div2 <= ~clk_div2;

    always @(posedge clk_div2 or negedge rst_n)
        if (!rst_n) clk_div4 <= 1'b0; else clk_div4 <= ~clk_div4;

    // Latch-based gating
    reg gate_latch, gate_latch_div2;
    always @(*) if (~clk_in) gate_latch <= gate_en;
    always @(*) if (~clk_div2) gate_latch_div2 <= gate_en;

    wire clk_gated = clk_in & gate_latch;
    wire clk_gated_div2 = clk_div2 & gate_latch_div2;
    wire clk_combined = clk_gated | clk_gated_div2;

    reg [7:0] gated_r, gated_div2_r, combined_r, div4_r;

    always @(posedge clk_gated or negedge rst_n)
        if (!rst_n) gated_r <= 8'h0; else gated_r <= data_in[7:0];

    always @(posedge clk_gated_div2 or negedge rst_n)
        if (!rst_n) gated_div2_r <= 8'h0; else gated_div2_r <= data_in[15:8];

    always @(posedge clk_combined or negedge rst_n)
        if (!rst_n) combined_r <= 8'h0; else combined_r <= gated_r ^ gated_div2_r;

    always @(posedge clk_div4 or negedge rst_n)
        if (!rst_n) div4_r <= 8'h0; else div4_r <= data_in[31:24];

    assign data_out = {gated_r, gated_div2_r, combined_r, div4_r};

endmodule
