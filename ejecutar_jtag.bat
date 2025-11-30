@echo off
REM ================================================================
REM Script para ejecutar la interfaz JTAG
REM ================================================================

REM Cambiar al directorio del script
cd /d "%~dp0"

echo.
echo ============================================================
echo   Ejecutando Interfaz JTAG - Downscale Project
echo ============================================================
echo.
echo Directorio actual: %CD%
echo.

REM Verificar que form.tcl existe
if not exist "form.tcl" (
    echo ERROR: No se encontro form.tcl en el directorio actual
    echo.
    echo Asegurate de ejecutar este script desde la carpeta del proyecto
    echo.
    pause
    exit /b 1
)

echo Asegurate de que:
echo   1. La FPGA este programada con ModoSecuencial.sof
echo   2. El cable USB-Blaster este conectado
echo   3. Quartus Programmer NO esta abierto
echo.
echo Buscando quartus_stp.exe...
echo.

REM Buscar quartus_stp en las rutas comunes
set QUARTUS_STP_PATH=

if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_STP_PATH=C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe
    echo Encontrado: %QUARTUS_STP_PATH%
) else if exist "C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_STP_PATH=C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe
    echo Encontrado: %QUARTUS_STP_PATH%
) else (
    echo ERROR: No se encontro quartus_stp.exe
    echo.
    echo Busca manualmente la ruta a quartus_stp.exe y ejecuta:
    echo   quartus_stp -t form.tcl
    echo.
    echo Rutas probadas:
    echo   - C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe
    echo   - C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe
    echo.
    pause
    exit /b 1
)

echo.
echo Ejecutando quartus_stp -t form.tcl...
echo Si hay errores, revisa la ventana que se abre.
echo.
echo ============================================================
echo.

REM Ejecutar quartus_stp
"%QUARTUS_STP_PATH%" -t form.tcl

REM Si quartus_stp termina con error, mostrar mensaje
if errorlevel 1 (
    echo.
    echo ============================================================
    echo ERROR: quartus_stp termino con un error
    echo ============================================================
    echo.
    echo Revisa los mensajes de error arriba.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo Script terminado normalmente
echo ============================================================
pause
