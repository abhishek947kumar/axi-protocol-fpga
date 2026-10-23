@echo off
setlocal enabledelayedexpansion
echo ==============================================================================
echo   AXI Protocol FPGA Subsystem - Full Verification and Synthesis Flow
echo ==============================================================================

set VIVADO_BIN=C:\Xilinx\Vivado\2019.2\bin\vivado.bat
if not exist "%VIVADO_BIN%" (
    where vivado >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        set VIVADO_BIN=vivado
    ) else (
        echo [ERROR] Vivado not found in C:\Xilinx\Vivado\2019.2\bin or system PATH!
        exit /b 1
    )
)

echo [1/3] Running Simulation...
call "%VIVADO_BIN%" -mode batch -source scripts\sim.tcl -notrace
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Simulation failed!
    exit /b %ERRORLEVEL%
)

echo [2/3] Running Synthesis & Timing Closure...
call "%VIVADO_BIN%" -mode batch -source scripts\synth.tcl -notrace
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Synthesis failed!
    exit /b %ERRORLEVEL%
)

echo [3/3] Generating Vivado GUI Project...
call "%VIVADO_BIN%" -mode batch -source scripts\create_vivado_proj.tcl -notrace
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Project generation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo ==============================================================================
echo   [SUCCESS] Full Flow Completed Successfully!
echo   - Waveforms: sim_output\tb_axi_waveform.wdb
echo   - Reports:   synth_output\utilization.rpt, timing_summary.rpt
echo   - Project:   vivado_project\axi_fpga_project.xpr
echo ==============================================================================
pause
