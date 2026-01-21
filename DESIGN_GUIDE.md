# Complex Clock RTL Design Guide

## 프로젝트 개요
DFT clock, test clock, 다중 clock mux, clock divider를 갖춘 복잡한 클럭 구조의 RTL 설계

## 요구사항 요약
- **언어**: Verilog-2001
- **클럭 도메인**: 6개 (sys_clk, div_clk, frac_clk, tck, scan_clk, bist_clk)
- **Clock Divider**: Integer (/2,4,8,16) + Fractional (1.0~16.0, 8bit)
- **DFT**: Scan + JTAG (IDCODE+BYPASS) + BIST

---

## 디렉토리 구조

```
/home/jysong/test/PST-temp/
├── DESIGN_GUIDE.md            # 이 문서
├── rtl/
│   ├── clock_gating_cell.v    # ICG cell
│   ├── clock_mux.v            # Glitch-free mux (2:1, 4:1)
│   ├── clock_divider.v        # Integer + Fractional divider
│   ├── jtag_tap.v             # JTAG TAP controller
│   ├── bist_clock_ctrl.v      # BIST clock controller
│   ├── dft_clock_ctrl.v       # DFT clock 통합 제어
│   ├── example_counter.v      # 예제 counter
│   └── clock_subsystem.v      # Top-level
└── tb/
    └── tb_clock_subsystem.v   # Testbench
```

---

## 클럭 아키텍처

```
                         CLOCK SUBSYSTEM
  ┌────────────────────────────────────────────────────────────┐
  │                                                            │
  │  ext_clk ──┬──► CLK_MUX_SRC (2:1) ──► sys_clk_src         │
  │  pll_clk ──┘                              │                │
  │                                           ▼                │
  │                    ┌─────────────────────────────────┐     │
  │                    │      CLOCK DIVIDERS             │     │
  │                    │  Integer (/2,4,8,16) ─► div_clk │     │
  │                    │  Fractional (8bit)   ─► frac_clk│     │
  │                    └─────────────────────────────────┘     │
  │                                                            │
  │  scan_clk ──┐                                              │
  │  tck ───────┼──► DFT_MUX (4:1) ──► dft_clk_out            │
  │  bist_clk ──┘                                              │
  │                                                            │
  │  sys_clk_src ──┐                                           │
  │  div_clk ──────┼──► FUNC_MUX (4:1) ──► func_clk           │
  │  frac_clk ─────┤                                           │
  │  bypass_clk ───┘                                           │
  │                                                            │
  │  func_clk ─────┬──► FINAL_MUX (2:1) ──► core_clk          │
  │  dft_clk_out ──┘       ▲ test_mode                         │
  │                                                            │
  │  core_clk ──► ICG ──► gated_clk                           │
  │                                                            │
  └────────────────────────────────────────────────────────────┘
```

---

## 모듈 상세

### 1. clock_gating_cell.v
- Integrated Clock Gating (ICG) cell
- Latch 기반 glitch-free gating
- 포트: clk_in, enable, scan_en, gated_clk

### 2. clock_mux.v
**clk_mux_2to1**: 2:1 glitch-free clock mux
- Double-sync selection signal
- 포트: clk_a, clk_b, sel, rst_n, clk_out

**clk_mux_4to1**: 4:1 glitch-free clock mux
- 2:1 mux 3개로 구성
- 포트: clk[3:0], sel[1:0], rst_n, clk_out

### 3. clock_divider.v
**clk_div_integer**: Programmable integer divider
- 분주비: /2, /4, /8, /16 (div_sel[1:0])
- 50% duty cycle 보장
- 포트: clk_in, rst_n, div_sel[1:0], clk_out

**clk_div_fractional**: Fractional divider
- Sigma-Delta accumulator 방식
- 범위: 1.0 ~ 16.0 (N=4bit, F=4bit)
- 포트: clk_in, rst_n, div_ratio[7:0], clk_out

### 4. jtag_tap.v
- IEEE 1149.1 호환 TAP controller
- State machine: Test-Logic-Reset → Run-Test/Idle → ...
- Instructions: BYPASS (0xF), IDCODE (0x1)
- IR 길이: 4bit
- 포트: tck, tms, tdi, trst_n, tdo, tap_state[3:0]

### 5. bist_clock_ctrl.v
- BIST 모드 클럭 제어
- BIST 시작/정지 제어
- 포트: clk_in, rst_n, bist_en, bist_clk_out, bist_done

### 6. dft_clock_ctrl.v
- DFT 모드별 클럭 선택 통합
- test_mode[1:0]: 00=func, 01=scan, 10=jtag, 11=bist
- 포트: func_clk, scan_clk, tck, bist_clk, test_mode[1:0], dft_clk_out

### 7. example_counter.v
- 각 클럭 도메인 동작 확인용 counter
- 포트: clk, rst_n, count[7:0]

### 8. clock_subsystem.v (Top-level)
- 모든 모듈 통합
- 주요 포트:
  - Input: ext_clk, pll_clk, scan_clk, tck, tms, tdi, trst_n
  - Control: clk_src_sel, div_sel[1:0], frac_ratio[7:0], func_clk_sel[1:0], test_mode[1:0], clk_gate_en
  - Output: core_clk, gated_clk, tdo

---

## 구현 순서

| 순서 | 파일 | 설명 | 상태 |
|------|------|------|------|
| 1 | clock_gating_cell.v | ICG cell | |
| 2 | clock_mux.v | Glitch-free mux | |
| 3 | clock_divider.v | Integer + Fractional | |
| 4 | jtag_tap.v | TAP controller | |
| 5 | bist_clock_ctrl.v | BIST controller | |
| 6 | dft_clock_ctrl.v | DFT 통합 제어 | |
| 7 | example_counter.v | 예제 counter | |
| 8 | clock_subsystem.v | Top-level 통합 | |
| 9 | tb_clock_subsystem.v | Testbench | |

---

## Simulation 방법

```bash
# iverilog 사용
cd /home/jysong/test/PST-temp
iverilog -o sim.vvp rtl/*.v tb/tb_clock_subsystem.v
vvp sim.vvp
gtkwave dump.vcd

# VCS 사용 (있는 경우)
vcs -full64 -sverilog rtl/*.v tb/tb_clock_subsystem.v -o simv
./simv
```

---

## 핵심 설계 포인트

### Glitch-Free Clock Mux 원리
1. sel 신호를 각 클럭 도메인에서 double-sync
2. 현재 클럭이 low일 때만 전환 허용
3. clk_out = (clk_a & sel_a_en) | (clk_b & sel_b_en)

### Fractional Divider 원리 (Sigma-Delta)
- div_ratio = {N[3:0], F[3:0]}
- accumulator에 F를 매 사이클 누적
- overflow 시 N+1로 분주, 아니면 N으로 분주
- 예: 3.5 분주 = 3,4,3,4... 패턴 반복

### DFT Mode Selection
```
test_mode[1:0]:
  00 - Functional mode (func_clk 사용)
  01 - Scan mode (scan_clk 사용)
  10 - JTAG mode (tck 사용)
  11 - BIST mode (bist_clk 사용)
```

---

## 주의사항
1. 모든 clock mux는 glitch-free 설계 필수
2. Reset은 비동기 assert, 동기 deassert
3. Fractional divider는 jitter 발생 (의도된 동작)
4. JTAG TAP는 tck falling edge에서 TDO 출력
