//-----------------------------------------------------------------------------
// Module: clk_div_integer
// Description: Programmable integer clock divider with 50% duty cycle
//              Supports /2, /4, /8, /16 division ratios
//-----------------------------------------------------------------------------

module clk_div_integer (
    input  wire       clk_in,     // Input clock
    input  wire       rst_n,      // Async reset (active low)
    input  wire       enable,     // Divider enable
    input  wire [1:0] div_sel,    // Division select: 00=/2, 01=/4, 10=/8, 11=/16
    output wire       clk_out     // Divided clock output
);

    //-------------------------------------------------------------------------
    // Counter for clock division
    //-------------------------------------------------------------------------
    reg [3:0] counter;
    reg       clk_div2;
    reg       clk_div4;
    reg       clk_div8;
    reg       clk_div16;

    //-------------------------------------------------------------------------
    // 4-bit counter (counts 0 to 15)
    //-------------------------------------------------------------------------
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 4'b0000;
        end else if (enable) begin
            counter <= counter + 1'b1;
        end
    end

    //-------------------------------------------------------------------------
    // Generate divided clocks with 50% duty cycle
    //-------------------------------------------------------------------------
    // /2 clock
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            clk_div2 <= 1'b0;
        end else if (enable) begin
            clk_div2 <= ~clk_div2;
        end
    end

    // /4 clock
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            clk_div4 <= 1'b0;
        end else if (enable && counter[0]) begin
            clk_div4 <= ~clk_div4;
        end
    end

    // /8 clock
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            clk_div8 <= 1'b0;
        end else if (enable && (counter[1:0] == 2'b11)) begin
            clk_div8 <= ~clk_div8;
        end
    end

    // /16 clock
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            clk_div16 <= 1'b0;
        end else if (enable && (counter[2:0] == 3'b111)) begin
            clk_div16 <= ~clk_div16;
        end
    end

    //-------------------------------------------------------------------------
    // Output mux (select divided clock based on div_sel)
    //-------------------------------------------------------------------------
    reg clk_out_reg;

    always @(*) begin
        case (div_sel)
            2'b00:   clk_out_reg = clk_div2;
            2'b01:   clk_out_reg = clk_div4;
            2'b10:   clk_out_reg = clk_div8;
            2'b11:   clk_out_reg = clk_div16;
            default: clk_out_reg = clk_div2;
        endcase
    end

    assign clk_out = enable ? clk_out_reg : 1'b0;

endmodule


//-----------------------------------------------------------------------------
// Module: clk_div_fractional
// Description: Fractional clock divider using Sigma-Delta modulation
//              Division ratio: N + F/16 (N=integer part, F=fractional part)
//              Range: 1.0 to 16.9375 (8-bit: N[7:4]=1~16, F[3:0]=0~15)
//-----------------------------------------------------------------------------

module clk_div_fractional (
    input  wire       clk_in,        // Input clock
    input  wire       rst_n,         // Async reset (active low)
    input  wire       enable,        // Divider enable
    input  wire [7:0] div_ratio,     // Division ratio: {N[3:0], F[3:0]}
                                     // Actual ratio = N + F/16, N must be >= 1
    output reg        clk_out        // Divided clock output
);

    //-------------------------------------------------------------------------
    // Extract integer and fractional parts
    //-------------------------------------------------------------------------
    wire [3:0] div_n = div_ratio[7:4];  // Integer part (1-16)
    wire [3:0] div_f = div_ratio[3:0];  // Fractional part (0-15, represents 0/16 to 15/16)

    //-------------------------------------------------------------------------
    // Sigma-Delta accumulator
    //-------------------------------------------------------------------------
    reg [4:0] accumulator;     // 5-bit to handle overflow
    reg [3:0] cycle_counter;   // Counts cycles within one output period
    reg       phase;           // Output clock phase

    wire [4:0] acc_next;
    wire       acc_overflow;
    wire [3:0] div_value;      // Current division value (N or N+1)

    // Accumulator: add fractional part each half-period
    assign acc_next = accumulator + {1'b0, div_f};
    assign acc_overflow = acc_next[4];  // Overflow when >= 16

    // Division value: N+1 when accumulator overflows, else N
    assign div_value = acc_overflow ? (div_n + 1'b1) : div_n;

    //-------------------------------------------------------------------------
    // Main divider logic
    //-------------------------------------------------------------------------
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            accumulator   <= 5'b0;
            cycle_counter <= 4'b0;
            clk_out       <= 1'b0;
            phase         <= 1'b0;
        end else if (enable) begin
            if (cycle_counter >= (div_value - 1'b1)) begin
                // End of half-period
                cycle_counter <= 4'b0;
                clk_out       <= ~clk_out;
                phase         <= ~phase;

                // Update accumulator on positive edge of output
                if (!phase) begin
                    accumulator <= acc_next[3:0];  // Keep lower 4 bits
                end
            end else begin
                cycle_counter <= cycle_counter + 1'b1;
            end
        end else begin
            clk_out <= 1'b0;
        end
    end

endmodule


//-----------------------------------------------------------------------------
// Module: clk_div_bypass
// Description: Clock divider with bypass option
//              Combines integer divider with bypass mux
//-----------------------------------------------------------------------------

module clk_div_bypass (
    input  wire       clk_in,     // Input clock
    input  wire       rst_n,      // Async reset (active low)
    input  wire       enable,     // Divider enable
    input  wire       bypass,     // Bypass divider (1=pass through clk_in)
    input  wire [1:0] div_sel,    // Division select when not bypassed
    output wire       clk_out     // Output clock
);

    wire clk_divided;

    //-------------------------------------------------------------------------
    // Integer divider
    //-------------------------------------------------------------------------
    clk_div_integer u_divider (
        .clk_in  (clk_in),
        .rst_n   (rst_n),
        .enable  (enable & ~bypass),
        .div_sel (div_sel),
        .clk_out (clk_divided)
    );

    //-------------------------------------------------------------------------
    // Bypass mux
    //-------------------------------------------------------------------------
    assign clk_out = bypass ? clk_in : clk_divided;

endmodule
