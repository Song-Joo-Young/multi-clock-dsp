// Multi-Clock DSP RTL File List
// Top module: multi_clock_dsp_top (in clock_subsystem.v)

// Basic building blocks (bottom-up order)
./rtl/clock_gating_cell.v
./rtl/clock_mux.v
./rtl/clock_divider.v

// DFT modules
./rtl/jtag_tap.v
./rtl/bist_clock_ctrl.v
./rtl/dft_clock_ctrl.v

// DSP core
./rtl/dsp_core.v

// Top-level integration
./rtl/clock_subsystem.v
