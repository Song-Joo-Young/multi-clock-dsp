//-----------------------------------------------------------------------------
// Module: clock_test_patterns
// Description: Consolidated clock test patterns for duplicate detection testing
//              Combines: reconvergence, cross-primary, OR/AND/XOR patterns
//-----------------------------------------------------------------------------

module clock_test_patterns (
    input  wire        clk_a,          // Primary clock A
    input  wire        clk_b,          // Primary clock B (independent)
    input  wire        rst_n,
    input  wire [3:0]  sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    //=========================================================================
    // Clock dividers from both sources
    //=========================================================================
    reg clk_a_div2, clk_a_div4;
    reg clk_b_div2, clk_b_div4;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) clk_a_div2 <= 1'b0;
        else clk_a_div2 <= ~clk_a_div2;
    end

    always @(posedge clk_a_div2 or negedge rst_n) begin
        if (!rst_n) clk_a_div4 <= 1'b0;
        else clk_a_div4 <= ~clk_a_div4;
    end

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) clk_b_div2 <= 1'b0;
        else clk_b_div2 <= ~clk_b_div2;
    end

    always @(posedge clk_b_div2 or negedge rst_n) begin
        if (!rst_n) clk_b_div4 <= 1'b0;
        else clk_b_div4 <= ~clk_b_div4;
    end

    //=========================================================================
    // Pattern 1: Cross-primary OR/AND/XOR (independent sources)
    //=========================================================================
    wire clk_cross_or  = clk_a_div2 | clk_b_div2;
    wire clk_cross_and = clk_a_div2 & clk_b_div2;
    wire clk_cross_xor = clk_a_div2 ^ clk_b_div2;

    //=========================================================================
    // Pattern 2: Reconvergence MUX (same source, different paths)
    //=========================================================================
    wire clk_mux_ab = sel[0] ? clk_a_div2 : clk_a_div4;
    wire clk_mux_cd = sel[1] ? clk_b_div2 : clk_b_div4;
    wire clk_reconv = sel[2] ? clk_mux_ab : clk_mux_cd;

    //=========================================================================
    // Registers on divided clocks
    //=========================================================================
    reg [7:0] ra2, ra4, rb2, rb4;

    always @(posedge clk_a_div2 or negedge rst_n)
        if (!rst_n) ra2 <= 8'h0; else ra2 <= data_in[7:0];

    always @(posedge clk_a_div4 or negedge rst_n)
        if (!rst_n) ra4 <= 8'h0; else ra4 <= data_in[15:8];

    always @(posedge clk_b_div2 or negedge rst_n)
        if (!rst_n) rb2 <= 8'h0; else rb2 <= data_in[23:16];

    always @(posedge clk_b_div4 or negedge rst_n)
        if (!rst_n) rb4 <= 8'h0; else rb4 <= data_in[31:24];

    //=========================================================================
    // Registers on combined clocks
    //=========================================================================
    reg [7:0] r_or, r_and, r_xor, r_reconv;

    always @(posedge clk_cross_or or negedge rst_n)
        if (!rst_n) r_or <= 8'h0; else r_or <= ra2 ^ rb2;

    always @(posedge clk_cross_and or negedge rst_n)
        if (!rst_n) r_and <= 8'h0; else r_and <= ra2 & rb2;

    always @(posedge clk_cross_xor or negedge rst_n)
        if (!rst_n) r_xor <= 8'h0; else r_xor <= ra2 | rb2;

    always @(posedge clk_reconv or negedge rst_n)
        if (!rst_n) r_reconv <= 8'h0; else r_reconv <= ra4 ^ rb4;

    //=========================================================================
    // Output
    //=========================================================================
    assign data_out = {r_or, r_and, r_xor, r_reconv};

endmodule
