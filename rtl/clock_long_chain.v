//-----------------------------------------------------------------------------
// Module: clock_long_chain
// Description: Long clock assignment chains
//-----------------------------------------------------------------------------

module clock_long_chain (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    // 16-level chain
    wire clk_c00 = clk_in;
    wire clk_c01 = clk_c00;
    wire clk_c02 = clk_c01;
    wire clk_c03 = clk_c02;
    wire clk_c04 = clk_c03;
    wire clk_c05 = clk_c04;
    wire clk_c06 = clk_c05;
    wire clk_c07 = clk_c06;
    wire clk_c08 = clk_c07;
    wire clk_c09 = clk_c08;
    wire clk_c10 = clk_c09;
    wire clk_c11 = clk_c10;
    wire clk_c12 = clk_c11;
    wire clk_c13 = clk_c12;
    wire clk_c14 = clk_c13;
    wire clk_c15 = clk_c14;

    reg [7:0] r00, r08, r15;

    always @(posedge clk_c00 or negedge rst_n)
        if (!rst_n) r00 <= 8'h0; else r00 <= data_in[7:0];

    always @(posedge clk_c08 or negedge rst_n)
        if (!rst_n) r08 <= 8'h0; else r08 <= data_in[15:8];

    always @(posedge clk_c15 or negedge rst_n)
        if (!rst_n) r15 <= 8'h0; else r15 <= r00 ^ r08;

    // Second chain with divider
    reg clk_div2;
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_div2 <= 1'b0; else clk_div2 <= ~clk_div2;

    wire clk_d00 = clk_div2;
    wire clk_d01 = clk_d00;
    wire clk_d02 = clk_d01;
    wire clk_d03 = clk_d02;
    wire clk_d04 = clk_d03;
    wire clk_d05 = clk_d04;
    wire clk_d06 = clk_d05;
    wire clk_d07 = clk_d06;

    reg [7:0] d00, d07;

    always @(posedge clk_d00 or negedge rst_n)
        if (!rst_n) d00 <= 8'h0; else d00 <= r15 + 8'h11;

    always @(posedge clk_d07 or negedge rst_n)
        if (!rst_n) d07 <= 8'h0; else d07 <= d00 + 8'h22;

    wire clk_cross = clk_c08 | clk_d04;
    reg [7:0] cross_r;
    always @(posedge clk_cross or negedge rst_n)
        if (!rst_n) cross_r <= 8'h0; else cross_r <= r08 ^ d00;

    assign data_out = {r15, d07, cross_r, 8'h00};

endmodule
