//-----------------------------------------------------------------------------
// Module: clock_reconvergence
// Description: Clock reconvergence patterns
//-----------------------------------------------------------------------------

module clock_reconvergence (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        sel_a,
    input  wire        sel_b,
    input  wire        sel_final,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    // Path A: clk_in -> div2_a -> div4_a
    reg clk_div2_a, clk_div4_a;
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_div2_a <= 1'b0; else clk_div2_a <= ~clk_div2_a;
    always @(posedge clk_div2_a or negedge rst_n)
        if (!rst_n) clk_div4_a <= 1'b0; else clk_div4_a <= ~clk_div4_a;

    // Path B: clk_in -> div2_b -> div4_b
    reg clk_div2_b, clk_div4_b;
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_div2_b <= 1'b0; else clk_div2_b <= ~clk_div2_b;
    always @(posedge clk_div2_b or negedge rst_n)
        if (!rst_n) clk_div4_b <= 1'b0; else clk_div4_b <= ~clk_div4_b;

    // MUX selections
    wire clk_mux_a = sel_a ? clk_div2_a : clk_div4_a;
    wire clk_mux_b = sel_b ? clk_div2_b : clk_div4_b;
    wire clk_final = sel_final ? clk_mux_a : clk_mux_b;

    // Registers
    reg [7:0] path_a_r0, path_a_r1, path_b_r0, path_b_r1;
    reg [7:0] mux_a_r0, mux_a_r1, mux_b_r0, mux_b_r1;
    reg [7:0] final_r0, final_r1, final_r2, final_r3;

    always @(posedge clk_div4_a or negedge rst_n)
        if (!rst_n) begin path_a_r0 <= 8'h0; path_a_r1 <= 8'h0; end
        else begin path_a_r0 <= data_in[7:0]; path_a_r1 <= path_a_r0+8'h1; end

    always @(posedge clk_div4_b or negedge rst_n)
        if (!rst_n) begin path_b_r0 <= 8'h0; path_b_r1 <= 8'h0; end
        else begin path_b_r0 <= data_in[15:8]; path_b_r1 <= path_b_r0+8'h2; end

    always @(posedge clk_mux_a or negedge rst_n)
        if (!rst_n) begin mux_a_r0 <= 8'h0; mux_a_r1 <= 8'h0; end
        else begin mux_a_r0 <= path_a_r1; mux_a_r1 <= mux_a_r0+8'h3; end

    always @(posedge clk_mux_b or negedge rst_n)
        if (!rst_n) begin mux_b_r0 <= 8'h0; mux_b_r1 <= 8'h0; end
        else begin mux_b_r0 <= path_b_r1; mux_b_r1 <= mux_b_r0+8'h4; end

    always @(posedge clk_final or negedge rst_n)
        if (!rst_n) begin final_r0 <= 8'h0; final_r1 <= 8'h0; final_r2 <= 8'h0; final_r3 <= 8'h0; end
        else begin final_r0 <= mux_a_r1^mux_b_r1; final_r1 <= final_r0+8'h5; final_r2 <= final_r1^final_r0; final_r3 <= final_r2&final_r1; end

    assign data_out = {final_r3, mux_a_r1, mux_b_r1, path_a_r1^path_b_r1};

endmodule

//-----------------------------------------------------------------------------
// Module: clock_diamond
//-----------------------------------------------------------------------------
module clock_diamond (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        sel,
    input  wire [15:0] data_in,
    output wire [15:0] data_out
);

    reg clk_path_a, clk_path_b;
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_path_a <= 1'b0; else clk_path_a <= ~clk_path_a;
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_path_b <= 1'b0; else clk_path_b <= ~clk_path_b;

    wire clk_rejoined = sel ? clk_path_a : clk_path_b;

    reg [7:0] pa_r, pb_r, rejoin_r0, rejoin_r1;

    always @(posedge clk_path_a or negedge rst_n)
        if (!rst_n) pa_r <= 8'h0; else pa_r <= data_in[7:0];
    always @(posedge clk_path_b or negedge rst_n)
        if (!rst_n) pb_r <= 8'h0; else pb_r <= data_in[15:8];
    always @(posedge clk_rejoined or negedge rst_n)
        if (!rst_n) begin rejoin_r0 <= 8'h0; rejoin_r1 <= 8'h0; end
        else begin rejoin_r0 <= pa_r ^ pb_r; rejoin_r1 <= rejoin_r0 + 8'h10; end

    assign data_out = {rejoin_r1, rejoin_r0};

endmodule
