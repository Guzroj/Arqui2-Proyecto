@echo off
echo ============================================
echo   Buscando quartus_stp...
echo ============================================

cd /d "%~dp0"
echo Directorio actual: %CD%
echo.

REM Intentar diferentes rutas de Quartus
set QUARTUS_STP=

REM Ruta 1: Intel FPGA 20.1
if exist "C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_STP=C:\intelFPGA\20.1\quartus\bin64\quartus_stp.exe
    goto found
)

REM Ruta 2: intelFPGA_lite 20.1
if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_STP=C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe
    goto found
)

REM Ruta 3: Altera 20.1
if exist "C:\altera\20.1\quartus\bin64\quartus_stp.exe" (
    set QUARTUS_STP=C:\altera\20.1\quartus\bin64\quartus_stp.exe
    goto found
)

REM Ruta 4: Buscar en PATH
where quartus_stp.exe >nul 2>&1
if %errorlevel%==0 (
    set QUARTUS_STP=quartus_stp.exe
    goto found
)

REM No encontrado
echo ERROR: No se encontro quartus_stp.exe
echo.
echo Por favor, busca manualmente donde esta instalado Quartus.
echo Ejemplo: C:\intelFPGA_lite\20.1\quartus\bin64\
echo.
pause
exit /b 1

:found
echo Encontrado: %QUARTUS_STP%
echo.
echo Ejecutando form.tcl...
echo ============================================
echo.

"%QUARTUS_STP%" -t form.tcl

echo.
echo ============================================
echo Script terminado.
pause

