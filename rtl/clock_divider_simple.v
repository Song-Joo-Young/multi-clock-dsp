//-----------------------------------------------------------------------------
// Module: clk_div_reg_simple
// Description: Simple register-based clock divider
//              Single toggle flip-flop for /2 division
//-----------------------------------------------------------------------------

module clk_div_reg_simple (
    input  wire clk_in,
    input  wire rst_n,
    input  wire enable,
    output reg  clk_out
);

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            clk_out <= 1'b0;
        else if (enable)
            clk_out <= ~clk_out;
    end

endmodule


//-----------------------------------------------------------------------------
// Module: clk_div_reg_chain
// Description: Chained register dividers (/2 -> /4 -> /8 -> /16)
//              Each stage is a simple toggle FF
//-----------------------------------------------------------------------------

module clk_div_reg_chain (
    input  wire clk_in,
    input  wire rst_n,
    input  wire enable,

    output wire clk_div2,
    output wire clk_div4,
    output wire clk_div8,
    output wire clk_div16
);

    reg div2_reg, div4_reg, div8_reg, div16_reg;

    // Stage 1: /2
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            div2_reg <= 1'b0;
        else if (enable)
            div2_reg <= ~div2_reg;
    end

    // Stage 2: /4 (clocked by /2)
    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n)
            div4_reg <= 1'b0;
        else if (enable)
            div4_reg <= ~div4_reg;
    end

    // Stage 3: /8 (clocked by /4)
    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n)
            div8_reg <= 1'b0;
        else if (enable)
            div8_reg <= ~div8_reg;
    end

    // Stage 4: /16 (clocked by /8)
    always @(posedge div8_reg or negedge rst_n) begin
        if (!rst_n)
            div16_reg <= 1'b0;
        else if (enable)
            div16_reg <= ~div16_reg;
    end

    assign clk_div2  = div2_reg;
    assign clk_div4  = div4_reg;
    assign clk_div8  = div8_reg;
    assign clk_div16 = div16_reg;

endmodule


//-----------------------------------------------------------------------------
// Module: clk_div_reg_programmable
// Description: Programmable counter-based divider
//              Divides by (div_ratio + 1) * 2 for 50% duty cycle
//-----------------------------------------------------------------------------

module clk_div_reg_programmable #(
    parameter WIDTH = 8
)(
    input  wire             clk_in,
    input  wire             rst_n,
    input  wire             enable,
    input  wire [WIDTH-1:0] div_ratio,    // Division = (div_ratio+1)*2
    output reg              clk_out
);

    reg [WIDTH-1:0] counter;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            counter <= {WIDTH{1'b0}};
            clk_out <= 1'b0;
        end else if (enable) begin
            if (counter >= div_ratio) begin
                counter <= {WIDTH{1'b0}};
                clk_out <= ~clk_out;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule
