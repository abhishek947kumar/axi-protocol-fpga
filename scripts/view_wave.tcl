# ==============================================================================
# File: view_wave.tcl
# Description: Loads the simulation waveform database into Vivado Waveform Viewer.
# ==============================================================================

if {[file exists sim_output/tb_axi_waveform.wdb]} {
    puts "Opening waveform database: sim_output/tb_axi_waveform.wdb"
    open_wave_database sim_output/tb_axi_waveform.wdb
} else {
    puts "Waveform database not found. Please run scripts/run_sim.bat first."
}
