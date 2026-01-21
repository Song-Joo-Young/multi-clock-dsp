# Multi-Clock DSP

복잡한 클럭 구조를 가진 DSP(Digital Signal Processing) RTL 설계 프로젝트

## 프로젝트 개요

다중 클럭 도메인, DFT(Design for Test) 지원, Clock Gating을 포함한 신호 처리 유닛 설계

### 주요 특징
- **다중 클럭 도메인**: 6개 독립 클럭 도메인
- **Clock Divider**: Integer(/2,4,8,16) + Fractional(1.0~16.0, Sigma-Delta)
- **DFT 지원**: Scan, JTAG (IDCODE+BYPASS), BIST
- **Library ICG**: Nangate Open Cell Library (CLKGATETST_X1)
- **Glitch-Free Mux**: 안전한 클럭 전환 (handshaking sync)
- **DSP Core**: MAC unit, FIR filter, async FIFO for CDC

## 디렉토리 구조

```
multi-clock-dsp/
├── README.md                  # 이 문서
├── DESIGN_GUIDE.md            # 상세 설계 가이드
├── rtl/                       # RTL 소스
│   ├── clock_gating_cell.v    # ICG cell wrapper (Nangate)
│   ├── clock_mux.v            # Glitch-free clock mux (2:1, 4:1)
│   ├── clock_divider.v        # Integer + Fractional divider
│   ├── jtag_tap.v             # IEEE 1149.1 JTAG TAP controller
│   ├── bist_clock_ctrl.v      # BIST clock controller + pattern gen
│   ├── dft_clock_ctrl.v       # DFT clock 통합 제어
│   ├── dsp_core.v             # DSP 코어 (MAC, FIR, CDC FIFO)
│   └── clock_subsystem.v      # Top-level + multi_clock_dsp_top
├── tb/                        # Testbench
│   └── tb_clock_subsystem.v   # 통합 테스트벤치
└── library/                   # Standard cell library
    ├── NangateOpenCellLibrary.lib
    └── NangateOpenCellLibrary.db
```

## 클럭 아키텍처

```
                         CLOCK SUBSYSTEM
  ┌────────────────────────────────────────────────────────────┐
  │                                                            │
  │  ext_clk ──┬──► CLK_MUX_SRC (2:1) ──► sys_clk_src         │
  │  pll_clk ──┘          │                                    │
  │                       ├──► INT_DIV (/2,4,8,16) ─► div_clk │
  │                       └──► FRAC_DIV (Sigma-Delta) ► frac_clk│
  │                                                            │
  │  sys_clk ─────┐                                            │
  │  div_clk ─────┼──► FUNC_MUX (4:1) ──► func_clk            │
  │  frac_clk ────┤                                            │
  │  bypass_clk ──┘                                            │
  │                                                            │
  │  scan_clk ──┐                                              │
  │  tck ───────┼──► DFT_MUX (4:1) ──► dft_clk                │
  │  bist_clk ──┘                                              │
  │                                                            │
  │  func_clk ────┬──► FINAL_MUX (2:1) ──► core_clk           │
  │  dft_clk ─────┘       ▲ test_mode                          │
  │                                                            │
  │  core_clk ──► ICG ──► dsp_gated_clk                       │
  │           ──► ICG ──► periph_gated_clk                    │
  └────────────────────────────────────────────────────────────┘
```

## 구현 현황

| 모듈 | 상태 | 설명 |
|------|------|------|
| clock_gating_cell.v | ✅ 완료 | ICG wrapper (Nangate CLKGATETST_X1) |
| clock_mux.v | ✅ 완료 | Glitch-free 2:1, 4:1 mux |
| clock_divider.v | ✅ 완료 | Integer + Fractional (Sigma-Delta) |
| jtag_tap.v | ✅ 완료 | IEEE 1149.1 TAP (IDCODE+BYPASS) |
| bist_clock_ctrl.v | ✅ 완료 | BIST controller + LFSR pattern gen |
| dft_clock_ctrl.v | ✅ 완료 | DFT 통합 (scan/JTAG/BIST mux) |
| dsp_core.v | ✅ 완료 | MAC, FIR engine, async FIFO |
| clock_subsystem.v | ✅ 완료 | Top-level integration |
| tb_clock_subsystem.v | ✅ 완료 | 종합 테스트벤치 |

## 모듈 상세

### Clock Infrastructure
- **clock_gating_cell**: Latch-based ICG, synthesis시 Nangate CLKGATETST_X1 사용
- **clock_mux**: Negedge sync + handshaking으로 glitch-free 전환
- **clock_divider**: Integer(counter-based), Fractional(Sigma-Delta accumulator)

### DFT Support
- **jtag_tap**: IEEE 1149.1 compliant, 16-state FSM, 4-bit IR
- **bist_clock_ctrl**: State machine + clock generation, LFSR pattern generator
- **dft_clock_ctrl**: 4-mode selection (func/scan/JTAG/BIST)

### DSP Core
- **dsp_mac**: Signed multiply-accumulate, 40-bit accumulator
- **dsp_fir_engine**: 8-tap FIR filter using MAC
- **dsp_data_interface**: Gray-coded async FIFO for clock domain crossing

## 시뮬레이션

```bash
cd /home/jysong/test/PST-temp

# iverilog
iverilog -o sim.vvp rtl/*.v tb/tb_clock_subsystem.v
vvp sim.vvp
gtkwave dump.vcd

# VCS
vcs -full64 rtl/*.v tb/tb_clock_subsystem.v -o simv
./simv
```

### 테스트 항목
1. Clock source selection (ext/pll)
2. Integer divider (/2, /4, /8, /16)
3. Fractional divider (2.5, 3.5 ratio)
4. JTAG IDCODE read (0x4D434453)
5. JTAG BYPASS mode
6. Scan mode activation
7. BIST execution and completion
8. DSP FIR filter operation
9. Clock gating verification

## 사용 라이브러리

- **Nangate Open Cell Library (45nm)**
  - `CLKGATETST_X1`: ICG with scan enable (CK, E, SE, GCK)
  - `CLKGATE_X1`: Basic ICG (CK, E, GCK)

## 합성 (Synthesis)

```tcl
# DC/Genus example
set_db library {./library/NangateOpenCellLibrary.lib}
read_hdl -v2001 rtl/*.v
elaborate multi_clock_dsp_top
# SYNTHESIS 매크로 정의하여 library ICG 사용
set_db hdl_define_macro SYNTHESIS
```

## 요구사항

- Verilog-2001 호환 시뮬레이터 (iverilog, VCS, ModelSim 등)
- (합성용) Nangate Open Cell Library

## 라이선스

Educational/Research purposes
