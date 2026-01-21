//-----------------------------------------------------------------------------
// Module: clock_multi_path
// Description: Multiple parallel clock buffer chains
//-----------------------------------------------------------------------------

module clock_multi_path (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire [1:0]  path_sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    // Chain A
    wire clk_buf_a1 = clk_in;
    wire clk_buf_a2 = clk_buf_a1;
    wire clk_buf_a3 = clk_buf_a2;

    // Chain B
    wire clk_buf_b1 = clk_in;
    wire clk_buf_b2 = clk_buf_b1;
    wire clk_buf_b3 = clk_buf_b2;

    wire clk_merged_or = clk_buf_a3 | clk_buf_b3;
    wire clk_merged_sel = path_sel[0] ? clk_buf_a3 : clk_buf_b3;
    wire clk_cross_a = path_sel[1] ? clk_buf_a2 : clk_buf_b2;

    reg [7:0] a1_r, a2_r, a3_r;
    reg [7:0] b1_r, b2_r, b3_r;
    reg [7:0] merged_or_r, merged_sel_r, cross_r;

    always @(posedge clk_buf_a1 or negedge rst_n)
        if (!rst_n) a1_r <= 8'h0; else a1_r <= data_in[7:0];
    always @(posedge clk_buf_a2 or negedge rst_n)
        if (!rst_n) a2_r <= 8'h0; else a2_r <= data_in[15:8];
    always @(posedge clk_buf_a3 or negedge rst_n)
        if (!rst_n) a3_r <= 8'h0; else a3_r <= data_in[23:16];

    always @(posedge clk_buf_b1 or negedge rst_n)
        if (!rst_n) b1_r <= 8'h0; else b1_r <= data_in[7:0] ^ 8'hAA;
    always @(posedge clk_buf_b2 or negedge rst_n)
        if (!rst_n) b2_r <= 8'h0; else b2_r <= data_in[15:8] ^ 8'h55;
    always @(posedge clk_buf_b3 or negedge rst_n)
        if (!rst_n) b3_r <= 8'h0; else b3_r <= data_in[23:16] ^ 8'hFF;

    always @(posedge clk_merged_or or negedge rst_n)
        if (!rst_n) merged_or_r <= 8'h0; else merged_or_r <= a3_r ^ b3_r;
    always @(posedge clk_merged_sel or negedge rst_n)
        if (!rst_n) merged_sel_r <= 8'h0; else merged_sel_r <= a3_r + b3_r;
    always @(posedge clk_cross_a or negedge rst_n)
        if (!rst_n) cross_r <= 8'h0; else cross_r <= a2_r | b2_r;

    assign data_out = {merged_or_r, merged_sel_r, cross_r, a1_r^b1_r};

endmodule
