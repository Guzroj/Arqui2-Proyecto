@echo off
echo ========================================
echo Compilando y ejecutando testbench SIMD
echo ========================================

REM Limpiar archivos anteriores
if exist work rmdir /s /q work

REM Crear librería de trabajo
vlib work

REM Compilar archivos RTL
echo.
echo Compilando modulos RTL...
vlog -sv rtl/ModoSecuencial.sv
if errorlevel 1 goto error

vlog -sv rtl/ModoSIMD.sv
if errorlevel 1 goto error

vlog -sv rtl/FSM_SIMD.sv
if errorlevel 1 goto error

vlog -sv rtl/SIMD_Registros.sv
if errorlevel 1 goto error

vlog -sv rtl/Top_SIMD.sv
if errorlevel 1 goto error

vlog -sv rtl/Downscale_SIMD.sv
if errorlevel 1 goto error

vlog -sv rtl/Top_Downscale_SIMD.sv
if errorlevel 1 goto error

REM Compilar testbench
echo.
echo Compilando testbench...
vlog -sv testbench/tb_Top_Downscale_Integration.sv
if errorlevel 1 goto error

REM Ejecutar simulación
echo.
echo Ejecutando simulacion...
vsim -c -do "run -all; quit" tb_Top_Downscale_Integration
if errorlevel 1 goto error

echo.
echo ========================================
echo Simulacion completada exitosamente
echo ========================================
goto end

:error
echo.
echo ========================================
echo ERROR en la compilacion o simulacion
echo ========================================
pause
exit /b 1

:end
pause
