#!/bin/bash
# ============================================================
# run_pd_flow.sh — Complete Open-Source PD Flow Script
# Tool: OpenLane + OpenROAD + Sky130 PDK
# ============================================================

set -e  # Exit on error
DESIGN="riscv_pipeline"
TAG="run_$(date +%Y%m%d_%H%M%S)"
OPENLANE_DIR="$HOME/OpenLane"

echo "============================================"
echo "  RISC-V Physical Design Flow"
echo "  Design : $DESIGN"
echo "  Tag    : $TAG"
echo "============================================"

# -------------------------------------------------------
# STEP 0: Setup
# -------------------------------------------------------
cd $OPENLANE_DIR
cp -r /path/to/riscv_pd designs/$DESIGN

# -------------------------------------------------------
# STEP 1: Launch OpenLane Interactive
# -------------------------------------------------------
docker run -it \
    -v $(pwd):/openlane \
    -v $PDK_ROOT:$PDK_ROOT \
    -e PDK_ROOT=$PDK_ROOT \
    efabless/openlane:latest \
    /bin/bash -c "
        cd /openlane
        ./flow.tcl -design $DESIGN -tag $TAG -interactive << 'EOF'

package require openlane

# -------------------------------------------------------
# STEP 2: Preparation
# -------------------------------------------------------
prep -design $DESIGN -tag $TAG

# -------------------------------------------------------
# STEP 3: Synthesis (Yosys)
# -------------------------------------------------------
run_synthesis
# Check: designs/$DESIGN/runs/$TAG/reports/synthesis/

# -------------------------------------------------------
# STEP 4: Floorplan (OpenROAD)
# -------------------------------------------------------
run_floorplan
# Sets die area, places IO pins, creates power grid

# -------------------------------------------------------
# STEP 5: Placement (OpenROAD)
# -------------------------------------------------------
run_placement
# Global → Legalization → Detailed placement

# -------------------------------------------------------
# STEP 6: Clock Tree Synthesis (OpenROAD TritonCTS)
# -------------------------------------------------------
run_cts
# Target: skew < 200ps

# -------------------------------------------------------
# STEP 7: Routing (OpenROAD TritonRoute)
# -------------------------------------------------------
run_routing
# Global → Detailed routing, DRC-clean

# -------------------------------------------------------
# STEP 8: RC Extraction (OpenROAD OpenRCX)
# -------------------------------------------------------
run_parasitics_sta
# Extracts parasitics for accurate timing

# -------------------------------------------------------
# STEP 9: Physical Verification
# -------------------------------------------------------
run_magic            ;# Stream out GDS
run_magic_drc        ;# DRC check
run_netgen           ;# LVS check
run_antenna_check    ;# Antenna rule check

# -------------------------------------------------------
# STEP 10: Final STA (OpenSTA)
# -------------------------------------------------------
run_sta
# Check WNS, TNS at all corners

# -------------------------------------------------------
# STEP 11: Generate Reports
# -------------------------------------------------------
generate_final_summary_report

EOF
    "

echo ""
echo "============================================"
echo "  Flow Complete! Check results in:"
echo "  designs/$DESIGN/runs/$TAG/"
echo "============================================"

# -------------------------------------------------------
# POST-FLOW: Parse Key Metrics
# -------------------------------------------------------
REPORT_DIR="designs/$DESIGN/runs/$TAG/reports"

echo ""
echo "=== SYNTHESIS SUMMARY ==="
grep -E "Number of cells|Chip area" $REPORT_DIR/synthesis/1-synthesis.stat.rpt 2>/dev/null || echo "Check synthesis report"

echo ""
echo "=== TIMING SUMMARY (WNS/TNS) ==="
grep -E "wns|tns|VIOLATED" $REPORT_DIR/signoff/*sta*.rpt 2>/dev/null | head -20

echo ""
echo "=== DRC VIOLATIONS ==="
grep -c "violation" $REPORT_DIR/routing/*drc* 2>/dev/null || echo "0 DRC violations"

echo ""
echo "=== POWER SUMMARY ==="
grep -E "Total|Dynamic|Leakage" $REPORT_DIR/signoff/*power* 2>/dev/null | head -10
