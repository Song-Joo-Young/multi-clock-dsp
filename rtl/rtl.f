// Multi-Clock DSP RTL File List
// Top module: multi_clock_dsp_top (in clock_subsystem.v)

// ============================================
// Basic building blocks
// ============================================
clock_gating_cell.v
clock_mux.v

// ============================================
// Clock dividers
// ============================================
clock_divider.v
clock_divider_simple.v
clock_divider_feedback.v

// ============================================
// DFT modules
// ============================================
jtag_tap.v
bist_clock_ctrl.v
dft_clock_ctrl.v

// ============================================
// Clock networks
// ============================================
clock_network_complex.v
clock_network_messy.v

// ============================================
// DSP and logic
// ============================================
dsp_core.v
example_logic.v
clock_domain_logic.v

// ============================================
// Test patterns for duplicate detection
// ============================================
clock_reconvergence.v
clock_corner_cases.v
clock_cross_primary.v
clock_hierarchical_dup.v
clock_multi_path.v
clock_generate_array.v
clock_wire_conflict.v
clock_latch_gen.v
clock_long_chain.v
clock_test_patterns.v

// ============================================
// Top-level
// ============================================
clock_subsystem.v
