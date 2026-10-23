# ==============================================================================
# File: axi_timing.xdc
# Description: Timing and Physical Constraints for AXI4 Protocol Implementation.
# Target Device: Xilinx Artix-7 (xc7a35tcsg324-1 / xc7a100tcsg324-1)
# ==============================================================================

# Primary AXI Subsystem Clock: 100 MHz (10.000 ns period)
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Set Clock Uncertainty for high-reliability synthesis
set_clock_uncertainty 0.200 [get_clocks clk]

# Asynchronous Reset False Path
set_false_path -from [get_ports rst_n]

# Input Delays relative to clk (2.0 ns setup requirement)
set_input_delay -clock [get_clocks clk] -max 2.000 [get_ports {cmd_* rst_n}]
set_input_delay -clock [get_clocks clk] -min 0.500 [get_ports {cmd_* rst_n}]

# Output Delays relative to clk (2.0 ns clock-to-out)
set_output_delay -clock [get_clocks clk] -max 2.000 [get_ports {status_leds* wr_* rd_* last_rd_data* debug_csr_*}]
set_output_delay -clock [get_clocks clk] -min 0.500 [get_ports {status_leds* wr_* rd_* last_rd_data* debug_csr_*}]

# Device Configuration Voltage Properties (Artix-7 3.3V Bank 0)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

