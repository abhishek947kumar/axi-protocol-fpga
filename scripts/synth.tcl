# ==============================================================================
# File: synth.tcl
# Description: Vivado Non-Project Mode Synthesis & Timing Closure Script.
# Target: Xilinx Artix-7 (xc7a35tcsg324-1)
# ==============================================================================

# Create synthesis output directory
file mkdir synth_output

puts "=========================================================================="
puts "  STEP 1/4: Reading RTL Source Files"
puts "=========================================================================="

read_verilog [list \
    rtl/axi_pkg.vh \
    rtl/axi4_slave_bram.v \
    rtl/axi4_lite_slave_reg.v \
    rtl/axi4_to_axilite_bridge.v \
    rtl/axi4_interconnect_1x2.v \
    rtl/axi4_master.v \
    rtl/axi_soc_top.v \
]

puts "=========================================================================="
puts "  STEP 2/4: Reading Timing Constraints"
puts "=========================================================================="

read_xdc constraints/axi_timing.xdc

puts "=========================================================================="
puts "  STEP 3/4: Synthesizing Top-Level Design (axi_soc_top)"
puts "=========================================================================="

synth_design -top axi_soc_top -part xc7a35tcsg324-1 -include_dirs rtl -flatten_hierarchy rebuilt

puts "=========================================================================="
puts "  STEP 4/4: Generating Implementation Reports"
puts "=========================================================================="

report_utilization -file synth_output/utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -nworst 1 -file synth_output/timing_summary.rpt
report_power -file synth_output/power.rpt
report_drc -file synth_output/drc.rpt

puts "=========================================================================="
puts "  Synthesis Finished! Reports generated in synth_output/"
puts "=========================================================================="
