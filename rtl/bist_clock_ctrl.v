//-----------------------------------------------------------------------------
// Module: bist_clock_ctrl
// Description: BIST (Built-In Self-Test) Clock Controller
//              Generates and controls clock for memory/logic BIST operations
//-----------------------------------------------------------------------------

module bist_clock_ctrl #(
    parameter BIST_PATTERN_WIDTH = 8,    // Width of BIST pattern counter
    parameter BIST_CLOCK_DIV     = 2     // BIST clock division ratio
)(
    input  wire                         clk_in,         // Input reference clock
    input  wire                         rst_n,          // Async reset (active low)

    // BIST control interface
    input  wire                         bist_enable,    // Enable BIST mode
    input  wire                         bist_start,     // Start BIST sequence
    input  wire                         bist_hold,      // Hold/pause BIST
    input  wire [BIST_PATTERN_WIDTH-1:0] bist_max_count, // Maximum pattern count

    // BIST outputs
    output reg                          bist_clk_out,   // BIST clock output
    output reg                          bist_active,    // BIST is running
    output reg                          bist_done,      // BIST sequence complete
    output reg [BIST_PATTERN_WIDTH-1:0] bist_count,     // Current pattern count
    output wire                         bist_clk_en     // Clock enable for gating
);

    //=========================================================================
    // BIST State Machine
    //=========================================================================
    localparam [2:0]
        BIST_IDLE     = 3'b000,
        BIST_INIT     = 3'b001,
        BIST_RUN      = 3'b010,
        BIST_PAUSE    = 3'b011,
        BIST_COMPLETE = 3'b100;

    reg [2:0] bist_state;
    reg [2:0] bist_state_next;

    //=========================================================================
    // Clock Divider for BIST Clock
    //=========================================================================
    reg [$clog2(BIST_CLOCK_DIV)-1:0] clk_div_counter;
    reg                              clk_div_toggle;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_counter <= 0;
            clk_div_toggle  <= 1'b0;
        end else if (bist_enable && bist_active && !bist_hold) begin
            if (clk_div_counter >= (BIST_CLOCK_DIV - 1)) begin
                clk_div_counter <= 0;
                clk_div_toggle  <= ~clk_div_toggle;
            end else begin
                clk_div_counter <= clk_div_counter + 1'b1;
            end
        end else begin
            clk_div_counter <= 0;
        end
    end

    //=========================================================================
    // BIST Clock Output Generation
    //=========================================================================
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            bist_clk_out <= 1'b0;
        end else if (bist_enable && bist_active && !bist_hold) begin
            bist_clk_out <= clk_div_toggle;
        end else begin
            bist_clk_out <= 1'b0;
        end
    end

    //=========================================================================
    // BIST State Machine - Next State Logic
    //=========================================================================
    always @(*) begin
        bist_state_next = bist_state;

        case (bist_state)
            BIST_IDLE: begin
                if (bist_enable && bist_start) begin
                    bist_state_next = BIST_INIT;
                end
            end

            BIST_INIT: begin
                bist_state_next = BIST_RUN;
            end

            BIST_RUN: begin
                if (!bist_enable) begin
                    bist_state_next = BIST_IDLE;
                end else if (bist_hold) begin
                    bist_state_next = BIST_PAUSE;
                end else if (bist_count >= bist_max_count) begin
                    bist_state_next = BIST_COMPLETE;
                end
            end

            BIST_PAUSE: begin
                if (!bist_enable) begin
                    bist_state_next = BIST_IDLE;
                end else if (!bist_hold) begin
                    bist_state_next = BIST_RUN;
                end
            end

            BIST_COMPLETE: begin
                if (!bist_enable || bist_start) begin
                    bist_state_next = BIST_IDLE;
                end
            end

            default: bist_state_next = BIST_IDLE;
        endcase
    end

    //=========================================================================
    // BIST State Machine - State Register
    //=========================================================================
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            bist_state <= BIST_IDLE;
        end else begin
            bist_state <= bist_state_next;
        end
    end

    //=========================================================================
    // BIST Control Outputs
    //=========================================================================
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            bist_active <= 1'b0;
            bist_done   <= 1'b0;
            bist_count  <= {BIST_PATTERN_WIDTH{1'b0}};
        end else begin
            case (bist_state)
                BIST_IDLE: begin
                    bist_active <= 1'b0;
                    bist_done   <= 1'b0;
                    bist_count  <= {BIST_PATTERN_WIDTH{1'b0}};
                end

                BIST_INIT: begin
                    bist_active <= 1'b1;
                    bist_done   <= 1'b0;
                    bist_count  <= {BIST_PATTERN_WIDTH{1'b0}};
                end

                BIST_RUN: begin
                    bist_active <= 1'b1;
                    // Increment count on BIST clock edge
                    if (clk_div_toggle && (clk_div_counter == 0)) begin
                        bist_count <= bist_count + 1'b1;
                    end
                end

                BIST_PAUSE: begin
                    bist_active <= 1'b1;
                    // Count frozen during pause
                end

                BIST_COMPLETE: begin
                    bist_active <= 1'b0;
                    bist_done   <= 1'b1;
                end

                default: begin
                    bist_active <= 1'b0;
                    bist_done   <= 1'b0;
                end
            endcase
        end
    end

    // Clock enable output for ICG
    assign bist_clk_en = bist_enable & bist_active & ~bist_hold;

endmodule


//-----------------------------------------------------------------------------
// Module: bist_pattern_gen
// Description: Simple BIST pattern generator (LFSR-based)
//              Generates pseudo-random patterns for test
//-----------------------------------------------------------------------------

module bist_pattern_gen #(
    parameter PATTERN_WIDTH = 16
)(
    input  wire                      clk,        // BIST clock
    input  wire                      rst_n,      // Async reset
    input  wire                      enable,     // Enable pattern generation
    input  wire                      load,       // Load seed value
    input  wire [PATTERN_WIDTH-1:0]  seed,       // Seed value
    output wire [PATTERN_WIDTH-1:0]  pattern     // Output pattern
);

    reg [PATTERN_WIDTH-1:0] lfsr;

    // LFSR feedback (polynomial depends on width)
    // Using x^16 + x^14 + x^13 + x^11 + 1 for 16-bit
    wire feedback;

    generate
        if (PATTERN_WIDTH == 16) begin : gen_16bit
            assign feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
        end else if (PATTERN_WIDTH == 8) begin : gen_8bit
            assign feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];
        end else begin : gen_default
            assign feedback = lfsr[PATTERN_WIDTH-1] ^ lfsr[0];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= {{PATTERN_WIDTH-1{1'b0}}, 1'b1};  // Non-zero initial
        end else if (load) begin
            lfsr <= (seed == 0) ? {{PATTERN_WIDTH-1{1'b0}}, 1'b1} : seed;
        end else if (enable) begin
            lfsr <= {lfsr[PATTERN_WIDTH-2:0], feedback};
        end
    end

    assign pattern = lfsr;

endmodule
