//-----------------------------------------------------------------------------
// Module: clock_gating_cell
// Description: ICG (Integrated Clock Gating) cell wrapper
//              Uses Nangate CLKGATETST_X1 library cell
//-----------------------------------------------------------------------------

module clock_gating_cell (
    input  wire clk_in,      // Input clock
    input  wire enable,      // Clock enable (active high)
    input  wire scan_enable, // Scan enable for DFT (bypasses gating)
    output wire clk_out      // Gated clock output
);

    //-------------------------------------------------------------------------
    // Instantiate Nangate Library ICG cell (CLKGATETST_X1)
    //-------------------------------------------------------------------------
    CLKGATETST_X1 u_icg (
        .CK  (clk_in),
        .E   (enable),
        .SE  (scan_enable),
        .GCK (clk_out)
    );

endmodule


//-----------------------------------------------------------------------------
// Module: clock_gating_cell_no_test
// Description: ICG cell without scan enable (basic version)
//              Uses Nangate CLKGATE_X1 library cell
//-----------------------------------------------------------------------------

module clock_gating_cell_no_test (
    input  wire clk_in,   // Input clock
    input  wire enable,   // Clock enable (active high)
    output wire clk_out   // Gated clock output
);

    //-------------------------------------------------------------------------
    // Instantiate Nangate Library ICG cell (CLKGATE_X1)
    //-------------------------------------------------------------------------
    CLKGATE_X1 u_icg (
        .CK  (clk_in),
        .E   (enable),
        .GCK (clk_out)
    );

endmodule
