# ============================================================
# floorplan_power.tcl — Floorplan + Power Planning Guide
# Tool: OpenROAD (inside OpenLane)
# ============================================================

# -------------------------------------------------------
# 1. FLOORPLAN — Initialize
# -------------------------------------------------------
# Core utilization: 65% (35% routing margin)
# Aspect ratio: 1:1 (square)
initialize_floorplan \
    -utilization 65 \
    -aspect_ratio 1.0 \
    -core_space 10 \
    -site unithd

# Alternatively define by exact dimensions:
# initialize_floorplan \
#     -die_area "0 0 500 500" \
#     -core_area "10 10 490 490" \
#     -site unithd


# -------------------------------------------------------
# 2. IO PIN PLACEMENT
# -------------------------------------------------------
place_pins \
    -hor_layers metal3 \
    -ver_layers metal2 \
    -random


# -------------------------------------------------------
# 3. MACRO PLACEMENT (if any SRAMs)
# -------------------------------------------------------
# Place SRAM macros manually with proper orientation
# place_cell \
#     -cell sram_256x32 \
#     -inst u_imem \
#     -origin {50 50} \
#     -orient R0 \
#     -status FIRM


# -------------------------------------------------------
# 4. POWER PLANNING — PDN (Power Distribution Network)
# -------------------------------------------------------

# Create power rings around core
add_pdn_ring \
    -grid pdn_grid \
    -layers {metal5 metal4} \
    -widths {3.1 3.1} \
    -spacings {1.7 1.7} \
    -core_offset {4.5 4.5}

# Add power stripes across core
add_pdn_stripe \
    -grid pdn_grid \
    -layer metal4 \
    -width 1.6 \
    -pitch 153.6 \
    -offset 2.0 \
    -followpins

add_pdn_stripe \
    -grid pdn_grid \
    -layer metal5 \
    -width 1.6 \
    -pitch 153.18 \
    -offset 2.0

# Connect standard cell rails (metal1)
add_pdn_connect \
    -grid pdn_grid \
    -layers {metal1 metal4}

add_pdn_connect \
    -grid pdn_grid \
    -layers {metal4 metal5}

# Build the PDN
pdngen


# -------------------------------------------------------
# 5. VERIFY PDN (IR Drop Analysis)
# -------------------------------------------------------
# analyze_power_grid -net VDD
# analyze_power_grid -net VSS


# -------------------------------------------------------
# 6. REPORT FLOORPLAN
# -------------------------------------------------------
report_design_area
# Expected output:
# Design area: 125000 um^2
# Core area: 192300 um^2
# Utilization: 65.0%


# ============================================================
# FLOORPLAN BEST PRACTICES FOR RISC-V
# ============================================================
#
#  ┌─────────────────────────────────────┐
#  │  Die Area                           │
#  │  ┌─────────────────────────────┐   │
#  │  │  Power Ring (M5/M4)         │   │
#  │  │  ┌─────────────────────┐   │   │
#  │  │  │    Core Area        │   │   │
#  │  │  │                     │   │   │
#  │  │  │  [SRAM Macro]       │   │   │
#  │  │  │  ┌──────────┐      │   │   │
#  │  │  │  │ imem/    │      │   │   │
#  │  │  │  │ dmem     │      │   │   │
#  │  │  │  └──────────┘      │   │   │
#  │  │  │                     │   │   │
#  │  │  │  [Std Cells Area]   │   │   │
#  │  │  │  ALU, RegFile,      │   │   │
#  │  │  │  Pipeline Regs      │   │   │
#  │  │  └─────────────────────┘   │   │
#  │  └─────────────────────────────┘   │
#  └─────────────────────────────────────┘
#
# Key Rules:
# 1. Place macros (SRAMs) at corners/edges
# 2. Keep macro halos (5um minimum)
# 3. Utilization 60-70% (leave routing margin)
# 4. PDN pitch must cover all cells (<IR drop limit)
# 5. Clock ports near center for CTS balance
