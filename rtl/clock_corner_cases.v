//-----------------------------------------------------------------------------
// Module: clock_corner_cases
// Description: Various corner cases for clock analysis
//-----------------------------------------------------------------------------

module clock_corner_cases (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire [3:0]  sel,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    // Clock dividers
    reg clk_div2_x, clk_div2_y;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) clk_div2_x <= 1'b0;
        else clk_div2_x <= ~clk_div2_x;
    end

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) clk_div2_y <= 1'b0;
        else clk_div2_y <= ~clk_div2_y;
    end

    // Case 1: Clock from OR
    wire clk_or = clk_div2_x | clk_div2_y;

    reg [7:0] or_r0, or_r1, or_r2, or_r3;
    always @(posedge clk_or or negedge rst_n) begin
        if (!rst_n) begin or_r0 <= 8'h0; or_r1 <= 8'h0; or_r2 <= 8'h0; or_r3 <= 8'h0; end
        else begin or_r0 <= data_in[7:0]; or_r1 <= or_r0+8'h1; or_r2 <= or_r1^or_r0; or_r3 <= or_r2&or_r1; end
    end

    // Case 2: Clock from AND
    wire clk_and = clk_div2_x & clk_div2_y;

    reg [7:0] and_r0, and_r1, and_r2, and_r3;
    always @(posedge clk_and or negedge rst_n) begin
        if (!rst_n) begin and_r0 <= 8'h0; and_r1 <= 8'h0; and_r2 <= 8'h0; and_r3 <= 8'h0; end
        else begin and_r0 <= data_in[15:8]; and_r1 <= and_r0+8'h2; and_r2 <= and_r1^and_r0; and_r3 <= and_r2&and_r1; end
    end

    // Case 3: Clock from XOR
    wire clk_xor = clk_div2_x ^ clk_div2_y;

    reg [7:0] xor_r0, xor_r1, xor_r2, xor_r3;
    always @(posedge clk_xor or negedge rst_n) begin
        if (!rst_n) begin xor_r0 <= 8'h0; xor_r1 <= 8'h0; xor_r2 <= 8'h0; xor_r3 <= 8'h0; end
        else begin xor_r0 <= data_in[23:16]; xor_r1 <= xor_r0+8'h3; xor_r2 <= xor_r1^xor_r0; xor_r3 <= xor_r2&xor_r1; end
    end

    // Case 4: Nested MUX
    reg clk_div4_a, clk_div4_b;
    always @(posedge clk_div2_x or negedge rst_n) begin
        if (!rst_n) clk_div4_a <= 1'b0;
        else clk_div4_a <= ~clk_div4_a;
    end
    always @(posedge clk_div2_y or negedge rst_n) begin
        if (!rst_n) clk_div4_b <= 1'b0;
        else clk_div4_b <= ~clk_div4_b;
    end

    wire clk_mux_l1_a = sel[0] ? clk_div2_x : clk_div2_y;
    wire clk_mux_l1_b = sel[1] ? clk_div4_a : clk_div4_b;
    wire clk_mux_l2   = sel[2] ? clk_mux_l1_a : clk_mux_l1_b;

    reg [7:0] mux_r0, mux_r1, mux_r2, mux_r3;
    always @(posedge clk_mux_l2 or negedge rst_n) begin
        if (!rst_n) begin mux_r0 <= 8'h0; mux_r1 <= 8'h0; mux_r2 <= 8'h0; mux_r3 <= 8'h0; end
        else begin mux_r0 <= data_in[31:24]; mux_r1 <= mux_r0+8'h4; mux_r2 <= mux_r1^mux_r0; mux_r3 <= mux_r2&mux_r1; end
    end

    // Registers on intermediate clocks
    reg [7:0] div2x_r0, div2x_r1, div2y_r0, div2y_r1;
    reg [7:0] div4a_r0, div4a_r1, div4b_r0, div4b_r1;

    always @(posedge clk_div2_x or negedge rst_n) begin
        if (!rst_n) begin div2x_r0 <= 8'h0; div2x_r1 <= 8'h0; end
        else begin div2x_r0 <= data_in[7:0]; div2x_r1 <= div2x_r0+8'h10; end
    end
    always @(posedge clk_div2_y or negedge rst_n) begin
        if (!rst_n) begin div2y_r0 <= 8'h0; div2y_r1 <= 8'h0; end
        else begin div2y_r0 <= data_in[15:8]; div2y_r1 <= div2y_r0+8'h20; end
    end
    always @(posedge clk_div4_a or negedge rst_n) begin
        if (!rst_n) begin div4a_r0 <= 8'h0; div4a_r1 <= 8'h0; end
        else begin div4a_r0 <= data_in[23:16]; div4a_r1 <= div4a_r0+8'h30; end
    end
    always @(posedge clk_div4_b or negedge rst_n) begin
        if (!rst_n) begin div4b_r0 <= 8'h0; div4b_r1 <= 8'h0; end
        else begin div4b_r0 <= data_in[31:24]; div4b_r1 <= div4b_r0+8'h40; end
    end

    assign data_out = {mux_r3, xor_r3, and_r3, or_r3};

endmodule
