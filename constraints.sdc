# ============================================================
# constraints.sdc — Timing Constraints for RISC-V Core
# Target: Sky130 PDK, 100MHz (10ns clock)
# ============================================================

# ----------------------------------------------------------
# 1. Clock Definition
# ----------------------------------------------------------
create_clock -name clk \
             -period 10.0 \
             -waveform {0 5} \
             [get_ports clk]

# Clock uncertainty (jitter + skew budget)
set_clock_uncertainty -setup 0.2 [get_clocks clk]
set_clock_uncertainty -hold  0.1 [get_clocks clk]

# Clock transition (slew)
set_clock_transition 0.15 [get_clocks clk]

# ----------------------------------------------------------
# 2. Input / Output Delays
# ----------------------------------------------------------
# Input delay = 20% of clock period
set_input_delay  -clock clk -max 2.0 [all_inputs]
set_input_delay  -clock clk -min 0.5 [all_inputs]

# Output delay = 20% of clock period
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.5 [all_outputs]

# Remove delay from clock port itself
set_input_delay  -clock clk 0 [get_ports clk]

# ----------------------------------------------------------
# 3. Driving Cell & Load
# ----------------------------------------------------------
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 \
                 -pin Y \
                 [all_inputs]

set_load 0.1 [all_outputs]

# ----------------------------------------------------------
# 4. False Paths
# ----------------------------------------------------------
# Async reset is a false path for timing
set_false_path -from [get_ports rst_n]

# ----------------------------------------------------------
# 5. Multicycle Paths (if applicable)
# ----------------------------------------------------------
# Example: Memory interface may take 2 cycles
# set_multicycle_path -setup 2 -from [get_pins u_dmem/*]
# set_multicycle_path -hold  1 -from [get_pins u_dmem/*]

# ----------------------------------------------------------
# 6. Operating Conditions
# ----------------------------------------------------------
# Worst case: SS corner, 1.6V, 100°C
# set_operating_conditions -library sky130_fd_sc_hd__ss_100C_1v60

# ----------------------------------------------------------
# 7. Max Fanout / Transition
# ----------------------------------------------------------
set_max_fanout    10 [current_design]
set_max_transition 0.5 [current_design]
set_max_capacitance 0.5 [current_design]
