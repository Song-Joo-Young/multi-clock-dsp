//-----------------------------------------------------------------------------
// Module: clock_generate_array
// Description: Generate blocks for clock paths
//-----------------------------------------------------------------------------

module clock_generate_array #(parameter NUM_PATHS = 4)(
    input  wire                   clk_in,
    input  wire                   rst_n,
    input  wire [NUM_PATHS-1:0]   path_sel,
    input  wire [31:0]            data_in,
    output wire [31:0]            data_out
);

    wire [NUM_PATHS-1:0] clk_div2;
    wire [NUM_PATHS-1:0] clk_div4;

    genvar i;
    generate
        for (i = 0; i < NUM_PATHS; i = i + 1) begin : gen_clk_path
            reg clk_div2_reg, clk_div4_reg;
            always @(posedge clk_in or negedge rst_n)
                if (!rst_n) clk_div2_reg <= 1'b0; else clk_div2_reg <= ~clk_div2_reg;
            always @(posedge clk_div2_reg or negedge rst_n)
                if (!rst_n) clk_div4_reg <= 1'b0; else clk_div4_reg <= ~clk_div4_reg;
            assign clk_div2[i] = clk_div2_reg;
            assign clk_div4[i] = clk_div4_reg;
        end
    endgenerate

    wire [7:0] path_data [0:NUM_PATHS-1];

    generate
        for (i = 0; i < NUM_PATHS; i = i + 1) begin : gen_path_regs
            reg [7:0] path_r;
            always @(posedge clk_div4[i] or negedge rst_n)
                if (!rst_n) path_r <= 8'h0; else path_r <= data_in[i*8 +: 8] + i[7:0];
            assign path_data[i] = path_r;
        end
    endgenerate

    wire clk_combined_all = clk_div4[0] | clk_div4[1] | clk_div4[2] | clk_div4[3];
    wire clk_mux_final = path_sel[2] ? (path_sel[0] ? clk_div4[0] : clk_div4[1])
                                      : (path_sel[1] ? clk_div4[2] : clk_div4[3]);

    reg [7:0] comb_r, mux_r;

    always @(posedge clk_combined_all or negedge rst_n)
        if (!rst_n) comb_r <= 8'h0; else comb_r <= path_data[0] ^ path_data[1];

    always @(posedge clk_mux_final or negedge rst_n)
        if (!rst_n) mux_r <= 8'h0; else mux_r <= path_data[2] ^ path_data[3];

    assign data_out = {comb_r, mux_r, path_data[0], path_data[1]};

endmodule
