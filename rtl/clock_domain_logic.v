//-----------------------------------------------------------------------------
// Module: div_clk_domain_logic
// Description: Logic blocks that use divided clocks
//              Multiple registers clocked by each divided clock
//              This helps tools recognize divided clocks as actual clocks
//-----------------------------------------------------------------------------

module div_clk_domain_logic (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        div_en,

    // Data interfaces
    input  wire [31:0] data_in,
    output wire [31:0] data_out,

    // Divided clock outputs (for tool recognition)
    output wire        clk_div2,
    output wire        clk_div4,
    output wire        clk_div8
);

    //=========================================================================
    // Clock Divider Chain (generates divided clocks)
    //=========================================================================
    reg div2_reg, div4_reg, div8_reg;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            div2_reg <= 1'b0;
        else if (div_en)
            div2_reg <= ~div2_reg;
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n)
            div4_reg <= 1'b0;
        else if (div_en)
            div4_reg <= ~div4_reg;
    end

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n)
            div8_reg <= 1'b0;
        else if (div_en)
            div8_reg <= ~div8_reg;
    end

    assign clk_div2 = div2_reg;
    assign clk_div4 = div4_reg;
    assign clk_div8 = div8_reg;

    //=========================================================================
    // CLK_DIV2 Domain - Multiple registers using div2 clock
    // (Tool should recognize div2_reg as clock)
    //=========================================================================
    reg [7:0] div2_reg_a, div2_reg_b, div2_reg_c, div2_reg_d;
    reg [7:0] div2_reg_e, div2_reg_f, div2_reg_g, div2_reg_h;

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_a <= 8'h00;
        else        div2_reg_a <= data_in[7:0];
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_b <= 8'h00;
        else        div2_reg_b <= div2_reg_a + 8'h01;
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_c <= 8'h00;
        else        div2_reg_c <= div2_reg_b + 8'h02;
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_d <= 8'h00;
        else        div2_reg_d <= div2_reg_c ^ div2_reg_a;
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_e <= 8'h00;
        else        div2_reg_e <= data_in[15:8];
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_f <= 8'h00;
        else        div2_reg_f <= div2_reg_e & div2_reg_d;
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_g <= 8'h00;
        else        div2_reg_g <= div2_reg_f | div2_reg_c;
    end

    always @(posedge div2_reg or negedge rst_n) begin
        if (!rst_n) div2_reg_h <= 8'h00;
        else        div2_reg_h <= div2_reg_g + div2_reg_b;
    end

    //=========================================================================
    // CLK_DIV4 Domain - Multiple registers using div4 clock
    //=========================================================================
    reg [7:0] div4_reg_a, div4_reg_b, div4_reg_c, div4_reg_d;
    reg [7:0] div4_reg_e, div4_reg_f;

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n) div4_reg_a <= 8'h00;
        else        div4_reg_a <= data_in[23:16];
    end

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n) div4_reg_b <= 8'h00;
        else        div4_reg_b <= div4_reg_a + 8'h10;
    end

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n) div4_reg_c <= 8'h00;
        else        div4_reg_c <= div4_reg_b ^ 8'hAA;
    end

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n) div4_reg_d <= 8'h00;
        else        div4_reg_d <= div4_reg_c & div4_reg_a;
    end

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n) div4_reg_e <= 8'h00;
        else        div4_reg_e <= div4_reg_d | div4_reg_b;
    end

    always @(posedge div4_reg or negedge rst_n) begin
        if (!rst_n) div4_reg_f <= 8'h00;
        else        div4_reg_f <= div4_reg_e + div4_reg_c;
    end

    //=========================================================================
    // CLK_DIV8 Domain - Multiple registers using div8 clock
    //=========================================================================
    reg [7:0] div8_reg_a, div8_reg_b, div8_reg_c, div8_reg_d;

    always @(posedge div8_reg or negedge rst_n) begin
        if (!rst_n) div8_reg_a <= 8'h00;
        else        div8_reg_a <= data_in[31:24];
    end

    always @(posedge div8_reg or negedge rst_n) begin
        if (!rst_n) div8_reg_b <= 8'h00;
        else        div8_reg_b <= div8_reg_a + 8'h20;
    end

    always @(posedge div8_reg or negedge rst_n) begin
        if (!rst_n) div8_reg_c <= 8'h00;
        else        div8_reg_c <= div8_reg_b ^ div8_reg_a;
    end

    always @(posedge div8_reg or negedge rst_n) begin
        if (!rst_n) div8_reg_d <= 8'h00;
        else        div8_reg_d <= div8_reg_c + div8_reg_b;
    end

    //=========================================================================
    // Output (combine all domains)
    //=========================================================================
    assign data_out = {div8_reg_d, div4_reg_f, div2_reg_h, div2_reg_d};

endmodule


//-----------------------------------------------------------------------------
// Module: frac_clk_domain_logic
// Description: Logic using fractional divided clock
//              Multiple registers to ensure clock recognition
//-----------------------------------------------------------------------------

module frac_clk_domain_logic #(
    parameter DATA_WIDTH = 16
)(
    input  wire                    clk_in,
    input  wire                    rst_n,
    input  wire                    frac_en,
    input  wire [7:0]              frac_ratio,     // {N[3:0], F[3:0]}

    input  wire [DATA_WIDTH-1:0]   data_in,
    output wire [DATA_WIDTH-1:0]   data_out,

    output wire                    frac_clk_out
);

    //=========================================================================
    // Fractional Clock Divider
    //=========================================================================
    wire [3:0] div_n = frac_ratio[7:4];
    wire [3:0] div_f = frac_ratio[3:0];

    reg [4:0]  accumulator;
    reg [3:0]  cycle_counter;
    reg        frac_clk_reg;

    wire [4:0] acc_next = accumulator + {1'b0, div_f};
    wire       acc_overflow = acc_next[4];
    wire [3:0] div_value = acc_overflow ? (div_n + 1'b1) : div_n;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            accumulator   <= 5'b0;
            cycle_counter <= 4'b0;
            frac_clk_reg  <= 1'b0;
        end else if (frac_en) begin
            if (cycle_counter >= (div_value - 1'b1)) begin
                cycle_counter <= 4'b0;
                frac_clk_reg  <= ~frac_clk_reg;
                if (!frac_clk_reg)
                    accumulator <= acc_next[3:0];
            end else begin
                cycle_counter <= cycle_counter + 1'b1;
            end
        end
    end

    assign frac_clk_out = frac_clk_reg;

    //=========================================================================
    // FRAC_CLK Domain - Multiple registers using fractional clock
    //=========================================================================
    reg [DATA_WIDTH-1:0] frac_reg_a, frac_reg_b, frac_reg_c, frac_reg_d;
    reg [DATA_WIDTH-1:0] frac_reg_e, frac_reg_f, frac_reg_g, frac_reg_h;
    reg [DATA_WIDTH-1:0] frac_reg_i, frac_reg_j;

    // Pipeline stage 1
    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_a <= {DATA_WIDTH{1'b0}};
        else        frac_reg_a <= data_in;
    end

    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_b <= {DATA_WIDTH{1'b0}};
        else        frac_reg_b <= ~data_in;
    end

    // Pipeline stage 2
    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_c <= {DATA_WIDTH{1'b0}};
        else        frac_reg_c <= frac_reg_a + frac_reg_b;
    end

    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_d <= {DATA_WIDTH{1'b0}};
        else        frac_reg_d <= frac_reg_a ^ frac_reg_b;
    end

    // Pipeline stage 3
    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_e <= {DATA_WIDTH{1'b0}};
        else        frac_reg_e <= frac_reg_c & frac_reg_d;
    end

    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_f <= {DATA_WIDTH{1'b0}};
        else        frac_reg_f <= frac_reg_c | frac_reg_d;
    end

    // Pipeline stage 4
    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_g <= {DATA_WIDTH{1'b0}};
        else        frac_reg_g <= frac_reg_e + frac_reg_f;
    end

    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_h <= {DATA_WIDTH{1'b0}};
        else        frac_reg_h <= frac_reg_e - frac_reg_f;
    end

    // Pipeline stage 5
    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_i <= {DATA_WIDTH{1'b0}};
        else        frac_reg_i <= frac_reg_g ^ frac_reg_h;
    end

    always @(posedge frac_clk_reg or negedge rst_n) begin
        if (!rst_n) frac_reg_j <= {DATA_WIDTH{1'b0}};
        else        frac_reg_j <= frac_reg_g & frac_reg_h;
    end

    assign data_out = frac_reg_i | frac_reg_j;

endmodule


//-----------------------------------------------------------------------------
// Module: multi_div_clk_subsystem
// Description: Subsystem with multiple divided clock domains
//              Each domain has substantial logic for tool recognition
//-----------------------------------------------------------------------------

module multi_div_clk_subsystem (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        scan_enable,

    // Enable signals
    input  wire        global_en,
    input  wire        div2_domain_en,
    input  wire        div4_domain_en,
    input  wire        div8_domain_en,
    input  wire        frac_domain_en,

    // Fractional ratio
    input  wire [7:0]  frac_ratio,

    // Data
    input  wire [31:0] data_in,
    output wire [31:0] data_out,

    // Clock outputs
    output wire        clk_div2,
    output wire        clk_div4,
    output wire        clk_div8,
    output wire        clk_frac
);

    //=========================================================================
    // Master Clock Dividers
    //=========================================================================
    reg div2_clk_reg, div4_clk_reg, div8_clk_reg;

    // Div2
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n)
            div2_clk_reg <= 1'b0;
        else if (global_en)
            div2_clk_reg <= ~div2_clk_reg;
    end

    // Div4
    always @(posedge div2_clk_reg or negedge rst_n) begin
        if (!rst_n)
            div4_clk_reg <= 1'b0;
        else if (global_en)
            div4_clk_reg <= ~div4_clk_reg;
    end

    // Div8
    always @(posedge div4_clk_reg or negedge rst_n) begin
        if (!rst_n)
            div8_clk_reg <= 1'b0;
        else if (global_en)
            div8_clk_reg <= ~div8_clk_reg;
    end

    assign clk_div2 = div2_clk_reg;
    assign clk_div4 = div4_clk_reg;
    assign clk_div8 = div8_clk_reg;

    //=========================================================================
    // Fractional Clock Divider
    //=========================================================================
    wire [3:0] frac_n = frac_ratio[7:4];
    wire [3:0] frac_f = frac_ratio[3:0];

    reg [4:0] frac_acc;
    reg [3:0] frac_cnt;
    reg       frac_clk_reg;

    wire [4:0] frac_acc_next = frac_acc + {1'b0, frac_f};
    wire       frac_overflow = frac_acc_next[4];
    wire [3:0] frac_div_val = frac_overflow ? (frac_n + 1'b1) : frac_n;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            frac_acc     <= 5'b0;
            frac_cnt     <= 4'b0;
            frac_clk_reg <= 1'b0;
        end else if (global_en && frac_domain_en) begin
            if (frac_cnt >= (frac_div_val - 1'b1)) begin
                frac_cnt     <= 4'b0;
                frac_clk_reg <= ~frac_clk_reg;
                if (!frac_clk_reg)
                    frac_acc <= frac_acc_next[3:0];
            end else begin
                frac_cnt <= frac_cnt + 1'b1;
            end
        end
    end

    assign clk_frac = frac_clk_reg;

    //=========================================================================
    // ICG for each clock domain
    //=========================================================================
    wire clk_div2_gated, clk_div4_gated, clk_div8_gated, clk_frac_gated;

    clock_gating_cell u_icg_div2 (
        .clk_in      (div2_clk_reg),
        .enable      (div2_domain_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_div2_gated)
    );

    clock_gating_cell u_icg_div4 (
        .clk_in      (div4_clk_reg),
        .enable      (div4_domain_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_div4_gated)
    );

    clock_gating_cell u_icg_div8 (
        .clk_in      (div8_clk_reg),
        .enable      (div8_domain_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_div8_gated)
    );

    clock_gating_cell u_icg_frac (
        .clk_in      (frac_clk_reg),
        .enable      (frac_domain_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_frac_gated)
    );

    //=========================================================================
    // DIV2 Domain Registers (8 registers)
    //=========================================================================
    reg [7:0] d2_r0, d2_r1, d2_r2, d2_r3, d2_r4, d2_r5, d2_r6, d2_r7;

    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r0 <= 8'h0; else d2_r0 <= data_in[7:0];
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r1 <= 8'h0; else d2_r1 <= d2_r0 + 8'h1;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r2 <= 8'h0; else d2_r2 <= d2_r1 ^ d2_r0;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r3 <= 8'h0; else d2_r3 <= d2_r2 & d2_r1;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r4 <= 8'h0; else d2_r4 <= d2_r3 | d2_r2;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r5 <= 8'h0; else d2_r5 <= d2_r4 + d2_r3;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r6 <= 8'h0; else d2_r6 <= d2_r5 - d2_r4;
    end
    always @(posedge clk_div2_gated or negedge rst_n) begin
        if (!rst_n) d2_r7 <= 8'h0; else d2_r7 <= d2_r6 ^ d2_r5;
    end

    //=========================================================================
    // DIV4 Domain Registers (8 registers)
    //=========================================================================
    reg [7:0] d4_r0, d4_r1, d4_r2, d4_r3, d4_r4, d4_r5, d4_r6, d4_r7;

    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r0 <= 8'h0; else d4_r0 <= data_in[15:8];
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r1 <= 8'h0; else d4_r1 <= d4_r0 + 8'h2;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r2 <= 8'h0; else d4_r2 <= d4_r1 ^ d4_r0;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r3 <= 8'h0; else d4_r3 <= d4_r2 & d4_r1;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r4 <= 8'h0; else d4_r4 <= d4_r3 | d4_r2;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r5 <= 8'h0; else d4_r5 <= d4_r4 + d4_r3;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r6 <= 8'h0; else d4_r6 <= d4_r5 - d4_r4;
    end
    always @(posedge clk_div4_gated or negedge rst_n) begin
        if (!rst_n) d4_r7 <= 8'h0; else d4_r7 <= d4_r6 ^ d4_r5;
    end

    //=========================================================================
    // DIV8 Domain Registers (8 registers)
    //=========================================================================
    reg [7:0] d8_r0, d8_r1, d8_r2, d8_r3, d8_r4, d8_r5, d8_r6, d8_r7;

    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r0 <= 8'h0; else d8_r0 <= data_in[23:16];
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r1 <= 8'h0; else d8_r1 <= d8_r0 + 8'h4;
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r2 <= 8'h0; else d8_r2 <= d8_r1 ^ d8_r0;
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r3 <= 8'h0; else d8_r3 <= d8_r2 & d8_r1;
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r4 <= 8'h0; else d8_r4 <= d8_r3 | d8_r2;
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r5 <= 8'h0; else d8_r5 <= d8_r4 + d8_r3;
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r6 <= 8'h0; else d8_r6 <= d8_r5 - d8_r4;
    end
    always @(posedge clk_div8_gated or negedge rst_n) begin
        if (!rst_n) d8_r7 <= 8'h0; else d8_r7 <= d8_r6 ^ d8_r5;
    end

    //=========================================================================
    // FRAC Domain Registers (8 registers)
    //=========================================================================
    reg [7:0] df_r0, df_r1, df_r2, df_r3, df_r4, df_r5, df_r6, df_r7;

    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r0 <= 8'h0; else df_r0 <= data_in[31:24];
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r1 <= 8'h0; else df_r1 <= df_r0 + 8'h8;
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r2 <= 8'h0; else df_r2 <= df_r1 ^ df_r0;
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r3 <= 8'h0; else df_r3 <= df_r2 & df_r1;
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r4 <= 8'h0; else df_r4 <= df_r3 | df_r2;
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r5 <= 8'h0; else df_r5 <= df_r4 + df_r3;
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r6 <= 8'h0; else df_r6 <= df_r5 - df_r4;
    end
    always @(posedge clk_frac_gated or negedge rst_n) begin
        if (!rst_n) df_r7 <= 8'h0; else df_r7 <= df_r6 ^ df_r5;
    end

    //=========================================================================
    // Output
    //=========================================================================
    assign data_out = {df_r7, d8_r7, d4_r7, d2_r7};

endmodule


//-----------------------------------------------------------------------------
// Module: feedback_clk_with_users
// Description: Feedback clock divider with multiple user registers
//              Ensures feedback clock is recognized as clock
//-----------------------------------------------------------------------------

module feedback_clk_with_users (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        enable,

    // Feedback control
    input  wire        feedback_en,    // Enable feedback path

    // Data
    input  wire [31:0] data_in,
    output wire [31:0] data_out,

    // Feedback clock output
    output wire        feedback_clk
);

    //=========================================================================
    // Feedback Clock Divider (simplified)
    // MUX -> REG -> MUX -> REG (feedback to first MUX)
    //=========================================================================
    wire mux0_out, mux1_out;
    reg  reg0_q, reg1_q;

    // First MUX: clk_in or feedback
    assign mux0_out = feedback_en ? reg1_q : clk_in;

    // First divider stage
    always @(posedge mux0_out or negedge rst_n) begin
        if (!rst_n)
            reg0_q <= 1'b0;
        else if (enable)
            reg0_q <= ~reg0_q;
    end

    // Second MUX (pass through in this example)
    assign mux1_out = reg0_q;

    // Second divider stage (output feeds back)
    always @(posedge mux1_out or negedge rst_n) begin
        if (!rst_n)
            reg1_q <= 1'b0;
        else if (enable)
            reg1_q <= ~reg1_q;
    end

    assign feedback_clk = reg1_q;

    //=========================================================================
    // Registers using feedback clock (ensures tool recognition)
    //=========================================================================
    reg [7:0] fb_r0, fb_r1, fb_r2, fb_r3;
    reg [7:0] fb_r4, fb_r5, fb_r6, fb_r7;
    reg [7:0] fb_r8, fb_r9, fb_r10, fb_r11;

    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r0 <= 8'h0; else fb_r0 <= data_in[7:0];
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r1 <= 8'h0; else fb_r1 <= data_in[15:8];
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r2 <= 8'h0; else fb_r2 <= data_in[23:16];
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r3 <= 8'h0; else fb_r3 <= data_in[31:24];
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r4 <= 8'h0; else fb_r4 <= fb_r0 + fb_r1;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r5 <= 8'h0; else fb_r5 <= fb_r2 + fb_r3;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r6 <= 8'h0; else fb_r6 <= fb_r4 ^ fb_r5;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r7 <= 8'h0; else fb_r7 <= fb_r4 & fb_r5;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r8 <= 8'h0; else fb_r8 <= fb_r6 | fb_r7;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r9 <= 8'h0; else fb_r9 <= fb_r6 - fb_r7;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r10 <= 8'h0; else fb_r10 <= fb_r8 + fb_r9;
    end
    always @(posedge reg1_q or negedge rst_n) begin
        if (!rst_n) fb_r11 <= 8'h0; else fb_r11 <= fb_r8 ^ fb_r9;
    end

    //=========================================================================
    // Output
    //=========================================================================
    assign data_out = {fb_r11, fb_r10, fb_r9, fb_r8};

endmodule
