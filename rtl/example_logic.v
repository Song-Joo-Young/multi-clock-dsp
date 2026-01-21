//-----------------------------------------------------------------------------
// Module: multi_clock_counter
// Description: Example counter running on multiple clock domains
//              Uses divided clocks from clk_div_reg_chain
//-----------------------------------------------------------------------------

module multi_clock_counter (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        enable,

    // Counter outputs (each runs on different clock domain)
    output wire [7:0]  cnt_fast,      // Runs on clk_in
    output wire [7:0]  cnt_div2,      // Runs on clk_in/2
    output wire [7:0]  cnt_div4,      // Runs on clk_in/4
    output wire [7:0]  cnt_div8,      // Runs on clk_in/8

    // Divided clocks output (for monitoring)
    output wire        clk_div2_out,
    output wire        clk_div4_out,
    output wire        clk_div8_out
);

    //=========================================================================
    // Clock Divider Chain
    //=========================================================================
    wire clk_div2, clk_div4, clk_div8, clk_div16;

    clk_div_reg_chain u_clk_div (
        .clk_in   (clk_in),
        .rst_n    (rst_n),
        .enable   (enable),
        .clk_div2 (clk_div2),
        .clk_div4 (clk_div4),
        .clk_div8 (clk_div8),
        .clk_div16(clk_div16)
    );

    assign clk_div2_out = clk_div2;
    assign clk_div4_out = clk_div4;
    assign clk_div8_out = clk_div8;

    //=========================================================================
    // Fast Counter (clk_in domain)
    //=========================================================================
    reg [7:0] cnt_fast_reg;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            cnt_fast_reg <= 8'h00;
        else if (enable)
            cnt_fast_reg <= cnt_fast_reg + 1'b1;
    end

    assign cnt_fast = cnt_fast_reg;

    //=========================================================================
    // Div2 Counter (clk_div2 domain)
    //=========================================================================
    reg [7:0] cnt_div2_reg;

    always @(posedge clk_div2 or negedge rst_n) begin
        if (!rst_n)
            cnt_div2_reg <= 8'h00;
        else if (enable)
            cnt_div2_reg <= cnt_div2_reg + 1'b1;
    end

    assign cnt_div2 = cnt_div2_reg;

    //=========================================================================
    // Div4 Counter (clk_div4 domain)
    //=========================================================================
    reg [7:0] cnt_div4_reg;

    always @(posedge clk_div4 or negedge rst_n) begin
        if (!rst_n)
            cnt_div4_reg <= 8'h00;
        else if (enable)
            cnt_div4_reg <= cnt_div4_reg + 1'b1;
    end

    assign cnt_div4 = cnt_div4_reg;

    //=========================================================================
    // Div8 Counter (clk_div8 domain)
    //=========================================================================
    reg [7:0] cnt_div8_reg;

    always @(posedge clk_div8 or negedge rst_n) begin
        if (!rst_n)
            cnt_div8_reg <= 8'h00;
        else if (enable)
            cnt_div8_reg <= cnt_div8_reg + 1'b1;
    end

    assign cnt_div8 = cnt_div8_reg;

endmodule


//-----------------------------------------------------------------------------
// Module: simple_dsp_with_clkdiv
// Description: Simple DSP block using divided clocks
//              - Fast path: Accumulator on main clock
//              - Slow path: Filter coefficient update on divided clock
//-----------------------------------------------------------------------------

module simple_dsp_with_clkdiv #(
    parameter DATA_WIDTH = 16
)(
    input  wire                    clk_in,
    input  wire                    rst_n,
    input  wire                    enable,

    // Data input (fast clock domain)
    input  wire [DATA_WIDTH-1:0]   data_in,
    input  wire                    data_valid,

    // Coefficient update (slow clock domain - div4)
    input  wire [DATA_WIDTH-1:0]   coeff_in,
    input  wire                    coeff_load,

    // Control
    input  wire                    clear_acc,

    // Outputs
    output wire [DATA_WIDTH*2-1:0] acc_out,       // Accumulator output
    output wire [DATA_WIDTH-1:0]   filtered_out,  // Filtered/scaled output
    output wire                    clk_slow_out   // Divided clock output
);

    //=========================================================================
    // Clock Divider (using simple register-based divider)
    //=========================================================================
    wire clk_div2, clk_div4;
    reg  div2_reg, div4_reg;

    // /2 divider
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            div2_reg <= 1'b0;
        else if (enable)
            div2_reg <= ~div2_reg;
    end
    assign clk_div2 = div2_reg;

    // /4 divider (from /2)
    always @(posedge clk_div2 or negedge rst_n) begin
        if (!rst_n)
            div4_reg <= 1'b0;
        else
            div4_reg <= ~div4_reg;
    end
    assign clk_div4 = div4_reg;
    assign clk_slow_out = clk_div4;

    //=========================================================================
    // Coefficient Register (slow clock domain - clk_div4)
    //=========================================================================
    reg [DATA_WIDTH-1:0] coeff_reg;

    always @(posedge clk_div4 or negedge rst_n) begin
        if (!rst_n)
            coeff_reg <= {{DATA_WIDTH-1{1'b0}}, 1'b1};  // Default coeff = 1
        else if (coeff_load)
            coeff_reg <= coeff_in;
    end

    //=========================================================================
    // Multiplier and Accumulator (fast clock domain - clk_in)
    //=========================================================================
    wire signed [DATA_WIDTH-1:0]   data_signed;
    wire signed [DATA_WIDTH-1:0]   coeff_signed;
    wire signed [DATA_WIDTH*2-1:0] product;
    reg  signed [DATA_WIDTH*2-1:0] accumulator;

    assign data_signed  = data_in;
    assign coeff_signed = coeff_reg;
    assign product      = data_signed * coeff_signed;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            accumulator <= {(DATA_WIDTH*2){1'b0}};
        else if (clear_acc)
            accumulator <= {(DATA_WIDTH*2){1'b0}};
        else if (data_valid && enable)
            accumulator <= accumulator + product;
    end

    assign acc_out = accumulator;

    //=========================================================================
    // Output scaling (take upper bits)
    //=========================================================================
    assign filtered_out = accumulator[DATA_WIDTH*2-1 -: DATA_WIDTH];

endmodule


//-----------------------------------------------------------------------------
// Module: pwm_generator_clkdiv
// Description: PWM generator using programmable clock divider
//              Demonstrates practical use of register-based divider
//-----------------------------------------------------------------------------

module pwm_generator_clkdiv #(
    parameter PWM_WIDTH = 8
)(
    input  wire                  clk_in,
    input  wire                  rst_n,
    input  wire                  enable,

    // Clock divider control
    input  wire [7:0]            clk_div_ratio,    // Clock division ratio

    // PWM control
    input  wire [PWM_WIDTH-1:0]  pwm_duty,         // Duty cycle (0-255)
    input  wire [PWM_WIDTH-1:0]  pwm_period,       // Period (should be >= duty)

    // Outputs
    output wire                  pwm_out,
    output wire                  pwm_clk           // PWM base clock
);

    //=========================================================================
    // Programmable Clock Divider
    //=========================================================================
    wire clk_divided;

    clk_div_reg_programmable #(
        .WIDTH (8)
    ) u_clk_div (
        .clk_in    (clk_in),
        .rst_n     (rst_n),
        .enable    (enable),
        .div_ratio (clk_div_ratio),
        .clk_out   (clk_divided)
    );

    assign pwm_clk = clk_divided;

    //=========================================================================
    // PWM Counter and Comparator
    //=========================================================================
    reg [PWM_WIDTH-1:0] pwm_counter;
    reg                 pwm_out_reg;

    always @(posedge clk_divided or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= {PWM_WIDTH{1'b0}};
            pwm_out_reg <= 1'b0;
        end else if (enable) begin
            // Counter
            if (pwm_counter >= pwm_period)
                pwm_counter <= {PWM_WIDTH{1'b0}};
            else
                pwm_counter <= pwm_counter + 1'b1;

            // PWM output
            pwm_out_reg <= (pwm_counter < pwm_duty);
        end
    end

    assign pwm_out = pwm_out_reg;

endmodule


//-----------------------------------------------------------------------------
// Module: sample_rate_converter
// Description: Simple sample rate converter using clock dividers
//              Decimates input data from fast to slow clock domain
//-----------------------------------------------------------------------------

module sample_rate_converter #(
    parameter DATA_WIDTH = 16,
    parameter DECIM_FACTOR = 4    // Decimation factor (power of 2)
)(
    input  wire                    clk_fast,      // Fast input clock
    input  wire                    rst_n,
    input  wire                    enable,

    // Input (fast clock domain)
    input  wire [DATA_WIDTH-1:0]   data_in,
    input  wire                    valid_in,

    // Output (slow clock domain)
    output reg  [DATA_WIDTH-1:0]   data_out,
    output reg                     valid_out,
    output wire                    clk_slow       // Decimated clock
);

    //=========================================================================
    // Clock Divider for decimation
    //=========================================================================
    reg [$clog2(DECIM_FACTOR)-1:0] div_counter;
    reg                            clk_slow_reg;

    always @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n) begin
            div_counter  <= 0;
            clk_slow_reg <= 1'b0;
        end else if (enable) begin
            if (div_counter >= (DECIM_FACTOR/2 - 1)) begin
                div_counter  <= 0;
                clk_slow_reg <= ~clk_slow_reg;
            end else begin
                div_counter <= div_counter + 1'b1;
            end
        end
    end

    assign clk_slow = clk_slow_reg;

    //=========================================================================
    // Accumulator for averaging (simple decimation filter)
    //=========================================================================
    reg [DATA_WIDTH+$clog2(DECIM_FACTOR)-1:0] accumulator;
    reg [$clog2(DECIM_FACTOR)-1:0]            sample_count;

    always @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n) begin
            accumulator  <= 0;
            sample_count <= 0;
            data_out     <= 0;
            valid_out    <= 1'b0;
        end else if (enable && valid_in) begin
            if (sample_count >= (DECIM_FACTOR - 1)) begin
                // Output decimated sample (average)
                data_out     <= (accumulator + data_in) >> $clog2(DECIM_FACTOR);
                valid_out    <= 1'b1;
                accumulator  <= 0;
                sample_count <= 0;
            end else begin
                // Accumulate
                accumulator  <= accumulator + data_in;
                sample_count <= sample_count + 1'b1;
                valid_out    <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
