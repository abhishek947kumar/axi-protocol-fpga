@echo off
setlocal enabledelayedexpansion
echo ==============================================================================
echo   AXI Protocol FPGA Subsystem - Vivado Synthesis Launcher
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

call "%VIVADO_BIN%" -mode batch -source scripts\synth.tcl -notrace
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Synthesis failed with code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Synthesis completed successfully!
pause
