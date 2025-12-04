@echo off
REM ============================================================================
REM start_client.bat
REM Script para ejecutar el cliente Python de downscaling
REM ============================================================================

echo ========================================
echo Cliente JTAG - Downscaling 64x64 a 32x32
echo ========================================
echo.

REM Verificar que Python esta instalado
where python >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python no esta instalado o no esta en el PATH
    echo.
    echo Por favor instala Python 3.x desde: https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)

REM Verificar que NumPy esta instalado
python -c "import numpy" >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: NumPy no esta instalado
    echo.
    echo Instalando NumPy...
    python -m pip install numpy
    echo.
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: No se pudo instalar NumPy
        pause
        exit /b 1
    )
    echo NumPy instalado correctamente
    echo.
)

REM Cambiar al directorio del script
cd /d "%~dp0"

echo Ejecutando cliente Python...
echo.
echo NOTA: Asegurate de que el servidor JTAG este corriendo en System Console
echo       antes de ejecutar este cliente.
echo.

REM Ejecutar el cliente
python downscale_client.py

echo.
echo Cliente finalizado.
pause
