//-----------------------------------------------------------------------------
// Module: jtag_tap
// Description: IEEE 1149.1 compliant JTAG TAP Controller
//              Supports BYPASS and IDCODE instructions
//-----------------------------------------------------------------------------

module jtag_tap #(
    parameter IDCODE_VALUE = 32'h1234_5678  // Device ID code
)(
    // JTAG interface
    input  wire        tck,       // Test clock
    input  wire        tms,       // Test mode select
    input  wire        tdi,       // Test data in
    input  wire        trst_n,    // Test reset (active low)
    output reg         tdo,       // Test data out
    output wire        tdo_en,    // TDO output enable

    // TAP state outputs (active high)
    output wire        tap_reset,       // Test-Logic-Reset state
    output wire        tap_idle,        // Run-Test/Idle state
    output wire        tap_shift_dr,    // Shift-DR state
    output wire        tap_shift_ir,    // Shift-IR state
    output wire        tap_capture_dr,  // Capture-DR state
    output wire        tap_update_dr,   // Update-DR state
    output wire        tap_update_ir    // Update-IR state
);

    //=========================================================================
    // TAP State Machine - IEEE 1149.1 State Encoding
    //=========================================================================
    localparam [3:0]
        TEST_LOGIC_RESET = 4'h0,
        RUN_TEST_IDLE    = 4'h1,
        SELECT_DR_SCAN   = 4'h2,
        CAPTURE_DR       = 4'h3,
        SHIFT_DR         = 4'h4,
        EXIT1_DR         = 4'h5,
        PAUSE_DR         = 4'h6,
        EXIT2_DR         = 4'h7,
        UPDATE_DR        = 4'h8,
        SELECT_IR_SCAN   = 4'h9,
        CAPTURE_IR       = 4'hA,
        SHIFT_IR         = 4'hB,
        EXIT1_IR         = 4'hC,
        PAUSE_IR         = 4'hD,
        EXIT2_IR         = 4'hE,
        UPDATE_IR        = 4'hF;

    reg [3:0] tap_state;
    reg [3:0] tap_state_next;

    //=========================================================================
    // Instruction Register
    //=========================================================================
    localparam IR_LENGTH = 4;

    // Instruction opcodes
    localparam [IR_LENGTH-1:0]
        INSTR_BYPASS = 4'b1111,
        INSTR_IDCODE = 4'b0001,
        INSTR_SAMPLE = 4'b0010;  // Sample/Preload (optional)

    reg [IR_LENGTH-1:0] ir_shift;   // IR shift register
    reg [IR_LENGTH-1:0] ir_reg;     // IR hold register

    //=========================================================================
    // Data Registers
    //=========================================================================
    reg [31:0] idcode_reg;          // IDCODE register (32-bit)
    reg        bypass_reg;           // BYPASS register (1-bit)

    //=========================================================================
    // TAP State Machine - Next State Logic
    //=========================================================================
    always @(*) begin
        case (tap_state)
            TEST_LOGIC_RESET: tap_state_next = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            RUN_TEST_IDLE:    tap_state_next = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;
            SELECT_DR_SCAN:   tap_state_next = tms ? SELECT_IR_SCAN   : CAPTURE_DR;
            CAPTURE_DR:       tap_state_next = tms ? EXIT1_DR         : SHIFT_DR;
            SHIFT_DR:         tap_state_next = tms ? EXIT1_DR         : SHIFT_DR;
            EXIT1_DR:         tap_state_next = tms ? UPDATE_DR        : PAUSE_DR;
            PAUSE_DR:         tap_state_next = tms ? EXIT2_DR         : PAUSE_DR;
            EXIT2_DR:         tap_state_next = tms ? UPDATE_DR        : SHIFT_DR;
            UPDATE_DR:        tap_state_next = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;
            SELECT_IR_SCAN:   tap_state_next = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
            CAPTURE_IR:       tap_state_next = tms ? EXIT1_IR         : SHIFT_IR;
            SHIFT_IR:         tap_state_next = tms ? EXIT1_IR         : SHIFT_IR;
            EXIT1_IR:         tap_state_next = tms ? UPDATE_IR        : PAUSE_IR;
            PAUSE_IR:         tap_state_next = tms ? EXIT2_IR         : PAUSE_IR;
            EXIT2_IR:         tap_state_next = tms ? UPDATE_IR        : SHIFT_IR;
            UPDATE_IR:        tap_state_next = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;
            default:          tap_state_next = TEST_LOGIC_RESET;
        endcase
    end

    //=========================================================================
    // TAP State Machine - State Register
    //=========================================================================
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tap_state <= TEST_LOGIC_RESET;
        end else begin
            tap_state <= tap_state_next;
        end
    end

    //=========================================================================
    // TAP State Outputs
    //=========================================================================
    assign tap_reset      = (tap_state == TEST_LOGIC_RESET);
    assign tap_idle       = (tap_state == RUN_TEST_IDLE);
    assign tap_shift_dr   = (tap_state == SHIFT_DR);
    assign tap_shift_ir   = (tap_state == SHIFT_IR);
    assign tap_capture_dr = (tap_state == CAPTURE_DR);
    assign tap_update_dr  = (tap_state == UPDATE_DR);
    assign tap_update_ir  = (tap_state == UPDATE_IR);

    //=========================================================================
    // Instruction Register Logic
    //=========================================================================
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            ir_shift <= {IR_LENGTH{1'b1}};  // Default to BYPASS
            ir_reg   <= INSTR_IDCODE;        // Power-up with IDCODE selected
        end else begin
            case (tap_state)
                CAPTURE_IR: begin
                    ir_shift <= 4'b0001;  // Capture pattern (LSB=1 per spec)
                end
                SHIFT_IR: begin
                    ir_shift <= {tdi, ir_shift[IR_LENGTH-1:1]};
                end
                UPDATE_IR: begin
                    ir_reg <= ir_shift;
                end
                TEST_LOGIC_RESET: begin
                    ir_reg <= INSTR_IDCODE;  // Reset selects IDCODE
                end
                default: ;
            endcase
        end
    end

    //=========================================================================
    // Data Register Logic
    //=========================================================================
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            idcode_reg <= IDCODE_VALUE;
            bypass_reg <= 1'b0;
        end else begin
            case (tap_state)
                CAPTURE_DR: begin
                    case (ir_reg)
                        INSTR_IDCODE: idcode_reg <= IDCODE_VALUE;
                        INSTR_BYPASS: bypass_reg <= 1'b0;
                        default:      bypass_reg <= 1'b0;
                    endcase
                end
                SHIFT_DR: begin
                    case (ir_reg)
                        INSTR_IDCODE: idcode_reg <= {tdi, idcode_reg[31:1]};
                        INSTR_BYPASS: bypass_reg <= tdi;
                        default:      bypass_reg <= tdi;
                    endcase
                end
                default: ;
            endcase
        end
    end

    //=========================================================================
    // TDO Output Logic (updated on falling edge of TCK)
    //=========================================================================
    reg tdo_ir;
    reg tdo_dr;

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo    <= 1'b0;
            tdo_ir <= 1'b0;
            tdo_dr <= 1'b0;
        end else begin
            // IR output
            tdo_ir <= ir_shift[0];

            // DR output based on selected instruction
            case (ir_reg)
                INSTR_IDCODE: tdo_dr <= idcode_reg[0];
                INSTR_BYPASS: tdo_dr <= bypass_reg;
                default:      tdo_dr <= bypass_reg;
            endcase

            // Select TDO source
            if (tap_state == SHIFT_IR) begin
                tdo <= tdo_ir;
            end else begin
                tdo <= tdo_dr;
            end
        end
    end

    // TDO is only driven during Shift states
    assign tdo_en = (tap_state == SHIFT_DR) || (tap_state == SHIFT_IR);

endmodule
