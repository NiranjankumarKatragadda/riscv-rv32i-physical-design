# RISC-V Physical Design Project
## ChipXpert PD Student Guide — Complete Open-Source Flow

---

## Project Structure

```
riscv_pd_project/
├── rtl/
│   ├── riscv_pipeline.v      ← 5-stage pipelined RV32I core (TOP)
│   ├── alu.v                 ← ALU: ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT
│   ├── control_hazard_fwd.v  ← Control unit + Hazard detection + Forwarding
│   ├── mem_tb.v              ← Instruction/Data memory + Testbench
│   └── program.hex           ← Test program (binary)
├── constraints/
│   └── constraints.sdc       ← SDC timing constraints (100MHz)
├── openlane/
│   └── config.json           ← OpenLane configuration
├── scripts/
│   ├── run_pd_flow.sh        ← Full automated PD flow script
│   ├── sta_analysis.tcl      ← STA analysis + timing fix guide
│   └── floorplan_power.tcl   ← Floorplan + PDN scripts
└── README.md
```

---

## 5-Stage Pipeline Architecture

```
┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
│  IF  │ → │  ID  │ → │  EX  │ → │ MEM  │ → │  WB  │
│Fetch │   │Decode│   │  ALU │   │D-Mem │   │RegWr │
└──────┘   └──────┘   └──────┘   └──────┘   └──────┘
              ↑            ↑
          Hazard Det    Forwarding
          (stall)       (MEM→EX, WB→EX)
```

### Key Features
- RV32I ISA (Base Integer)
- 5-stage pipeline: IF, ID, EX, MEM, WB
- Data forwarding (eliminates RAW hazards)
- Load-use hazard detection (1-cycle stall)
- Branch resolution in EX stage (2-cycle penalty)
- 32 x 32-bit register file (x0 hardwired to 0)

---

## Tool Stack (Open-Source)

| Stage            | Tool          | Version    |
|-----------------|---------------|------------|
| Simulation       | Icarus Verilog| 11+        |
| Waveform         | GTKWave       | 3.3+       |
| Synthesis        | Yosys         | 0.20+      |
| P&R              | OpenROAD      | 2.0+       |
| Full Flow        | OpenLane      | 2.0+       |
| PDK              | Sky130        | 1.0        |
| DRC/LVS          | Magic/Netgen  | 8.3+       |

---

## Quick Start

### Step 1: Simulate RTL
```bash
# Install Icarus Verilog
sudo apt install iverilog gtkwave

# Compile
iverilog -o sim.out rtl/riscv_pipeline.v rtl/alu.v \
         rtl/control_hazard_fwd.v rtl/mem_tb.v

# Run
vvp sim.out

# View waveforms
gtkwave riscv_pipeline.vcd
```

### Step 2: Install OpenLane
```bash
git clone https://github.com/The-OpenROAD-Project/OpenLane
cd OpenLane
make        # pulls Docker image + PDK
make test   # run SPM test design
```

### Step 3: Copy Design
```bash
cp -r riscv_pd OpenLane/designs/riscv_pipeline
```

### Step 4: Run Full Flow
```bash
cd OpenLane
./flow.tcl -design riscv_pipeline
```

### Step 5: View Results
```bash
# Open final GDS in Magic
magic -T sky130A designs/riscv_pipeline/runs/latest/results/final/riscv_pipeline.gds
```

---

## Key Design Parameters

| Parameter         | Value         |
|------------------|---------------|
| ISA               | RV32I         |
| Pipeline Stages   | 5             |
| Clock Frequency   | 100 MHz       |
| Target PDK        | Sky130 (130nm)|
| Core Utilization  | 65%           |
| Metal Layers      | 5             |
| Std Cell Library  | sky130_fd_sc_hd|

---

## PD Flow Stages & Expected Results

| Stage        | Tool        | Key Metric          | Target     |
|-------------|-------------|---------------------|------------|
| Synthesis    | Yosys       | Cell count          | ~5K gates  |
| Floorplan    | OpenROAD    | Core utilization    | 65%        |
| Placement    | OpenROAD    | Congestion          | < 0.8      |
| CTS          | TritonCTS   | Clock skew          | < 200 ps   |
| Routing      | TritonRoute | DRC violations      | 0          |
| STA          | OpenSTA     | WNS (setup)         | > 0 (MET)  |
| STA          | OpenSTA     | WNS (hold)          | > 0 (MET)  |
| LVS          | Netgen      | Mismatches          | 0          |

---

## Common Issues & Fixes

### Synthesis
| Issue | Fix |
|-------|-----|
| Undefined module | Check all .v files are included |
| Latch inferred | Add default in case statements |
| High cell count | Use SYNTH_STRATEGY "AREA 0" |

### Floorplan
| Issue | Fix |
|-------|-----|
| High congestion | Reduce FP_CORE_UTIL to 55% |
| IR drop fail | Reduce PDN pitch |
| Macro overlap | Increase macro halo |

### Timing
| Issue | Fix |
|-------|-----|
| Setup violation | Increase clock period or insert pipeline stage |
| Hold violation | Insert delay buffers |
| Clock skew high | Adjust CTS buffer list |

### Routing
| Issue | Fix |
|-------|-----|
| DRC violations | Run DRC-guided repair |
| Antenna violations | Use diode insertion (strategy 4) |
| Routing congestion | Reduce placement density |

---

## Timing Report Interpretation

```
Startpoint: ID_EX_rs1_data_reg[0]/CLK
Endpoint:   EX_MEM_alu_result_reg[0]/D
Path Type:  max (setup check)

Point                              Delay    Arrival
----------------------------------------   -------
clock clk (rise edge)              0.000    0.000
ID_EX_rs1_data_reg[0]/CLK         0.200    0.200  ← clock insertion
ID_EX_rs1_data_reg[0]/Q           0.350    0.550  ← FF output
u_alu/a[0]  (net)                  0.120    0.670  ← wire delay
u_alu/U15/A                        0.000    0.670
u_alu/U15/Y                        0.280    0.950  ← gate delay
EX_MEM_alu_result_reg[0]/D        0.050    1.000  ← wire to FF input

data arrival time                           1.000

clock clk (rise edge)             10.000   10.000
clock uncertainty (setup)         -0.200    9.800
EX_MEM_alu_result_reg[0]/CLK      0.200   10.000
library setup time                -0.180    9.820
data required time                          9.820

slack (MET)  =  9.820 - 1.000  =  8.820 ← POSITIVE = PASS ✅
```

---

## Resources

- OpenLane Docs: https://openlane.readthedocs.io
- OpenROAD: https://theopenroadproject.org
- Sky130 PDK: https://skywater-pdk.readthedocs.io
- RISC-V Spec: https://riscv.org/specifications
- Zero to ASIC: https://zerotoasiccourse.com
- Efabless: https://efabless.com

---
*ChipXpert RISC-V PD Project — Open Source Flow*

## 🛡️ Pre-Shuttle Physical Verification Sign-Off (ChipFoundry / chipIgnite)
| Check | Status | Engine / Standard |
| :--- | :---: | :--- |
| **Top Cell & Boundary** | **PASS** | `cf-precheck` v1.3.7 |
| **GPIO Configuration** | **PASS** | Power-On Reset Vector Validation |
| **Wrapper XOR** | **PASS** | KLayout Boundary Mask XOR |
| **FEOL & BEOL DRC** | **PASS** | KLayout (SkyWater 130A Ruleset) |
| **Offgrid & Metal Density** | **PASS** | KLayout DRC Engine |
| **Pin Labels & ZeroArea** | **PASS** | Geometry Integrity Validator |
| **Transistor-Level LVS** | **PASS** | Netgen & Magic SPICE Extraction |
| **OEB Logic Solver** | **PASS** | CVC (Circuit Validity Check) |
