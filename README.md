# MIPS Pipeline with Two-Level Adaptive Branch Predictor

5-stage MIPS pipeline implemented in SystemVerilog with full hazard support and a two-level adaptive (GAg) branch predictor. Simulated using Icarus Verilog and visualised with GTKWave.

---

## Project structure

```
.
├── rtl/
│   ├── mips_pipeline.sv      # Top-level — all 5 stages wired together
│   ├── branch_predictor.sv   # Two-level adaptive predictor (GAg)
│   ├── alu.sv                # Arithmetic logic unit
│   ├── alu_control.sv        # ALU control decoder
│   ├── control.sv            # Main control unit (opcode decoder)
│   ├── regfile.sv            # 32×32 register file
│   ├── hazard_unit.sv        # Load-use stall detection
│   ├── forwarding_unit.sv    # EX-EX and MEM-WB data forwarding
│   └── memory.sv             # Instruction and data memory
├── tb/
│   └── tb_mips_pipeline.sv   # Testbench with GTKWave dump
├── sim/                      # Generated simulation outputs (gitignored)
├── docs/
│   ├── gtkwave_signals.gtkw  # Pre-configured GTKWave signal layout
│   └── VIVA_CHEATSHEET.md    # Viva preparation notes
├── Makefile
└── README.md
```

---

## Supported instructions

| Type | Instructions |
|------|-------------|
| R-type | `add`, `sub`, `and`, `or`, `slt`, `nor`, `xor` |
| I-type | `addi`, `ori`, `slti`, `lw`, `sw`, `beq`, `bne` |
| J-type | `j`, `jal` |

---

## Pipeline features

### 5-stage pipeline
- IF → ID → EX → MEM → WB
- Pipeline registers: IF/ID, ID/EX, EX/MEM, MEM/WB

### Hazard handling
- **Data hazards**: resolved via forwarding unit (EX-EX and MEM-WB paths)
- **Load-use hazard**: detected by hazard unit, resolved with 1-cycle stall
- **Control hazards**: resolved by flushing IF/ID, ID/EX, and EX/MEM on branch taken (3-cycle penalty)

### Two-level adaptive branch predictor (GAg)
- **GHR**: 4-bit global history register tracking last 4 branch outcomes
- **PHT**: 16-entry pattern history table of 2-bit saturating counters
- Prediction happens in IF stage (combinational, zero latency)
- GHR and PHT updated in MEM stage after branch resolves

---

## How to run

### Requirements
```bash
# Ubuntu / Debian
sudo apt install iverilog gtkwave

# macOS (Homebrew)
brew install icarus-verilog gtkwave
```

### Compile and simulate
```bash
make
```

This compiles all RTL, runs the simulation, and prints test results.

### Open waveform
```bash
make wave
```

Opens GTKWave with all key signals pre-loaded from `docs/gtkwave_signals.gtkw`.

### Manual compile (if make is unavailable)
```bash
mkdir -p sim
iverilog -g2012 -o sim/mips_sim \
  rtl/alu.sv rtl/alu_control.sv rtl/regfile.sv rtl/control.sv \
  rtl/hazard_unit.sv rtl/forwarding_unit.sv rtl/branch_predictor.sv \
  rtl/memory.sv rtl/mips_pipeline.sv tb/tb_mips_pipeline.sv

vvp sim/mips_sim
gtkwave sim/mips_wave.vcd docs/gtkwave_signals.gtkw
```

---

## Test program

The testbench loads a MIPS program that exercises every feature:

| Instruction | Tests |
|-------------|-------|
| `addi $t0, $zero, 5` | Basic immediate |
| `addi $t1, $zero, 3` | Basic immediate |
| `add $t2, $t0, $t1` | R-type + EX-EX forwarding |
| `sw $t2, 0($zero)` | Store word |
| `lw $t3, 0($zero)` | Load word |
| `add $t4, $t3, $t0` | Load-use hazard → stall |
| `beq $t0, $t5, +2` | Branch taken → flush + predictor update |
| `bne $t0, $t1, +1` | Branch taken → flush + predictor update |

### Expected results
```
$t0 = 5    $t1 = 3    $t2 = 8    $t3 = 8
$t4 = 13   $t6 = 0 (NOT 99 — branch correctly flushed)
$s0 = 1    $s2 = 42
*** ALL CHECKS PASSED ***
```

---

## Design decisions

### Why GAg over bimodal (1-level)?
A bimodal predictor indexes the PHT by PC — each branch has its own counter. It cannot detect correlations between branches. GAg uses a global history register to index the PHT, so the predictor learns what the program tends to do after any given sequence of outcomes. This handles loops and correlated branches significantly better.

### Why 4-bit GHR?
- 4-bit GHR → 16 PHT entries — captures medium-length patterns with minimal hardware
- 2-bit would miss longer repeated patterns
- 8-bit (256 entries) is overkill for a course project and stays cold on short programs

### Why resolve branches in MEM stage?
Resolving in EX would require less flushing (2 cycles vs 3) but needs a dedicated comparator in EX and more complex bypass logic. MEM-stage resolution reuses the ALU result cleanly.

### Misprediction penalty
3 cycles — because the branch is in MEM (4th stage) when resolved, so 3 instructions behind it have been fetched incorrectly and must be flushed.

---

## Waveform guide (GTKWave)

Key signals to watch:

| Signal | What to look for |
|--------|-----------------|
| `pc` | Jumps to branch target when `branch_taken=1` |
| `stall` | Goes high for 1 cycle on load-use hazard |
| `branch_taken` | Goes high when beq/bne resolves as taken |
| `flush_if_id/id_ex/ex_mem` | All go high same cycle as `branch_taken` |
| `forward_a/b` | `2'b10` = EX-EX forward, `2'b01` = MEM-WB forward |
| `bp.ghr` | Shifts after every branch resolution |
| `prediction` | Reads PHT[GHR] MSB combinationally in IF |

---

## Module hierarchy

```
tb_mips_pipeline
└── mips_pipeline (top)
    ├── instr_mem
    ├── branch_predictor
    ├── control
    ├── regfile
    ├── hazard_unit
    ├── forwarding_unit
    ├── alu_control
    ├── alu
    └── data_mem
```
