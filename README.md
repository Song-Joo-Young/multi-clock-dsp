# Multi-Clock DSP

복잡한 클럭 구조를 가진 DSP(Digital Signal Processing) RTL 설계 프로젝트

## 프로젝트 개요

다중 클럭 도메인, DFT(Design for Test) 지원, Clock Gating을 포함한 신호 처리 유닛 설계

### 주요 특징
- **다중 클럭 도메인**: 6개 독립 클럭 도메인
- **Clock Divider**: Integer(/2,4,8,16) + Fractional(1.0~16.0)
- **DFT 지원**: Scan, JTAG (IDCODE+BYPASS), BIST
- **Library ICG**: Nangate Open Cell Library 사용
- **Glitch-Free Mux**: 안전한 클럭 전환

## 디렉토리 구조

```
multi-clock-dsp/
├── README.md              # 이 문서
├── DESIGN_GUIDE.md        # 상세 설계 가이드
├── rtl/                   # RTL 소스
│   ├── clock_gating_cell.v    # [완료] ICG cell wrapper
│   ├── clock_mux.v            # [완료] Glitch-free clock mux
│   ├── clock_divider.v        # [ ] Integer + Fractional divider
│   ├── jtag_tap.v             # [ ] JTAG TAP controller
│   ├── bist_clock_ctrl.v      # [ ] BIST clock controller
│   ├── dft_clock_ctrl.v       # [ ] DFT clock 통합 제어
│   ├── dsp_core.v             # [ ] DSP 코어 모듈
│   └── clock_subsystem.v      # [ ] Top-level
├── tb/                    # Testbench
│   └── tb_clock_subsystem.v   # [ ] 통합 테스트벤치
└── library/               # Standard cell library
    ├── NangateOpenCellLibrary.lib
    └── NangateOpenCellLibrary.db
```

## 클럭 아키텍처

```
ext_clk ──┬──► SRC_MUX ──► DIVIDERS ──┬─► FUNC_MUX ──┬──► FINAL_MUX ──► core_clk
pll_clk ──┘                           │              │        ▲
                                      │              │     test_mode
scan_clk ──┐                          │              │
tck ───────┼──► DFT_MUX ──────────────┼──────────────┘
bist_clk ──┘                          │
                                      └──► ICG ──► gated_clk
```

## 구현 현황

| 모듈 | 상태 | 설명 |
|------|------|------|
| clock_gating_cell.v | ✅ 완료 | ICG wrapper (Nangate CLKGATETST_X1) |
| clock_mux.v | ✅ 완료 | Glitch-free 2:1, 4:1 mux |
| clock_divider.v | 🔄 진행중 | Integer + Fractional |
| jtag_tap.v | ⏳ 대기 | IEEE 1149.1 TAP |
| bist_clock_ctrl.v | ⏳ 대기 | BIST 클럭 제어 |
| dft_clock_ctrl.v | ⏳ 대기 | DFT 통합 |
| dsp_core.v | ⏳ 대기 | DSP 코어 |
| clock_subsystem.v | ⏳ 대기 | Top-level |
| tb_clock_subsystem.v | ⏳ 대기 | Testbench |

## 사용 라이브러리

- **Nangate Open Cell Library (45nm)**
  - `CLKGATETST_X1`: ICG with scan enable
  - `CLKGATE_X1`: Basic ICG

## 시뮬레이션

```bash
# iverilog
iverilog -o sim.vvp rtl/*.v tb/tb_clock_subsystem.v
vvp sim.vvp
gtkwave dump.vcd

# VCS
vcs -full64 rtl/*.v tb/tb_clock_subsystem.v -o simv
./simv
```

## 요구사항

- Verilog-2001 호환 시뮬레이터
- (선택) Nangate Open Cell Library for synthesis

## 라이선스

Educational/Research purposes
