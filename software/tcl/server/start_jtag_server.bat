@echo off
REM ============================================================================
REM start_jtag_server.bat
REM Script batch para ejecutar el servidor JTAG en Windows
REM FASE 3: Test de JTAG con LEDs
REM ============================================================================

echo ==========================================
echo JTAG Downscaling Server - FASE 6
echo ==========================================
echo.

REM Buscar Quartus en ubicaciones comunes
set QUARTUS_PATH=

REM Intentar ubicacion estandar de Quartus Prime Lite 20.1
if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_PATH=C:\intelFPGA_lite\20.1\quartus\bin64
    goto :found
)

REM Intentar otras versiones de Quartus Lite
for /d %%i in ("C:\intelFPGA_lite\*") do (
    if exist "%%i\quartus\bin64\quartus_stp.exe" (
        set QUARTUS_PATH=%%i\quartus\bin64
        goto :found
    )
)

REM Intentar Quartus Prime Standard
for /d %%i in ("C:\intelFPGA\*") do (
    if exist "%%i\quartus\bin64\quartus_stp.exe" (
        set QUARTUS_PATH=%%i\quartus\bin64
        goto :found
    )
)

REM Intentar ubicación de Altera (versiones antiguas)
for /d %%i in ("C:\altera\*") do (
    if exist "%%i\quartus\bin64\quartus_stp.exe" (
        set QUARTUS_PATH=%%i\quartus\bin64
        goto :found
    )
)

REM Intentar desde variables de entorno
if defined QUARTUS_ROOTDIR (
    if exist "%QUARTUS_ROOTDIR%\bin64\quartus_stp.exe" (
        set QUARTUS_PATH=%QUARTUS_ROOTDIR%\bin64
        goto :found
    )
)

:not_found
echo ERROR: No se encontro Quartus Prime.
echo.
echo Por favor, instale Quartus Prime o verifique la ruta de instalacion.
echo.
echo Rutas comunes:
echo   C:\intelFPGA_lite\20.1\quartus\bin64
echo   C:\intelFPGA\20.1\quartus\bin64
echo   C:\altera\20.1\quartus\bin64
echo.
pause
exit /b 1

:found
echo Quartus encontrado en: %QUARTUS_PATH%
echo.
echo Ejecutando servidor JTAG...
echo.

REM Cambiar al directorio del proyecto
cd /d "%~dp0\..\..\..\"

REM Ejecutar quartus_stp con el script TCL de downscaling
"%QUARTUS_PATH%\quartus_stp.exe" -t software\tcl\server\jtag_downscale_server_sld.tcl

pause
