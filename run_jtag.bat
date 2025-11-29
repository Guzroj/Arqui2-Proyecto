@echo off
REM ================================================================
REM run_jtag.bat
REM Ejecuta la GUI de control JTAG
REM ================================================================

echo Buscando Quartus...

REM Rutas comunes de Quartus
set QUARTUS_PATH=

if exist "C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_PATH=C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe
    goto :found
)

if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_PATH=C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe
    goto :found
)

if exist "C:\altera\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_PATH=C:\altera\20.1\quartus\bin64\quartus_stp.exe
    goto :found
)

REM Buscar en PATH
where quartus_stp.exe >nul 2>&1
if %errorlevel%==0 (
    set QUARTUS_PATH=quartus_stp.exe
    goto :found
)

echo ERROR: No se encontro quartus_stp.exe
echo Por favor, edita este archivo y agrega la ruta correcta
pause
exit /b 1

:found
echo Encontrado: %QUARTUS_PATH%
echo.
echo Iniciando GUI de control JTAG...
echo.

"%QUARTUS_PATH%" -t "%~dp0form.tcl"

pause

