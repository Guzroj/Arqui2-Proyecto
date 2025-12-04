@echo off
echo ========================================
echo Compilando y ejecutando testbench
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

vlog -sv rtl/Downscale_Secuencial.sv
if errorlevel 1 goto error

vlog -sv rtl/Top_Downscale_Secuencial.sv
if errorlevel 1 goto error

REM Compilar testbench
echo.
echo Compilando testbench...
vlog -sv testbench/tb_top_Downscale_Secuencial.sv
if errorlevel 1 goto error

REM Ejecutar simulación
echo.
echo Ejecutando simulacion...
vsim -c -do "run -all; quit" tb_top_Downscale_Secuencial
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
exit /b 1

:end
