//-----------------------------------------------------------------------------
// Module: dsp_mac
// Description: Multiply-Accumulate Unit (MAC)
//              Core DSP building block for filtering and convolution
//-----------------------------------------------------------------------------

module dsp_mac #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 40   // Wider accumulator to prevent overflow
)(
    input  wire                    clk,          // System clock
    input  wire                    rst_n,        // Async reset
    input  wire                    clk_en,       // Clock enable (from ICG)

    // Control
    input  wire                    clear_acc,    // Clear accumulator
    input  wire                    enable,       // Enable MAC operation

    // Data inputs
    input  wire [DATA_WIDTH-1:0]   data_a,       // Input A (e.g., sample)
    input  wire [DATA_WIDTH-1:0]   data_b,       // Input B (e.g., coefficient)

    // Output
    output reg  [ACC_WIDTH-1:0]    acc_out,      // Accumulator output
    output wire [DATA_WIDTH-1:0]   result        // Truncated result
);

    //=========================================================================
    // Multiply and Accumulate Logic
    //=========================================================================
    wire signed [DATA_WIDTH-1:0]   a_signed;
    wire signed [DATA_WIDTH-1:0]   b_signed;
    wire signed [2*DATA_WIDTH-1:0] product;
    wire signed [ACC_WIDTH-1:0]    product_ext;
    wire signed [ACC_WIDTH-1:0]    acc_next;

    assign a_signed    = data_a;
    assign b_signed    = data_b;
    assign product     = a_signed * b_signed;
    assign product_ext = {{(ACC_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};
    assign acc_next    = $signed(acc_out) + product_ext;

    //=========================================================================
    // Accumulator Register (gated by clk_en)
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= {ACC_WIDTH{1'b0}};
        end else if (clk_en) begin
            if (clear_acc) begin
                acc_out <= {ACC_WIDTH{1'b0}};
            end else if (enable) begin
                acc_out <= acc_next;
            end
        end
    end

    // Truncated output (take upper bits after accumulation)
    assign result = acc_out[ACC_WIDTH-1 -: DATA_WIDTH];

endmodule


//-----------------------------------------------------------------------------
// Module: dsp_fir_engine
// Description: Simple FIR Filter Engine
//              Uses single MAC with coefficient memory
//-----------------------------------------------------------------------------

module dsp_fir_engine #(
    parameter DATA_WIDTH   = 16,
    parameter COEFF_WIDTH  = 16,
    parameter TAP_COUNT    = 8,
    parameter ACC_WIDTH    = 40
)(
    input  wire                      clk,           // Fast processing clock
    input  wire                      rst_n,         // Async reset
    input  wire                      clk_en,        // Clock enable

    // Control
    input  wire                      start,         // Start filtering
    input  wire                      load_coeff,    // Load coefficient mode
    input  wire [$clog2(TAP_COUNT)-1:0] coeff_addr, // Coefficient address
    input  wire [COEFF_WIDTH-1:0]    coeff_data,    // Coefficient data

    // Data interface
    input  wire [DATA_WIDTH-1:0]     sample_in,     // Input sample
    output reg  [DATA_WIDTH-1:0]     sample_out,    // Filtered output
    output reg                       valid_out,     // Output valid
    output reg                       busy           // Filter busy
);

    //=========================================================================
    // Internal registers and memory
    //=========================================================================
    reg [COEFF_WIDTH-1:0] coeff_mem [0:TAP_COUNT-1];
    reg [DATA_WIDTH-1:0]  sample_buf [0:TAP_COUNT-1];

    reg [$clog2(TAP_COUNT):0] tap_counter;
    reg [2:0] state;

    localparam S_IDLE    = 3'd0;
    localparam S_LOAD    = 3'd1;
    localparam S_COMPUTE = 3'd2;
    localparam S_OUTPUT  = 3'd3;

    //=========================================================================
    // MAC instantiation
    //=========================================================================
    reg                   mac_clear;
    reg                   mac_enable;
    reg  [DATA_WIDTH-1:0] mac_data_a;
    reg  [COEFF_WIDTH-1:0] mac_data_b;
    wire [ACC_WIDTH-1:0]  mac_acc;
    wire [DATA_WIDTH-1:0] mac_result;

    dsp_mac #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) u_mac (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .clear_acc (mac_clear),
        .enable    (mac_enable),
        .data_a    (mac_data_a),
        .data_b    (mac_data_b),
        .acc_out   (mac_acc),
        .result    (mac_result)
    );

    //=========================================================================
    // Coefficient Loading
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize coefficients to zero
            // (Use generate for synthesis, loop for sim)
        end else if (clk_en && load_coeff) begin
            coeff_mem[coeff_addr] <= coeff_data;
        end
    end

    //=========================================================================
    // Sample Buffer Shift Register
    //=========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TAP_COUNT; i = i + 1) begin
                sample_buf[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (clk_en && (state == S_LOAD)) begin
            // Shift samples
            sample_buf[0] <= sample_in;
            for (i = 1; i < TAP_COUNT; i = i + 1) begin
                sample_buf[i] <= sample_buf[i-1];
            end
        end
    end

    //=========================================================================
    // FIR State Machine
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            tap_counter <= 0;
            busy        <= 1'b0;
            valid_out   <= 1'b0;
            sample_out  <= {DATA_WIDTH{1'b0}};
            mac_clear   <= 1'b0;
            mac_enable  <= 1'b0;
            mac_data_a  <= {DATA_WIDTH{1'b0}};
            mac_data_b  <= {COEFF_WIDTH{1'b0}};
        end else if (clk_en) begin
            case (state)
                S_IDLE: begin
                    valid_out  <= 1'b0;
                    mac_clear  <= 1'b0;
                    mac_enable <= 1'b0;
                    if (start && !load_coeff) begin
                        state       <= S_LOAD;
                        busy        <= 1'b1;
                        mac_clear   <= 1'b1;
                    end
                end

                S_LOAD: begin
                    mac_clear   <= 1'b0;
                    state       <= S_COMPUTE;
                    tap_counter <= 0;
                end

                S_COMPUTE: begin
                    mac_enable <= 1'b1;
                    mac_data_a <= sample_buf[tap_counter];
                    mac_data_b <= coeff_mem[tap_counter];

                    if (tap_counter >= TAP_COUNT - 1) begin
                        state      <= S_OUTPUT;
                        mac_enable <= 1'b0;
                    end else begin
                        tap_counter <= tap_counter + 1'b1;
                    end
                end

                S_OUTPUT: begin
                    sample_out <= mac_result;
                    valid_out  <= 1'b1;
                    busy       <= 1'b0;
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule


//-----------------------------------------------------------------------------
// Module: dsp_data_interface
// Description: Data interface with clock domain crossing
//              Handles slow ADC input and fast DSP processing
//-----------------------------------------------------------------------------

module dsp_data_interface #(
    parameter DATA_WIDTH = 16,
    parameter FIFO_DEPTH = 8
)(
    // Slow clock domain (ADC side)
    input  wire                    slow_clk,      // ADC clock (divided clock)
    input  wire                    slow_rst_n,    // Reset in slow domain

    // Fast clock domain (DSP side)
    input  wire                    fast_clk,      // DSP processing clock
    input  wire                    fast_rst_n,    // Reset in fast domain

    // Slow domain interface
    input  wire [DATA_WIDTH-1:0]   adc_data_in,   // ADC data input
    input  wire                    adc_valid,     // ADC data valid

    // Fast domain interface
    output reg  [DATA_WIDTH-1:0]   dsp_data_out,  // Data to DSP
    output reg                     dsp_valid,     // Data valid to DSP
    input  wire                    dsp_ready,     // DSP ready for data

    // Status
    output wire                    fifo_empty,
    output wire                    fifo_full
);

    //=========================================================================
    // Async FIFO for clock domain crossing
    //=========================================================================
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] wr_ptr_bin;
    reg [$clog2(FIFO_DEPTH):0] rd_ptr_bin;
    reg [$clog2(FIFO_DEPTH):0] wr_ptr_gray;
    reg [$clog2(FIFO_DEPTH):0] rd_ptr_gray;

    // Synchronized pointers
    reg [$clog2(FIFO_DEPTH):0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    reg [$clog2(FIFO_DEPTH):0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    // Binary to Gray conversion
    function [$clog2(FIFO_DEPTH):0] bin2gray;
        input [$clog2(FIFO_DEPTH):0] bin;
        begin
            bin2gray = bin ^ (bin >> 1);
        end
    endfunction

    //=========================================================================
    // Write side (slow clock domain)
    //=========================================================================
    wire wr_enable;
    assign wr_enable = adc_valid && !fifo_full;

    always @(posedge slow_clk or negedge slow_rst_n) begin
        if (!slow_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_enable) begin
            fifo_mem[wr_ptr_bin[$clog2(FIFO_DEPTH)-1:0]] <= adc_data_in;
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= bin2gray(wr_ptr_bin + 1'b1);
        end
    end

    // Sync read pointer to write domain
    always @(posedge slow_clk or negedge slow_rst_n) begin
        if (!slow_rst_n) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    assign fifo_full = (wr_ptr_gray == {~rd_ptr_gray_sync2[$clog2(FIFO_DEPTH):$clog2(FIFO_DEPTH)-1],
                                         rd_ptr_gray_sync2[$clog2(FIFO_DEPTH)-2:0]});

    //=========================================================================
    // Read side (fast clock domain)
    //=========================================================================
    wire rd_enable;
    assign rd_enable = dsp_ready && !fifo_empty;

    always @(posedge fast_clk or negedge fast_rst_n) begin
        if (!fast_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
            dsp_data_out <= {DATA_WIDTH{1'b0}};
            dsp_valid    <= 1'b0;
        end else begin
            dsp_valid <= 1'b0;
            if (rd_enable) begin
                dsp_data_out <= fifo_mem[rd_ptr_bin[$clog2(FIFO_DEPTH)-1:0]];
                dsp_valid    <= 1'b1;
                rd_ptr_bin   <= rd_ptr_bin + 1'b1;
                rd_ptr_gray  <= bin2gray(rd_ptr_bin + 1'b1);
            end
        end
    end

    // Sync write pointer to read domain
    always @(posedge fast_clk or negedge fast_rst_n) begin
        if (!fast_rst_n) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    assign fifo_empty = (rd_ptr_gray == wr_ptr_gray_sync2);

endmodule
