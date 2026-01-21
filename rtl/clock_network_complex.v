//-----------------------------------------------------------------------------
// Module: clock_network_complex
// Description: Complex clock network with multiple ICG instances
//              Mix of inferred and instantiated ICGs
//              Hierarchical clock gating structure
//-----------------------------------------------------------------------------

module clock_network_complex (
    input  wire        clk_in,
    input  wire        rst_n,

    // Top-level clock enables
    input  wire        top_clk_en,        // Top-level gate
    input  wire        scan_enable,       // Scan mode bypass

    // Block enables
    input  wire        blk_a_en,          // Block A enable
    input  wire        blk_b_en,          // Block B enable
    input  wire        blk_c_en,          // Block C enable

    // Sub-block enables
    input  wire        blk_a_sub0_en,
    input  wire        blk_a_sub1_en,
    input  wire        blk_b_sub0_en,
    input  wire        blk_b_sub1_en,

    // Data interface (for functional activity)
    input  wire [15:0] data_in,
    output wire [15:0] data_out,

    // Clock outputs for monitoring
    output wire        clk_gated_top,
    output wire        clk_gated_blk_a,
    output wire        clk_gated_blk_b,
    output wire        clk_gated_blk_c
);

    //=========================================================================
    // Level 0: Top-level ICG (INSTANTIATED - Nangate)
    // clk_in -> ICG_TOP -> clk_gated_top
    //=========================================================================
    wire clk_l0;

    clock_gating_cell u_icg_top (
        .clk_in      (clk_in),
        .enable      (top_clk_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_l0)
    );

    assign clk_gated_top = clk_l0;

    //=========================================================================
    // Level 1: Block-level ICGs
    // clk_l0 -> ICG_BLK_A -> clk_blk_a
    // clk_l0 -> ICG_BLK_B -> clk_blk_b
    // clk_l0 -> ICG_BLK_C -> clk_blk_c
    //=========================================================================
    wire clk_blk_a, clk_blk_b, clk_blk_c;

    // Block A ICG (INSTANTIATED)
    clock_gating_cell u_icg_blk_a (
        .clk_in      (clk_l0),
        .enable      (blk_a_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_blk_a)
    );

    // Block B ICG (INSTANTIATED)
    clock_gating_cell u_icg_blk_b (
        .clk_in      (clk_l0),
        .enable      (blk_b_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_blk_b)
    );

    // Block C ICG (INSTANTIATED - no test)
    clock_gating_cell_no_test u_icg_blk_c (
        .clk_in  (clk_l0),
        .enable  (blk_c_en),
        .clk_out (clk_blk_c)
    );

    assign clk_gated_blk_a = clk_blk_a;
    assign clk_gated_blk_b = clk_blk_b;
    assign clk_gated_blk_c = clk_blk_c;

    //=========================================================================
    // Level 2: Sub-block ICGs (under Block A and B)
    //=========================================================================
    wire clk_blk_a_sub0, clk_blk_a_sub1;
    wire clk_blk_b_sub0, clk_blk_b_sub1;

    // Block A Sub0 ICG (INSTANTIATED)
    clock_gating_cell u_icg_blk_a_sub0 (
        .clk_in      (clk_blk_a),
        .enable      (blk_a_sub0_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_blk_a_sub0)
    );

    // Block A Sub1 ICG (INSTANTIATED)
    clock_gating_cell u_icg_blk_a_sub1 (
        .clk_in      (clk_blk_a),
        .enable      (blk_a_sub1_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_blk_a_sub1)
    );

    // Block B Sub0 ICG (INSTANTIATED)
    clock_gating_cell u_icg_blk_b_sub0 (
        .clk_in      (clk_blk_b),
        .enable      (blk_b_sub0_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_blk_b_sub0)
    );

    // Block B Sub1 ICG (INSTANTIATED)
    clock_gating_cell u_icg_blk_b_sub1 (
        .clk_in      (clk_blk_b),
        .enable      (blk_b_sub1_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_blk_b_sub1)
    );

    //=========================================================================
    // Functional Logic with INFERRED ICGs
    //=========================================================================
    reg [15:0] reg_a_sub0, reg_a_sub1;
    reg [15:0] reg_b_sub0, reg_b_sub1;
    reg [15:0] reg_c;

    // Block A Sub0 register (clocked by ICG output)
    always @(posedge clk_blk_a_sub0 or negedge rst_n) begin
        if (!rst_n)
            reg_a_sub0 <= 16'h0;
        else
            reg_a_sub0 <= data_in + 16'h1;
    end

    // Block A Sub1 register
    always @(posedge clk_blk_a_sub1 or negedge rst_n) begin
        if (!rst_n)
            reg_a_sub1 <= 16'h0;
        else
            reg_a_sub1 <= reg_a_sub0 + 16'h2;
    end

    // Block B Sub0 register
    always @(posedge clk_blk_b_sub0 or negedge rst_n) begin
        if (!rst_n)
            reg_b_sub0 <= 16'h0;
        else
            reg_b_sub0 <= data_in ^ 16'hFFFF;
    end

    // Block B Sub1 register
    always @(posedge clk_blk_b_sub1 or negedge rst_n) begin
        if (!rst_n)
            reg_b_sub1 <= 16'h0;
        else
            reg_b_sub1 <= reg_b_sub0 & reg_a_sub1;
    end

    // Block C register (direct from level 1 ICG)
    always @(posedge clk_blk_c or negedge rst_n) begin
        if (!rst_n)
            reg_c <= 16'h0;
        else
            reg_c <= reg_a_sub1 | reg_b_sub1;
    end

    assign data_out = reg_c;

endmodule


//-----------------------------------------------------------------------------
// Module: hierarchical_clock_tree
// Description: Multi-level hierarchical clock tree
//              Demonstrates deep clock gating hierarchy
//-----------------------------------------------------------------------------

module hierarchical_clock_tree (
    input  wire        clk_root,
    input  wire        rst_n,
    input  wire        scan_enable,

    // Hierarchical enables
    input  wire        en_level1,
    input  wire [1:0]  en_level2,
    input  wire [3:0]  en_level3,
    input  wire [7:0]  en_level4,

    // Data
    input  wire [7:0]  data_in,
    output wire [7:0]  data_out
);

    //=========================================================================
    // Level 1: Root ICG
    //=========================================================================
    wire clk_l1;

    clock_gating_cell u_icg_l1 (
        .clk_in      (clk_root),
        .enable      (en_level1),
        .scan_enable (scan_enable),
        .clk_out     (clk_l1)
    );

    //=========================================================================
    // Level 2: 2 ICGs
    //=========================================================================
    wire [1:0] clk_l2;

    genvar i;
    generate
        for (i = 0; i < 2; i = i + 1) begin : gen_l2
            clock_gating_cell u_icg_l2 (
                .clk_in      (clk_l1),
                .enable      (en_level2[i]),
                .scan_enable (scan_enable),
                .clk_out     (clk_l2[i])
            );
        end
    endgenerate

    //=========================================================================
    // Level 3: 4 ICGs (2 under each L2)
    //=========================================================================
    wire [3:0] clk_l3;

    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_l3
            clock_gating_cell u_icg_l3 (
                .clk_in      (clk_l2[i/2]),
                .enable      (en_level3[i]),
                .scan_enable (scan_enable),
                .clk_out     (clk_l3[i])
            );
        end
    endgenerate

    //=========================================================================
    // Level 4: 8 ICGs (2 under each L3)
    //=========================================================================
    wire [7:0] clk_l4;

    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_l4
            clock_gating_cell u_icg_l4 (
                .clk_in      (clk_l3[i/2]),
                .enable      (en_level4[i]),
                .scan_enable (scan_enable),
                .clk_out     (clk_l4[i])
            );
        end
    endgenerate

    //=========================================================================
    // Leaf registers (one per L4 clock)
    //=========================================================================
    reg [7:0] leaf_regs [0:7];
    wire [7:0] leaf_sum;

    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_leaf
            always @(posedge clk_l4[i] or negedge rst_n) begin
                if (!rst_n)
                    leaf_regs[i] <= 8'h0;
                else
                    leaf_regs[i] <= data_in + i[7:0];
            end
        end
    endgenerate

    // Combine outputs
    assign leaf_sum = leaf_regs[0] ^ leaf_regs[1] ^ leaf_regs[2] ^ leaf_regs[3] ^
                      leaf_regs[4] ^ leaf_regs[5] ^ leaf_regs[6] ^ leaf_regs[7];
    assign data_out = leaf_sum;

endmodule


//-----------------------------------------------------------------------------
// Module: mixed_icg_block
// Description: Block with mixed inferred and instantiated ICGs
//              Shows synthesis tool pattern recognition
//-----------------------------------------------------------------------------

module mixed_icg_block (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        scan_enable,

    // Enable signals
    input  wire        inst_icg_en,      // For instantiated ICG
    input  wire        inf_icg_en,       // For inferred ICG pattern

    // Data
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    //=========================================================================
    // Path 1: INSTANTIATED ICG -> Register
    //=========================================================================
    wire clk_inst_gated;

    clock_gating_cell u_inst_icg (
        .clk_in      (clk),
        .enable      (inst_icg_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_inst_gated)
    );

    reg [15:0] reg_inst;
    always @(posedge clk_inst_gated or negedge rst_n) begin
        if (!rst_n)
            reg_inst <= 16'h0;
        else
            reg_inst <= data_in[15:0];
    end

    //=========================================================================
    // Path 2: INFERRED ICG pattern (synthesis tool should recognize)
    // Pattern: if (enable) reg <= data;
    // Synthesis tool will infer: clk -> ICG -> reg
    //=========================================================================
    reg [15:0] reg_inf;

    // This pattern should be recognized by synthesis tools as clock gating
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reg_inf <= 16'h0;
        else if (inf_icg_en)    // <-- Synthesis tool infers ICG from this
            reg_inf <= data_in[31:16];
    end

    //=========================================================================
    // Output
    //=========================================================================
    assign data_out = {reg_inf, reg_inst};

endmodule


//-----------------------------------------------------------------------------
// Module: clock_network_multiblock
// Description: Multiple processing blocks with independent clock gating
//              Each block has its own clock tree branch
//-----------------------------------------------------------------------------

module clock_network_multiblock (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        scan_enable,

    // Global enables
    input  wire        global_en,

    // Per-block enables
    input  wire        proc_en,
    input  wire        mem_en,
    input  wire        io_en,
    input  wire        ctrl_en,

    // Per-unit enables within blocks
    input  wire [3:0]  proc_unit_en,
    input  wire [1:0]  mem_unit_en,

    // Data interface
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    //=========================================================================
    // Global Clock Gate
    //=========================================================================
    wire clk_global;

    clock_gating_cell u_icg_global (
        .clk_in      (clk_in),
        .enable      (global_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_global)
    );

    //=========================================================================
    // Processing Block Clock Tree
    //=========================================================================
    wire clk_proc;
    wire [3:0] clk_proc_unit;

    // Processing block root ICG
    clock_gating_cell u_icg_proc (
        .clk_in      (clk_global),
        .enable      (proc_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_proc)
    );

    // Processing unit ICGs (4 units)
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_proc_unit
            clock_gating_cell u_icg_proc_unit (
                .clk_in      (clk_proc),
                .enable      (proc_unit_en[i]),
                .scan_enable (scan_enable),
                .clk_out     (clk_proc_unit[i])
            );
        end
    endgenerate

    // Processing unit registers
    reg [7:0] proc_reg [0:3];
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_proc_reg
            always @(posedge clk_proc_unit[i] or negedge rst_n) begin
                if (!rst_n)
                    proc_reg[i] <= 8'h0;
                else
                    proc_reg[i] <= data_in[i*8 +: 8] + i[7:0];
            end
        end
    endgenerate

    //=========================================================================
    // Memory Block Clock Tree
    //=========================================================================
    wire clk_mem;
    wire [1:0] clk_mem_unit;

    // Memory block root ICG
    clock_gating_cell u_icg_mem (
        .clk_in      (clk_global),
        .enable      (mem_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_mem)
    );

    // Memory unit ICGs (2 units)
    generate
        for (i = 0; i < 2; i = i + 1) begin : gen_mem_unit
            clock_gating_cell u_icg_mem_unit (
                .clk_in      (clk_mem),
                .enable      (mem_unit_en[i]),
                .scan_enable (scan_enable),
                .clk_out     (clk_mem_unit[i])
            );
        end
    endgenerate

    // Memory registers
    reg [15:0] mem_reg [0:1];
    generate
        for (i = 0; i < 2; i = i + 1) begin : gen_mem_reg
            always @(posedge clk_mem_unit[i] or negedge rst_n) begin
                if (!rst_n)
                    mem_reg[i] <= 16'h0;
                else
                    mem_reg[i] <= data_in[i*16 +: 16];
            end
        end
    endgenerate

    //=========================================================================
    // IO Block (single ICG)
    //=========================================================================
    wire clk_io;

    clock_gating_cell u_icg_io (
        .clk_in      (clk_global),
        .enable      (io_en),
        .scan_enable (scan_enable),
        .clk_out     (clk_io)
    );

    reg [31:0] io_reg;
    always @(posedge clk_io or negedge rst_n) begin
        if (!rst_n)
            io_reg <= 32'h0;
        else
            io_reg <= data_in;
    end

    //=========================================================================
    // Control Block (INFERRED ICG pattern)
    //=========================================================================
    reg [31:0] ctrl_reg;

    // Inferred ICG pattern
    always @(posedge clk_global or negedge rst_n) begin
        if (!rst_n)
            ctrl_reg <= 32'h0;
        else if (ctrl_en)
            ctrl_reg <= {proc_reg[3], proc_reg[2], proc_reg[1], proc_reg[0]};
    end

    //=========================================================================
    // Output Mux
    //=========================================================================
    assign data_out = ctrl_reg ^ io_reg ^ {mem_reg[1], mem_reg[0]};

endmodule


//-----------------------------------------------------------------------------
// Module: clock_gating_with_divider
// Description: Combines clock dividers with gating
//              Divided clocks each have their own ICG
//-----------------------------------------------------------------------------

module clock_gating_with_divider (
    input  wire        clk_in,
    input  wire        rst_n,
    input  wire        scan_enable,

    // Divider enable
    input  wire        div_en,

    // Per-domain enables
    input  wire        en_div1,     // Full speed
    input  wire        en_div2,     // /2
    input  wire        en_div4,     // /4
    input  wire        en_div8,     // /8

    // Data
    input  wire [15:0] data_in,
    output wire [15:0] data_out,

    // Clock outputs
    output wire        clk_div1_gated,
    output wire        clk_div2_gated,
    output wire        clk_div4_gated,
    output wire        clk_div8_gated
);

    //=========================================================================
    // Clock Divider Chain
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

    //=========================================================================
    // ICG for each clock domain
    //=========================================================================
    wire clk_d1_g, clk_d2_g, clk_d4_g, clk_d8_g;

    // Full speed ICG
    clock_gating_cell u_icg_div1 (
        .clk_in      (clk_in),
        .enable      (en_div1),
        .scan_enable (scan_enable),
        .clk_out     (clk_d1_g)
    );

    // /2 ICG
    clock_gating_cell u_icg_div2 (
        .clk_in      (div2_reg),
        .enable      (en_div2),
        .scan_enable (scan_enable),
        .clk_out     (clk_d2_g)
    );

    // /4 ICG
    clock_gating_cell u_icg_div4 (
        .clk_in      (div4_reg),
        .enable      (en_div4),
        .scan_enable (scan_enable),
        .clk_out     (clk_d4_g)
    );

    // /8 ICG
    clock_gating_cell u_icg_div8 (
        .clk_in      (div8_reg),
        .enable      (en_div8),
        .scan_enable (scan_enable),
        .clk_out     (clk_d8_g)
    );

    assign clk_div1_gated = clk_d1_g;
    assign clk_div2_gated = clk_d2_g;
    assign clk_div4_gated = clk_d4_g;
    assign clk_div8_gated = clk_d8_g;

    //=========================================================================
    // Registers in each clock domain
    //=========================================================================
    reg [3:0] reg_d1, reg_d2, reg_d4, reg_d8;

    always @(posedge clk_d1_g or negedge rst_n) begin
        if (!rst_n) reg_d1 <= 4'h0;
        else        reg_d1 <= data_in[3:0];
    end

    always @(posedge clk_d2_g or negedge rst_n) begin
        if (!rst_n) reg_d2 <= 4'h0;
        else        reg_d2 <= data_in[7:4];
    end

    always @(posedge clk_d4_g or negedge rst_n) begin
        if (!rst_n) reg_d4 <= 4'h0;
        else        reg_d4 <= data_in[11:8];
    end

    always @(posedge clk_d8_g or negedge rst_n) begin
        if (!rst_n) reg_d8 <= 4'h0;
        else        reg_d8 <= data_in[15:12];
    end

    assign data_out = {reg_d8, reg_d4, reg_d2, reg_d1};

endmodule
