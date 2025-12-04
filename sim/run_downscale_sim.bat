@echo off
REM ============================================================================
REM run_downscale_sim.bat
REM Script para ejecutar simulación de downscaling en ModelSim
REM FASE 5: Downscaling secuencial con pipeline
REM ============================================================================

echo.
echo ==========================================
echo Downscale Sequential Simulation - FASE 5
echo ==========================================
echo.

REM Detectar instalación de ModelSim
set MODELSIM_PATH=

REM Buscar ModelSim en ubicaciones comunes
if exist "C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe" (
    set MODELSIM_PATH=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem
    echo ModelSim encontrado en: %MODELSIM_PATH%
    goto :found_modelsim
)

if exist "C:\intelFPGA\20.1\modelsim_ase\win32aloem\vsim.exe" (
    set MODELSIM_PATH=C:\intelFPGA\20.1\modelsim_ase\win32aloem
    echo ModelSim encontrado en: %MODELSIM_PATH%
    goto :found_modelsim
)

if exist "C:\modeltech_ase\win32aloem\vsim.exe" (
    set MODELSIM_PATH=C:\modeltech_ase\win32aloem
    echo ModelSim encontrado en: %MODELSIM_PATH%
    goto :found_modelsim
)

REM No se encontró ModelSim
echo ERROR: No se encontro ModelSim
echo.
echo Por favor, instala ModelSim-Intel FPGA Edition o actualiza la ruta en este script
pause
exit /b 1

:found_modelsim
echo.
echo Ejecutando simulacion de downscaling...
echo.

REM Cambiar al directorio de simulación
cd /d "%~dp0"

REM Ejecutar ModelSim con el script TCL
"%MODELSIM_PATH%\vsim" -do run_downscale_sim.do

echo.
echo ==========================================
echo Simulacion completada
echo ==========================================
echo.
pause
