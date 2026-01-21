// Multi-Clock DSP RTL File List
// Top module: multi_clock_dsp_top (in clock_subsystem.v)

// ============================================
// Basic building blocks (bottom-up order)
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
// Complex clock network (hierarchical ICG)
// ============================================
clock_network_complex.v

// ============================================
// DSP and example logic
// ============================================
dsp_core.v
example_logic.v

// ============================================
// Top-level integration
// ============================================
clock_subsystem.v
