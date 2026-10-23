# ==============================================================================
# File: create_vivado_proj.tcl
# Description: Generates a complete Vivado GUI Project (.xpr) for the
#              AXI Protocol Subsystem with RTL, TB, and Constraints added.
# Usage: vivado -mode batch -source scripts/create_vivado_proj.tcl
# ==============================================================================

set proj_name "axi_fpga_project"
set proj_dir  "./vivado_project"
set part_num  "xc7a35tcsg324-1"

puts "Creating project: $proj_name in $proj_dir"
create_project -force $proj_name $proj_dir -part $part_num

# Add RTL Source Files
add_files -fileset sources_1 [list \
    rtl/axi_pkg.vh \
    rtl/axi4_slave_bram.v \
    rtl/axi4_lite_slave_reg.v \
    rtl/axi4_to_axilite_bridge.v \
    rtl/axi4_interconnect_1x2.v \
    rtl/axi4_master.v \
    rtl/axi_soc_top.v \
]

# Set Top Module
set_property top axi_soc_top [current_fileset]

# Add Timing Constraints
add_files -fileset constrs_1 [list \
    constraints/axi_timing.xdc \
]

# Add Simulation Sources
add_files -fileset sim_1 [list \
    tb/axi_protocol_checker.sv \
    tb/tb_axi_top.sv \
]

# Set Simulation Top
set_property top tb_axi_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "=========================================================================="
puts "  Vivado Project Successfully Created! Open vivado_project/$proj_name.xpr"
puts "=========================================================================="
