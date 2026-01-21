//-----------------------------------------------------------------------------
// Module: clk_div_chain_feedback
// Description: Clock divider chain with feedback path
//              Last stage output feeds back to first mux input
//              Pattern: MUX -> REG -> MUX -> REG -> MUX -> REG -> MUX -> out
//                        ^                                         |
//                        +----------------feedback-----------------+
//-----------------------------------------------------------------------------

module clk_div_chain_feedback (
    input  wire        clk_in,          // External clock input
    input  wire        rst_n,           // Async reset (active low)

    // Stage control (each stage has mux select)
    input  wire        stg0_sel,        // Stage 0 mux: 0=clk_in, 1=feedback
    input  wire        stg1_sel,        // Stage 1 mux: 0=stg0_out, 1=bypass
    input  wire        stg2_sel,        // Stage 2 mux: 0=stg1_out, 1=bypass
    input  wire        stg3_sel,        // Stage 3 mux: 0=stg2_out, 1=bypass

    // Divider enables
    input  wire        div_en,          // Global divider enable

    // Outputs
    output wire        clk_out,         // Final divided clock
    output wire        stg0_clk,        // Stage 0 output (for monitoring)
    output wire        stg1_clk,        // Stage 1 output
    output wire        stg2_clk,        // Stage 2 output
    output wire        feedback_clk     // Feedback clock (= clk_out)
);

    //=========================================================================
    // Internal signals
    //=========================================================================
    wire mux0_out;
    wire mux1_out;
    wire mux2_out;
    wire mux3_out;

    reg  reg0_out;
    reg  reg1_out;
    reg  reg2_out;
    reg  reg3_out;

    //=========================================================================
    // Stage 0: First MUX (selects between clk_in and feedback)
    //          -> Divider register (/2)
    //=========================================================================
    // MUX0: clk_in or feedback from final output
    assign mux0_out = stg0_sel ? reg3_out : clk_in;

    // REG0: Divide by 2
    always @(posedge mux0_out or negedge rst_n) begin
        if (!rst_n) begin
            reg0_out <= 1'b0;
        end else if (div_en) begin
            reg0_out <= ~reg0_out;
        end
    end

    assign stg0_clk = reg0_out;

    //=========================================================================
    // Stage 1: MUX (selects stage0 output or bypass)
    //          -> Divider register (/2)
    //=========================================================================
    // MUX1: reg0_out or bypass (clk_in)
    assign mux1_out = stg1_sel ? clk_in : reg0_out;

    // REG1: Divide by 2
    always @(posedge mux1_out or negedge rst_n) begin
        if (!rst_n) begin
            reg1_out <= 1'b0;
        end else if (div_en) begin
            reg1_out <= ~reg1_out;
        end
    end

    assign stg1_clk = reg1_out;

    //=========================================================================
    // Stage 2: MUX (selects stage1 output or bypass)
    //          -> Divider register (/2)
    //=========================================================================
    // MUX2: reg1_out or bypass (clk_in)
    assign mux2_out = stg2_sel ? clk_in : reg1_out;

    // REG2: Divide by 2
    always @(posedge mux2_out or negedge rst_n) begin
        if (!rst_n) begin
            reg2_out <= 1'b0;
        end else if (div_en) begin
            reg2_out <= ~reg2_out;
        end
    end

    assign stg2_clk = reg2_out;

    //=========================================================================
    // Stage 3: Final MUX (selects stage2 output or bypass)
    //          -> Divider register (/2)
    //          -> Output feeds back to Stage 0 MUX
    //=========================================================================
    // MUX3: reg2_out or bypass (clk_in)
    assign mux3_out = stg3_sel ? clk_in : reg2_out;

    // REG3: Divide by 2
    always @(posedge mux3_out or negedge rst_n) begin
        if (!rst_n) begin
            reg3_out <= 1'b0;
        end else if (div_en) begin
            reg3_out <= ~reg3_out;
        end
    end

    // Final output (also used as feedback)
    assign clk_out      = reg3_out;
    assign feedback_clk = reg3_out;

endmodule


//-----------------------------------------------------------------------------
// Module: clk_div_cascade_feedback
// Description: More complex cascaded divider with configurable feedback point
//              Supports selecting which stage output feeds back
//-----------------------------------------------------------------------------

module clk_div_cascade_feedback #(
    parameter NUM_STAGES = 4
)(
    input  wire                    clk_in,
    input  wire                    rst_n,

    // Feedback control
    input  wire                    feedback_en,       // Enable feedback path
    input  wire [1:0]              feedback_tap,      // Which stage to tap for feedback
                                                      // 00=stg0, 01=stg1, 10=stg2, 11=stg3

    // Stage bypass control
    input  wire [NUM_STAGES-1:0]   stage_bypass,      // Per-stage bypass

    // Division control per stage
    input  wire [NUM_STAGES-1:0]   stage_div_en,      // Per-stage divide enable

    // Output
    output wire                    clk_out,
    output wire [NUM_STAGES-1:0]   stage_clk_out      // All stage outputs
);

    //=========================================================================
    // Internal signals
    //=========================================================================
    wire [NUM_STAGES-1:0] mux_out;
    reg  [NUM_STAGES-1:0] reg_out;
    wire                  feedback_clk;

    // Select feedback source based on feedback_tap
    assign feedback_clk = (feedback_tap == 2'b00) ? reg_out[0] :
                          (feedback_tap == 2'b01) ? reg_out[1] :
                          (feedback_tap == 2'b10) ? reg_out[2] :
                                                    reg_out[3];

    //=========================================================================
    // Stage 0: Input MUX with feedback option
    //=========================================================================
    // MUX0: clk_in or feedback (when feedback_en=1)
    wire stg0_mux_in;
    assign stg0_mux_in = (feedback_en) ? feedback_clk : clk_in;
    assign mux_out[0]  = (stage_bypass[0]) ? clk_in : stg0_mux_in;

    always @(posedge mux_out[0] or negedge rst_n) begin
        if (!rst_n) begin
            reg_out[0] <= 1'b0;
        end else if (stage_div_en[0]) begin
            reg_out[0] <= ~reg_out[0];
        end
    end

    //=========================================================================
    // Stage 1
    //=========================================================================
    assign mux_out[1] = (stage_bypass[1]) ? clk_in : reg_out[0];

    always @(posedge mux_out[1] or negedge rst_n) begin
        if (!rst_n) begin
            reg_out[1] <= 1'b0;
        end else if (stage_div_en[1]) begin
            reg_out[1] <= ~reg_out[1];
        end
    end

    //=========================================================================
    // Stage 2
    //=========================================================================
    assign mux_out[2] = (stage_bypass[2]) ? clk_in : reg_out[1];

    always @(posedge mux_out[2] or negedge rst_n) begin
        if (!rst_n) begin
            reg_out[2] <= 1'b0;
        end else if (stage_div_en[2]) begin
            reg_out[2] <= ~reg_out[2];
        end
    end

    //=========================================================================
    // Stage 3 (Final)
    //=========================================================================
    assign mux_out[3] = (stage_bypass[3]) ? clk_in : reg_out[2];

    always @(posedge mux_out[3] or negedge rst_n) begin
        if (!rst_n) begin
            reg_out[3] <= 1'b0;
        end else if (stage_div_en[3]) begin
            reg_out[3] <= ~reg_out[3];
        end
    end

    //=========================================================================
    // Outputs
    //=========================================================================
    assign clk_out       = reg_out[NUM_STAGES-1];
    assign stage_clk_out = reg_out;

endmodule


//-----------------------------------------------------------------------------
// Module: clk_div_pll_style_feedback
// Description: PLL-style divider with feedback
//              Mimics PLL feedback divider structure
//              ref_clk -> PFD -> ... -> VCO -> divider -> feedback to PFD
//-----------------------------------------------------------------------------

module clk_div_pll_style_feedback #(
    parameter FB_DIV_WIDTH = 4    // Feedback divider width
)(
    input  wire                     clk_in,           // Reference clock (like PLL ref)
    input  wire                     rst_n,

    // Feedback divider control
    input  wire [FB_DIV_WIDTH-1:0]  fb_div_ratio,     // Feedback division ratio (N)
    input  wire                     fb_div_en,        // Feedback divider enable

    // Output divider control (post-divider)
    input  wire [1:0]               out_div_sel,      // Output divider: 00=/1, 01=/2, 10=/4, 11=/8

    // Source select
    input  wire                     use_feedback,     // 0=use clk_in, 1=use feedback path

    // Outputs
    output wire                     clk_out,          // Final output clock
    output wire                     fb_clk,           // Feedback clock (for monitoring)
    output wire                     div_clk           // Post-divided clock
);

    //=========================================================================
    // Input MUX: Select between external clock and feedback
    //=========================================================================
    wire clk_selected;
    wire clk_feedback;

    assign clk_selected = use_feedback ? clk_feedback : clk_in;

    //=========================================================================
    // Main clock path (simulates VCO output in PLL)
    // In real PLL, this would be VCO. Here we just pass through or buffer.
    //=========================================================================
    wire vco_clk;
    assign vco_clk = clk_selected;  // Simplified - real PLL would have VCO here

    //=========================================================================
    // Feedback Divider (divides VCO output by N)
    // This creates the feedback clock that goes back to input mux
    //=========================================================================
    reg [FB_DIV_WIDTH-1:0] fb_counter;
    reg                    fb_clk_reg;

    always @(posedge vco_clk or negedge rst_n) begin
        if (!rst_n) begin
            fb_counter <= {FB_DIV_WIDTH{1'b0}};
            fb_clk_reg <= 1'b0;
        end else if (fb_div_en) begin
            if (fb_counter >= (fb_div_ratio - 1'b1)) begin
                fb_counter <= {FB_DIV_WIDTH{1'b0}};
                fb_clk_reg <= ~fb_clk_reg;
            end else begin
                fb_counter <= fb_counter + 1'b1;
            end
        end
    end

    // Feedback path back to input mux
    assign clk_feedback = fb_clk_reg;
    assign fb_clk       = fb_clk_reg;

    //=========================================================================
    // Output Divider (post-divider for output clock)
    //=========================================================================
    reg [2:0] out_counter;
    reg       out_div2, out_div4, out_div8;

    always @(posedge vco_clk or negedge rst_n) begin
        if (!rst_n) begin
            out_counter <= 3'b0;
            out_div2    <= 1'b0;
            out_div4    <= 1'b0;
            out_div8    <= 1'b0;
        end else begin
            out_counter <= out_counter + 1'b1;

            // /2
            out_div2 <= ~out_div2;

            // /4
            if (out_counter[0]) out_div4 <= ~out_div4;

            // /8
            if (out_counter[1:0] == 2'b11) out_div8 <= ~out_div8;
        end
    end

    // Output divider mux
    reg div_clk_mux;
    always @(*) begin
        case (out_div_sel)
            2'b00:   div_clk_mux = vco_clk;    // /1 (no division)
            2'b01:   div_clk_mux = out_div2;   // /2
            2'b10:   div_clk_mux = out_div4;   // /4
            2'b11:   div_clk_mux = out_div8;   // /8
            default: div_clk_mux = vco_clk;
        endcase
    end

    assign div_clk = div_clk_mux;
    assign clk_out = div_clk_mux;

endmodule


//-----------------------------------------------------------------------------
// Module: clk_mux_chain_with_feedback
// Description: Pure MUX-REG chain with explicit feedback wiring
//              Shows the exact pattern: MUX->REG->MUX->REG->...->feedback
//-----------------------------------------------------------------------------

module clk_mux_chain_with_feedback (
    input  wire clk_in,
    input  wire rst_n,

    // MUX select signals
    input  wire sel_mux0,    // 0: clk_in,      1: feedback (from mux3_out via reg3)
    input  wire sel_mux1,    // 0: reg0_out,    1: clk_in (bypass)
    input  wire sel_mux2,    // 0: reg1_out,    1: clk_in (bypass)
    input  wire sel_mux3,    // 0: reg2_out,    1: clk_in (bypass)

    // Enable
    input  wire enable,

    // Outputs
    output wire clk_out,
    output wire [3:0] reg_outputs    // All register outputs for debug
);

    //=========================================================================
    // Wires
    //=========================================================================
    wire mux0_out, mux1_out, mux2_out, mux3_out;
    reg  reg0_q, reg1_q, reg2_q, reg3_q;

    //=========================================================================
    // MUX0: First mux - selects between clk_in and FEEDBACK from reg3
    //=========================================================================
    assign mux0_out = sel_mux0 ? reg3_q : clk_in;

    // REG0: Toggle flip-flop (divide by 2)
    always @(posedge mux0_out or negedge rst_n) begin
        if (!rst_n)
            reg0_q <= 1'b0;
        else if (enable)
            reg0_q <= ~reg0_q;
    end

    //=========================================================================
    // MUX1: Second mux - selects between reg0_out and bypass
    //=========================================================================
    assign mux1_out = sel_mux1 ? clk_in : reg0_q;

    // REG1: Toggle flip-flop
    always @(posedge mux1_out or negedge rst_n) begin
        if (!rst_n)
            reg1_q <= 1'b0;
        else if (enable)
            reg1_q <= ~reg1_q;
    end

    //=========================================================================
    // MUX2: Third mux
    //=========================================================================
    assign mux2_out = sel_mux2 ? clk_in : reg1_q;

    // REG2: Toggle flip-flop
    always @(posedge mux2_out or negedge rst_n) begin
        if (!rst_n)
            reg2_q <= 1'b0;
        else if (enable)
            reg2_q <= ~reg2_q;
    end

    //=========================================================================
    // MUX3: Fourth (final) mux - output goes to FEEDBACK
    //=========================================================================
    assign mux3_out = sel_mux3 ? clk_in : reg2_q;

    // REG3: Toggle flip-flop - OUTPUT FEEDS BACK TO MUX0
    always @(posedge mux3_out or negedge rst_n) begin
        if (!rst_n)
            reg3_q <= 1'b0;
        else if (enable)
            reg3_q <= ~reg3_q;
    end

    //=========================================================================
    // Outputs
    //=========================================================================
    assign clk_out = reg3_q;
    assign reg_outputs = {reg3_q, reg2_q, reg1_q, reg0_q};

endmodule
