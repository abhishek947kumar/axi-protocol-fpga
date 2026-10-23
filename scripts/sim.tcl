# ==============================================================================
# File: sim.tcl
# Description: Vivado Simulation Automation Script for AXI Protocol Subsystem.
# ==============================================================================

# Create simulation output directory if it does not exist
file mkdir sim_output

puts "=========================================================================="
puts "  STEP 1/3: Compiling RTL and Verification Files with xvlog"
puts "=========================================================================="

exec xvlog -i rtl \
    rtl/axi4_slave_bram.v \
    rtl/axi4_lite_slave_reg.v \
    rtl/axi4_to_axilite_bridge.v \
    rtl/axi4_interconnect_1x2.v \
    rtl/axi4_master.v \
    rtl/axi_soc_top.v

exec xvlog -sv -i rtl \
    tb/axi_protocol_checker.sv \
    tb/tb_axi_top.sv

puts "=========================================================================="
puts "  STEP 2/3: Elaborating Design Snapshot with xelab"
puts "=========================================================================="

exec xelab -top tb_axi_top -snapshot tb_axi_snapshot -timescale 1ns/1ps -debug typical

puts "=========================================================================="
puts "  STEP 3/3: Executing Simulation with xsim"
puts "=========================================================================="

set sim_result [exec xsim tb_axi_snapshot -runall -wdb sim_output/tb_axi_waveform.wdb]
puts $sim_result

puts "=========================================================================="
puts "  Simulation Complete! Waveform saved to sim_output/tb_axi_waveform.wdb"
puts "=========================================================================="
