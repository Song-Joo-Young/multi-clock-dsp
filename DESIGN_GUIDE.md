# Multi-Clock DSP Design Guide

## 프로젝트 개요
DFT clock, test clock, 다중 clock mux, clock divider를 갖춘 복잡한 클럭 구조의 DSP RTL 설계

## 구현 완료 상태: ✅ ALL COMPLETE

---

## 요구사항 요약
- **언어**: Verilog-2001
- **클럭 도메인**: 6개 (sys_clk, div_clk, frac_clk, tck, scan_clk, bist_clk)
- **Clock Divider**: Integer (/2,4,8,16) + Fractional (1.0~16.0, Sigma-Delta)
- **DFT**: Scan + JTAG (IDCODE+BYPASS) + BIST
- **Library ICG**: Nangate CLKGATETST_X1

---

## 디렉토리 구조

```
/home/jysong/test/PST-temp/
├── README.md                  # GitHub README
├── DESIGN_GUIDE.md            # 이 문서 (세션 복구용)
├── .gitignore                 # Git ignore rules
├── rtl/
│   ├── clock_gating_cell.v    # ✅ ICG cell (Nangate wrapper)
│   ├── clock_mux.v            # ✅ Glitch-free mux (2:1, 4:1)
│   ├── clock_divider.v        # ✅ Integer + Fractional divider
│   ├── jtag_tap.v             # ✅ IEEE 1149.1 JTAG TAP
│   ├── bist_clock_ctrl.v      # ✅ BIST clock controller + LFSR
│   ├── dft_clock_ctrl.v       # ✅ DFT clock 통합 제어
│   ├── dsp_core.v             # ✅ MAC, FIR, async FIFO
│   └── clock_subsystem.v      # ✅ Top-level + multi_clock_dsp_top
├── tb/
│   └── tb_clock_subsystem.v   # ✅ 종합 테스트벤치
└── library/
    ├── NangateOpenCellLibrary.lib
    └── NangateOpenCellLibrary.db
```

---

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
  │  sys_clk_src ─┐                                            │
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
  │  core_clk ──► ICG (CLKGATETST_X1) ──► dsp_gated_clk       │
  │           ──► ICG (CLKGATETST_X1) ──► periph_gated_clk    │
  └────────────────────────────────────────────────────────────┘
```

---

## 모듈 상세

### 1. clock_gating_cell.v
**모듈들:**
- `clock_gating_cell`: ICG with scan enable
- `clock_gating_cell_no_test`: Basic ICG

**Nangate Library Cell:**
- Synthesis: `CLKGATETST_X1 (CK, E, SE, GCK)`
- Simulation: Behavioral latch model

**포트:**
| 포트 | 방향 | 설명 |
|------|------|------|
| clk_in | input | 입력 클럭 |
| enable | input | 게이트 활성화 |
| scan_enable | input | 스캔 모드 (게이팅 바이패스) |
| clk_out | output | 게이트된 클럭 |

---

### 2. clock_mux.v
**모듈들:**
- `clk_mux_2to1`: Glitch-free 2:1 mux (negedge sync + handshaking)
- `clk_mux_4to1`: 4:1 mux (2:1 트리 구조)
- `clk_mux_2to1_simple`: Simple mux (DFT bypass용)

**Glitch-Free 원리:**
```
sel ──► [sync_a: 2-stage negedge sync] ──► en_a
    ──► [sync_b: 2-stage negedge sync] ──► en_b

clk_out = (clk_a & en_a) | (clk_b & en_b)
Handshaking: sel_a_async = ~sel & ~sync_b[1]
```

---

### 3. clock_divider.v
**모듈들:**
- `clk_div_integer`: /2, /4, /8, /16 (50% duty cycle)
- `clk_div_fractional`: Sigma-Delta 방식 (8bit ratio)
- `clk_div_bypass`: Divider + bypass mux

**Fractional Divider 원리:**
```
div_ratio[7:0] = {N[3:0], F[3:0]}
Actual ratio = N + F/16

매 사이클:
  acc_next = accumulator + F
  if (overflow) → divide by N+1
  else          → divide by N

예: 3.5 분주 = 3,4,3,4... 패턴
```

---

### 4. jtag_tap.v
**IEEE 1149.1 호환 TAP Controller**

**State Machine (16 states):**
```
Test-Logic-Reset ◄──────────────────────────┐
      │ TMS=0                               │ TMS=1 (5+ cycles)
      ▼                                     │
Run-Test/Idle ──► Select-DR ──► Select-IR ──┘
                      │              │
                      ▼              ▼
              Capture-DR      Capture-IR
                      │              │
                      ▼              ▼
                Shift-DR        Shift-IR
                      │              │
                      ▼              ▼
                Exit1-DR        Exit1-IR
                      │              │
                 ┌────┴────┐    ┌────┴────┐
                 ▼         ▼    ▼         ▼
            Pause-DR  Update-DR Pause-IR Update-IR
```

**Instructions:**
| Opcode | Name | 설명 |
|--------|------|------|
| 0x1 | IDCODE | 32-bit device ID 읽기 |
| 0xF | BYPASS | 1-bit bypass register |

**IDCODE 기본값:** `0x4D434453` ("MCDS")

---

### 5. bist_clock_ctrl.v
**모듈들:**
- `bist_clock_ctrl`: BIST state machine + clock generation
- `bist_pattern_gen`: LFSR pseudo-random pattern generator

**BIST State Machine:**
```
IDLE ──► INIT ──► RUN ──► COMPLETE
                   ▲  │
                   └──┘ (PAUSE)
```

**LFSR Polynomial (16-bit):** x^16 + x^14 + x^13 + x^11 + 1

---

### 6. dft_clock_ctrl.v
**모듈들:**
- `dft_clock_ctrl`: Basic 4-mode mux
- `dft_clock_ctrl_glitchfree`: Glitch-free version
- `scan_clock_gate`: Scan-aware ICG wrapper

**Test Mode Selection:**
| test_mode[1:0] | 모드 | 클럭 소스 |
|----------------|------|-----------|
| 00 | Functional | func_clk |
| 01 | Scan | scan_clk |
| 10 | JTAG | tck |
| 11 | BIST | bist_clk |

---

### 7. dsp_core.v
**모듈들:**
- `dsp_mac`: Multiply-Accumulate (16x16→40bit)
- `dsp_fir_engine`: 8-tap FIR filter
- `dsp_data_interface`: Async FIFO for CDC

**MAC 연산:**
```
acc_out = acc_out + (data_a * data_b)
- Signed multiply: 16-bit × 16-bit → 32-bit
- Sign-extend to 40-bit
- Accumulate
```

**Async FIFO (CDC):**
- Gray-coded write/read pointers
- 2-stage synchronizers
- div_clk (ADC) → dsp_gated_clk (DSP)

---

### 8. clock_subsystem.v
**모듈들:**
- `clock_subsystem`: 클럭 인프라 통합
- `multi_clock_dsp_top`: 전체 시스템 통합

**clock_subsystem 포트:**
| 카테고리 | 포트 |
|----------|------|
| Clocks | ext_clk, pll_clk, scan_clk, tck |
| Reset | rst_n, por_n, trst_n |
| Control | clk_src_sel, int_div_sel, frac_div_ratio, func_clk_sel, test_mode |
| JTAG | tms, tdi, tdo, tdo_en |
| BIST | bist_enable, bist_start, bist_done |
| Gating | dsp_clk_en, periph_clk_en |
| Outputs | sys_clk, div_clk, frac_clk, core_clk, dsp_gated_clk, periph_gated_clk |

---

## 테스트벤치 (tb_clock_subsystem.v)

### 테스트 항목
1. **Clock Source Selection** - ext_clk/pll_clk 전환
2. **Integer Divider** - /2, /4, /8, /16 확인
3. **Fractional Divider** - 2.5, 3.5 비율 확인
4. **JTAG IDCODE** - 0x4D434453 읽기 검증
5. **JTAG BYPASS** - BYPASS instruction 테스트
6. **Scan Mode** - test_mode=01 활성화 확인
7. **BIST Mode** - BIST 시작 및 완료 확인
8. **DSP FIR** - 계수 로드 및 필터 동작
9. **Clock Gating** - ICG 동작 확인

### 실행 방법
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

---

## 핵심 설계 포인트

### 1. Glitch-Free Clock Mux
- Negedge sync: 클럭 low 구간에서 전환
- Handshaking: 상대 클럭 비활성화 확인 후 전환
- No overlap/underlap 보장

### 2. Library ICG Instantiation
```verilog
`ifdef SYNTHESIS
    CLKGATETST_X1 u_icg (
        .CK(clk_in), .E(enable), .SE(scan_enable), .GCK(clk_out)
    );
`else
    // Behavioral model
`endif
```

### 3. Clock Domain Crossing
- Gray-coded pointers in async FIFO
- 2-stage synchronizers
- Full/empty 판단 시 동기화된 포인터 사용

### 4. DFT Considerations
- ICG scan_enable으로 테스트 시 클럭 활성화
- JTAG TAP tck falling edge에서 TDO 출력
- BIST clock division for controllability

---

## Git Commit History
1. Initial commit: project structure and design guide
2. Add ICG cell wrapper with Nangate library instantiation
3. Add glitch-free clock mux modules
4. Add clock divider modules and README
5. Add IEEE 1149.1 JTAG TAP controller
6. Add BIST clock controller and pattern generator
7. Add DFT clock controller modules
8. Add DSP core modules
9. Add top-level clock subsystem and DSP integration
10. Add comprehensive testbench for clock subsystem

---

## 세션 복구 시 참고사항
1. 모든 RTL 모듈 구현 완료
2. 테스트벤치 구현 완료
3. Nangate CLKGATETST_X1 ICG 사용
4. 시뮬레이션: iverilog 또는 VCS 사용
5. 합성 시 `SYNTHESIS` 매크로 정의 필요
