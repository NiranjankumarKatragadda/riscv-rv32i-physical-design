# ============================================================
# sta_analysis.tcl — Static Timing Analysis with OpenSTA
# Run: sta sta_analysis.tcl
# ============================================================

# -------------------------------------------------------
# 1. Setup
# -------------------------------------------------------
read_liberty  sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog  riscv_pipeline_synth.v
link_design   riscv_pipeline

read_sdc      constraints.sdc

# -------------------------------------------------------
# 2. Report Timing — Setup Check
# -------------------------------------------------------
puts "============ SETUP TIMING ============"
report_checks \
    -path_delay max \
    -fields {slew cap input nets fanout} \
    -format full_clock_expanded \
    -digits 3

# -------------------------------------------------------
# 3. Report Timing — Hold Check
# -------------------------------------------------------
puts "============ HOLD TIMING ============"
report_checks \
    -path_delay min \
    -fields {slew cap input nets fanout} \
    -format full_clock_expanded \
    -digits 3

# -------------------------------------------------------
# 4. WNS / TNS Summary
# -------------------------------------------------------
puts "============ WNS / TNS ============"
report_wns
report_tns
report_worst_slack -max
report_worst_slack -min

# -------------------------------------------------------
# 5. Check by Clock Domain
# -------------------------------------------------------
puts "============ CLOCK SUMMARY ============"
report_clock_skew
report_clock_latency

# -------------------------------------------------------
# 6. Power Estimation
# -------------------------------------------------------
puts "============ POWER ============"
report_power

# -------------------------------------------------------
# 7. Report Unconstrained Endpoints
# -------------------------------------------------------
puts "============ UNCONSTRAINED PATHS ============"
report_checks -unconstrained

# -------------------------------------------------------
# 8. Check Fanout Violations
# -------------------------------------------------------
puts "============ FANOUT ============"
report_check_types -max_fanout
report_check_types -max_transition
report_check_types -max_capacitance


# ============================================================
# TIMING VIOLATION FIX GUIDE
# ============================================================
#
# SETUP VIOLATION (WNS < 0):
# ----------------------------
# 1. Buffer insertion on long paths:
#    insert_buffer [get_nets long_net] sky130_fd_sc_hd__buf_4
#
# 2. Upsize driver cell:
#    replace_cell [get_cells slow_cell] sky130_fd_sc_hd__buf_8
#
# 3. Increase clock period (relax constraint):
#    create_clock -period 12.0 [get_ports clk]
#
# 4. Logic restructuring — break long combinational paths
#
# HOLD VIOLATION (WNS < 0 in hold):
# -----------------------------------
# 1. Insert delay buffer (hold fix):
#    insert_buffer [get_nets hold_net] sky130_fd_sc_hd__dlygate4sd3_1
#
# 2. CTS hold margin adjustment:
#    set CTS_HOLD_SLACK_MARGIN 0.1
#
# ============================================================
# REPORT INTERPRETATION
# ============================================================
#
# Timing Path Example:
# -------------------
# Startpoint: regfile_reg[5][3]/CLK
# Endpoint:   alu/result[3]
#
# Path Type: max (setup)
# Point                    Incr   Path
# -------                  ----   ----
# clock clk (rise)         0.00   0.00
# regfile_reg[5][3]/CLK    0.20   0.20  (clock insertion)
# regfile_reg[5][3]/Q      0.30   0.50  (cell delay)
# alu_a[3]                 0.15   0.65  (net delay)
# alu/U23/A                0.00   0.65
# alu/U23/Y                0.25   0.90  (cell delay)
# alu/result[3]            0.05   0.95  (net)
# EX_MEM_alu_result[3]/D   0.00   0.95
# -------
# data arrival time               0.95
#
# clock clk (rise)         0.00  10.00
# clock uncertainty               -0.20
# EX_MEM_alu_result[3]/CLK        9.80  (clock at endpoint)
# library setup time              -0.18
# data required time               9.62
# -------
# slack (MET)                      8.67  ← WNS (positive = good!)
