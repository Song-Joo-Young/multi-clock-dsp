//-----------------------------------------------------------------------------
// Module: clk_mux_2to1
// Description: Glitch-free 2:1 clock multiplexer
//              Uses synchronized selection with handshaking to prevent glitches
//-----------------------------------------------------------------------------

module clk_mux_2to1 (
    input  wire clk_a,    // Clock input A
    input  wire clk_b,    // Clock input B
    input  wire sel,      // Select: 0=clk_a, 1=clk_b
    input  wire rst_n,    // Async reset (active low)
    output wire clk_out   // Output clock
);

    //-------------------------------------------------------------------------
    // Synchronizers and enable logic for each clock domain
    //-------------------------------------------------------------------------
    reg [1:0] sync_a;  // Synchronizer in clk_a domain
    reg [1:0] sync_b;  // Synchronizer in clk_b domain

    wire sel_a_async;
    wire sel_b_async;
    wire en_a;
    wire en_b;

    // Selection logic: enable A when sel=0, enable B when sel=1
    // But only when the other clock is disabled (handshaking)
    assign sel_a_async = ~sel & ~sync_b[1];
    assign sel_b_async =  sel & ~sync_a[1];

    //-------------------------------------------------------------------------
    // Synchronize selection in clk_a domain (negedge for safe switching)
    //-------------------------------------------------------------------------
    always @(negedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            sync_a <= 2'b00;
        end else begin
            sync_a <= {sync_a[0], sel_a_async};
        end
    end

    //-------------------------------------------------------------------------
    // Synchronize selection in clk_b domain (negedge for safe switching)
    //-------------------------------------------------------------------------
    always @(negedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            sync_b <= 2'b00;
        end else begin
            sync_b <= {sync_b[0], sel_b_async};
        end
    end

    // Enable signals after synchronization
    assign en_a = sync_a[1];
    assign en_b = sync_b[1];

    //-------------------------------------------------------------------------
    // Glitch-free clock output
    //-------------------------------------------------------------------------
    assign clk_out = (clk_a & en_a) | (clk_b & en_b);

endmodule


//-----------------------------------------------------------------------------
// Module: clk_mux_4to1
// Description: Glitch-free 4:1 clock multiplexer
//              Built using three 2:1 muxes in tree structure
//-----------------------------------------------------------------------------

module clk_mux_4to1 (
    input  wire clk_0,      // Clock input 0
    input  wire clk_1,      // Clock input 1
    input  wire clk_2,      // Clock input 2
    input  wire clk_3,      // Clock input 3
    input  wire [1:0] sel,  // Select: 00=clk_0, 01=clk_1, 10=clk_2, 11=clk_3
    input  wire rst_n,      // Async reset (active low)
    output wire clk_out     // Output clock
);

    wire clk_01;  // Intermediate: mux of clk_0 and clk_1
    wire clk_23;  // Intermediate: mux of clk_2 and clk_3

    //-------------------------------------------------------------------------
    // First level: select between clk_0/clk_1 and clk_2/clk_3
    //-------------------------------------------------------------------------
    clk_mux_2to1 u_mux_01 (
        .clk_a   (clk_0),
        .clk_b   (clk_1),
        .sel     (sel[0]),
        .rst_n   (rst_n),
        .clk_out (clk_01)
    );

    clk_mux_2to1 u_mux_23 (
        .clk_a   (clk_2),
        .clk_b   (clk_3),
        .sel     (sel[0]),
        .rst_n   (rst_n),
        .clk_out (clk_23)
    );

    //-------------------------------------------------------------------------
    // Second level: select between first level outputs
    //-------------------------------------------------------------------------
    clk_mux_2to1 u_mux_final (
        .clk_a   (clk_01),
        .clk_b   (clk_23),
        .sel     (sel[1]),
        .rst_n   (rst_n),
        .clk_out (clk_out)
    );

endmodule


//-----------------------------------------------------------------------------
// Module: clk_mux_2to1_simple
// Description: Simple 2:1 clock mux (for DFT bypass, not glitch-free)
//              Use only when switching occurs during reset or idle
//-----------------------------------------------------------------------------

module clk_mux_2to1_simple (
    input  wire clk_a,    // Clock input A
    input  wire clk_b,    // Clock input B
    input  wire sel,      // Select: 0=clk_a, 1=clk_b
    output wire clk_out   // Output clock
);

    assign clk_out = sel ? clk_b : clk_a;

endmodule
