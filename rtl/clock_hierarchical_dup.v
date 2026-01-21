//-----------------------------------------------------------------------------
// Module: clock_gen_unit
//-----------------------------------------------------------------------------
module clock_gen_unit (
    input  wire clk_in,
    input  wire rst_n,
    output reg  clk_out
);
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) clk_out <= 1'b0; else clk_out <= ~clk_out;
endmodule

//-----------------------------------------------------------------------------
// Module: clock_hierarchical_dup
//-----------------------------------------------------------------------------
module clock_hierarchical_dup (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire [2:0]  sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    wire clk_gen_out_0, clk_gen_out_1, clk_gen_out_2, clk_gen_out_3;

    clock_gen_unit u_gen0 (.clk_in(clk_in), .rst_n(rst_n), .clk_out(clk_gen_out_0));
    clock_gen_unit u_gen1 (.clk_in(clk_in), .rst_n(rst_n), .clk_out(clk_gen_out_1));
    clock_gen_unit u_gen2 (.clk_in(clk_in), .rst_n(rst_n), .clk_out(clk_gen_out_2));
    clock_gen_unit u_gen3 (.clk_in(clk_in), .rst_n(rst_n), .clk_out(clk_gen_out_3));

    wire clk_combined_01 = clk_gen_out_0 | clk_gen_out_1;
    wire clk_combined_23 = clk_gen_out_2 | clk_gen_out_3;
    wire clk_combined_all = clk_combined_01 & clk_combined_23;

    wire clk_mux_01 = sel[0] ? clk_gen_out_0 : clk_gen_out_1;
    wire clk_mux_23 = sel[1] ? clk_gen_out_2 : clk_gen_out_3;
    wire clk_mux_final = sel[2] ? clk_mux_01 : clk_mux_23;

    reg [7:0] gen0_r, gen1_r, gen2_r, gen3_r;
    reg [7:0] comb01_r, comb23_r, comball_r, muxfinal_r;

    always @(posedge clk_gen_out_0 or negedge rst_n)
        if (!rst_n) gen0_r <= 8'h0; else gen0_r <= data_in[7:0];
    always @(posedge clk_gen_out_1 or negedge rst_n)
        if (!rst_n) gen1_r <= 8'h0; else gen1_r <= data_in[15:8];
    always @(posedge clk_gen_out_2 or negedge rst_n)
        if (!rst_n) gen2_r <= 8'h0; else gen2_r <= data_in[23:16];
    always @(posedge clk_gen_out_3 or negedge rst_n)
        if (!rst_n) gen3_r <= 8'h0; else gen3_r <= data_in[31:24];

    always @(posedge clk_combined_01 or negedge rst_n)
        if (!rst_n) comb01_r <= 8'h0; else comb01_r <= gen0_r ^ gen1_r;
    always @(posedge clk_combined_23 or negedge rst_n)
        if (!rst_n) comb23_r <= 8'h0; else comb23_r <= gen2_r ^ gen3_r;
    always @(posedge clk_combined_all or negedge rst_n)
        if (!rst_n) comball_r <= 8'h0; else comball_r <= comb01_r ^ comb23_r;
    always @(posedge clk_mux_final or negedge rst_n)
        if (!rst_n) muxfinal_r <= 8'h0; else muxfinal_r <= gen0_r + gen1_r + gen2_r + gen3_r;

    assign data_out = {comball_r, muxfinal_r, comb01_r, comb23_r};

endmodule
