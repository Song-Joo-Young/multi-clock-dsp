//-----------------------------------------------------------------------------
// Module: clock_wire_conflict
// Description: Wire aliasing patterns
//-----------------------------------------------------------------------------

module clock_wire_conflict (
    input  wire        clk_a,
    input  wire        clk_b,
    input  wire        rst_n,
    input  wire [1:0]  sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    reg clk_a_div2, clk_b_div2;

    always @(posedge clk_a or negedge rst_n)
        if (!rst_n) clk_a_div2 <= 1'b0; else clk_a_div2 <= ~clk_a_div2;

    always @(posedge clk_b or negedge rst_n)
        if (!rst_n) clk_b_div2 <= 1'b0; else clk_b_div2 <= ~clk_b_div2;

    // Aliasing
    wire clk_alias_1 = clk_a_div2;
    wire clk_alias_2 = clk_alias_1;
    wire clk_alias_3 = clk_alias_2;
    wire clk_alias_b1 = clk_b_div2;
    wire clk_alias_b2 = clk_alias_b1;
    wire clk_alias_b3 = clk_alias_b2;

    wire clk_combo_1 = clk_alias_1 | clk_alias_b1;
    wire clk_combo_2 = clk_alias_2 | clk_alias_b2;
    wire clk_cross_12 = clk_alias_1 | clk_alias_b2;

    reg [7:0] alias1_r, alias2_r, alias3_r;
    reg [7:0] combo1_r, combo2_r, cross12_r;

    always @(posedge clk_alias_1 or negedge rst_n)
        if (!rst_n) alias1_r <= 8'h0; else alias1_r <= data_in[7:0];
    always @(posedge clk_alias_2 or negedge rst_n)
        if (!rst_n) alias2_r <= 8'h0; else alias2_r <= data_in[15:8];
    always @(posedge clk_alias_3 or negedge rst_n)
        if (!rst_n) alias3_r <= 8'h0; else alias3_r <= data_in[23:16];

    always @(posedge clk_combo_1 or negedge rst_n)
        if (!rst_n) combo1_r <= 8'h0; else combo1_r <= alias1_r ^ alias2_r;
    always @(posedge clk_combo_2 or negedge rst_n)
        if (!rst_n) combo2_r <= 8'h0; else combo2_r <= alias2_r ^ alias3_r;
    always @(posedge clk_cross_12 or negedge rst_n)
        if (!rst_n) cross12_r <= 8'h0; else cross12_r <= alias3_r + 8'h30;

    assign data_out = {alias3_r, combo2_r, cross12_r, combo1_r};

endmodule
