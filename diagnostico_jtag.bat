@echo off
echo ========================================
echo DIAGNOSTICO COMPLETO DE JTAG
echo ========================================
echo.

echo [1/6] Matando procesos de Quartus...
taskkill /F /IM quartus_pgm.exe /T >nul 2>&1
taskkill /F /IM quartus_stp.exe /T >nul 2>&1
taskkill /F /IM system-console.exe /T >nul 2>&1
taskkill /F /IM jtagd.exe /T >nul 2>&1
taskkill /F /IM jtagserver.exe /T >nul 2>&1
echo Procesos terminados.
echo.

echo [2/6] Verificando instalacion de Quartus...
if exist "C:\intelFPGA_lite\20.1\quartus\bin64\jtagconfig.exe" (
    echo OK: Quartus encontrado
) else (
    echo ERROR: No se encuentra Quartus
    pause
    exit /b 1
)
echo.

echo [3/6] Verificando dispositivos JTAG...
cd C:\intelFPGA_lite\20.1\quartus\bin64
jtagconfig
echo.

echo [4/6] Reiniciando servidor JTAG...
jtagconfig --debug
echo.

echo [5/6] Listando dispositivos USB...
jtagconfig --enum
echo.

echo [6/6] Test de comunicacion JTAG...
quartus_pgm --test
echo.

echo ========================================
echo DIAGNOSTICO COMPLETO
echo ========================================
echo.
echo Si ves "1) USB-Blaster [USB-0]" arriba, el JTAG funciona.
echo Si NO ves nada, hay problema con el cable o drivers.
echo.
pause
