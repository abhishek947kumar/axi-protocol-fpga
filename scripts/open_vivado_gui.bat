@echo off
setlocal enabledelayedexpansion
echo ==============================================================================
echo   Launching Vivado GUI Project: vivado_project\axi_fpga_project.xpr
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

start "" "%VIVADO_BIN%" vivado_project\axi_fpga_project.xpr
