@echo off
REM ============================================================================
REM run_sim.bat
REM Script batch para ejecutar simulación en ModelSim
REM FASE 4: Módulos de Memoria
REM ============================================================================

echo ==========================================
echo ModelSim Simulation - Memory Modules
echo ==========================================
echo.

REM Buscar ModelSim en ubicaciones comunes
set MODELSIM_PATH=

REM Intentar ubicación de ModelSim-Intel (viene con Quartus)
if exist "C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe" (
    set MODELSIM_PATH=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem
    goto :found
)

REM Intentar otras versiones
for /d %%i in ("C:\intelFPGA_lite\*") do (
    if exist "%%i\modelsim_ase\win32aloem\vsim.exe" (
        set MODELSIM_PATH=%%i\modelsim_ase\win32aloem
        goto :found
    )
)

REM Intentar ModelSim standalone
if exist "C:\modeltech64\win64\vsim.exe" (
    set MODELSIM_PATH=C:\modeltech64\win64
    goto :found
)

:not_found
echo ERROR: No se encontro ModelSim.
echo.
echo Por favor, instale ModelSim o verifique la ruta de instalacion.
echo.
pause
exit /b 1

:found
echo ModelSim encontrado en: %MODELSIM_PATH%
echo.
echo Ejecutando simulacion...
echo.

REM Cambiar al directorio de simulación
cd /d "%~dp0"

REM Ejecutar ModelSim con el script .do
"%MODELSIM_PATH%\vsim.exe" -do run_modelsim.do

pause
