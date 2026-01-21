//-----------------------------------------------------------------------------
// Module: clock_cross_primary
// Description: Clocks from two independent primary sources
//-----------------------------------------------------------------------------

module clock_cross_primary (
    input  wire        clk_ext,
    input  wire        clk_pll,
    input  wire        rst_n,
    input  wire [1:0]  sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    reg clk_ext_div2, clk_pll_div2;

    always @(posedge clk_ext or negedge rst_n)
        if (!rst_n) clk_ext_div2 <= 1'b0; else clk_ext_div2 <= ~clk_ext_div2;

    always @(posedge clk_pll or negedge rst_n)
        if (!rst_n) clk_pll_div2 <= 1'b0; else clk_pll_div2 <= ~clk_pll_div2;

    wire clk_cross_or  = clk_ext_div2 | clk_pll_div2;
    wire clk_cross_and = clk_ext_div2 & clk_pll_div2;
    wire clk_cross_xor = clk_ext_div2 ^ clk_pll_div2;
    wire clk_cross_mux = sel[0] ? clk_ext_div2 : clk_pll_div2;

    reg [7:0] ext_r, pll_r;
    reg [7:0] or_r, and_r, xor_r, mux_r;

    always @(posedge clk_ext_div2 or negedge rst_n)
        if (!rst_n) ext_r <= 8'h0; else ext_r <= data_in[7:0];

    always @(posedge clk_pll_div2 or negedge rst_n)
        if (!rst_n) pll_r <= 8'h0; else pll_r <= data_in[15:8];

    always @(posedge clk_cross_or or negedge rst_n)
        if (!rst_n) or_r <= 8'h0; else or_r <= ext_r ^ pll_r;

    always @(posedge clk_cross_and or negedge rst_n)
        if (!rst_n) and_r <= 8'h0; else and_r <= ext_r & pll_r;

    always @(posedge clk_cross_xor or negedge rst_n)
        if (!rst_n) xor_r <= 8'h0; else xor_r <= ext_r | pll_r;

    always @(posedge clk_cross_mux or negedge rst_n)
        if (!rst_n) mux_r <= 8'h0; else mux_r <= ext_r + pll_r;

    assign data_out = {or_r, and_r, xor_r, mux_r};

endmodule
