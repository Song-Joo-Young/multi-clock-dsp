//-----------------------------------------------------------------------------
// Module: clock_gating_cell
// Description: ICG (Integrated Clock Gating) cell wrapper
//              Uses Nangate CLKGATETST_X1 for synthesis
//              Behavioral model for simulation
//-----------------------------------------------------------------------------

module clock_gating_cell (
    input  wire clk_in,      // Input clock
    input  wire enable,      // Clock enable (active high)
    input  wire scan_enable, // Scan enable for DFT (bypasses gating)
    output wire clk_out      // Gated clock output
);

`ifdef SYNTHESIS
    //-------------------------------------------------------------------------
    // Synthesis: Instantiate Nangate Library ICG cell
    //-------------------------------------------------------------------------
    CLKGATETST_X1 u_icg (
        .CK  (clk_in),
        .E   (enable),
        .SE  (scan_enable),
        .GCK (clk_out)
    );

`else
    //-------------------------------------------------------------------------
    // Simulation: Behavioral model (latch-based ICG)
    //-------------------------------------------------------------------------
    reg latch_out;

    // Latch enable on negative edge of clock (transparent when clk_in = 0)
    always @(*) begin
        if (!clk_in) begin
            latch_out <= enable | scan_enable;
        end
    end

    // AND gated clock
    assign clk_out = clk_in & latch_out;

`endif

endmodule


//-----------------------------------------------------------------------------
// Module: clock_gating_cell_no_test
// Description: ICG cell without scan enable (basic version)
//              Uses Nangate CLKGATE_X1 for synthesis
//-----------------------------------------------------------------------------

module clock_gating_cell_no_test (
    input  wire clk_in,   // Input clock
    input  wire enable,   // Clock enable (active high)
    output wire clk_out   // Gated clock output
);

`ifdef SYNTHESIS
    //-------------------------------------------------------------------------
    // Synthesis: Instantiate Nangate Library ICG cell (no test)
    //-------------------------------------------------------------------------
    CLKGATE_X1 u_icg (
        .CK  (clk_in),
        .E   (enable),
        .GCK (clk_out)
    );

`else
    //-------------------------------------------------------------------------
    // Simulation: Behavioral model
    //-------------------------------------------------------------------------
    reg latch_out;

    always @(*) begin
        if (!clk_in) begin
            latch_out <= enable;
        end
    end

    assign clk_out = clk_in & latch_out;

`endif

endmodule
