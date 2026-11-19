# 5-Stage RV32I Core: RTL-to-GDSII on SkyWater 130nm

Pipelined RV32I core taken from RTL through physical design and STA timing closure on Sky130, with pre-shuttle sign-off (`cf-precheck` v1.3.7) passing for ChipFoundry / chipIgnite.

## Pre-shuttle sign-off

| Check | Status | Engine / standard |
| --- | --- | --- |
| Top cell and boundary | PASS | `cf-precheck` v1.3.7 |
| GPIO configuration | PASS | Power-on reset vector validation |
| Wrapper XOR | PASS | KLayout boundary mask XOR |
| FEOL and BEOL DRC | PASS | KLayout (SkyWater 130A ruleset) |
| Offgrid and metal density | PASS | KLayout DRC engine |
| Pin labels and zero-area | PASS | Geometry integrity validator |
| Transistor-level LVS | PASS | Netgen and Magic SPICE extraction |
| OEB logic solver | PASS | CVC (Circuit Validity Check) |

Full reports: [`precheck_results/10_NOV_2026___17_22_34`](precheck_results/10_NOV_2026___17_22_34)

## Design summary

| Parameter | Value |
| --- | --- |
| ISA | RV32I (base integer) |
| Pipeline | 5 stages: IF, ID, EX, MEM, WB |
| Hazards | Forwarding (MEM to EX, WB to EX); 1-cycle load-use stall |
| Branches | Resolved in EX, 2-cycle penalty |
| Register file | 32 x 32-bit, x0 hardwired to 0 |
| Clock target | 100 MHz (`constraints.sdc`) |
| PDK / cell library | Sky130 / `sky130_fd_sc_hd` (`tt_025C_1v80`) |
| Core utilization (config) | 65% |

## Quick start

Simulate the RTL:

    iverilog -o sim.out riscv_pipeline.v alu.v control_hazard_fwd.v mem_tb.v
    vvp sim.out
    gtkwave riscv_pipeline.vcd

Run the physical design flow (`Yosys` -> `OpenROAD` -> `OpenSTA` -> `Magic` / `Netgen`):

    PDK_ROOT=/usr/share/pdk bash run_pd_flow.sh

## Verification

`mem_tb.v` runs a directed RV32I test program verifying `addi`/`add` EX-EX forwarding, `sw`/`lw` 1-cycle load-use hazard stalling with MEM-EX forwarding, and `beq` branch-taken pipeline flushing. RTL simulation was verified with Icarus Verilog and GTKWave; post-PnR physical sign-off was verified via `cf-precheck` v1.3.7 (13/13 PASS).

## Need something similar?

NK Verif Labs offers verification and RTL-to-GDSII services. Email **nkveriflabs@gmail.com**.

## License

MIT. See [LICENSE](LICENSE).
