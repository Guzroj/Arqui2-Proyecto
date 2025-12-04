@echo off
REM ========================================
REM Script de prueba rapida - FASES 1 y 2
REM ========================================

echo.
echo ======================================================================
echo PRUEBA RAPIDA: FASES 1 y 2
echo ======================================================================
echo.

REM Verificar Python
echo [1/4] Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo   X ERROR: Python no encontrado
    echo   Instalar Python 3.x desde https://www.python.org/
    pause
    exit /b 1
)
python --version
echo   OK Python encontrado
echo.

REM Verificar C++
echo [2/4] Verificando compilador C++...
g++ --version >nul 2>&1
if errorlevel 1 (
    echo   X ERROR: g++ no encontrado
    echo   Instalar MinGW desde https://www.mingw-w64.org/
    pause
    exit /b 1
)
g++ --version | findstr /C:"gcc"
echo   OK Compilador encontrado
echo.

pause
echo.

REM Ejecutar tests Python
echo [3/4] Ejecutando tests Python (FASE 1)...
echo ======================================================================
cd software\python
python TEST_FASE1.py
if errorlevel 1 (
    echo.
    echo   X ERROR en tests Python
    pause
    exit /b 1
)
cd ..\..
echo.
echo   OK Tests Python pasados
echo.

pause
echo.

REM Compilar modelo C++
echo [4/4] Compilando modelo C++ (FASE 2)...
echo ======================================================================
cd software\reference_model
mingw32-make clean
mingw32-make
if errorlevel 1 (
    echo.
    echo   X ERROR compilando C++
    pause
    exit /b 1
)
cd ..\..
echo.
echo   OK Modelo C++ compilado
echo.

pause
echo.

REM Validacion cruzada
echo [5/5] Validacion cruzada Python vs C++...
echo ======================================================================
cd software\python\utils
python validate_cpp_model.py
if errorlevel 1 (
    echo.
    echo   X ERROR en validacion cruzada
    pause
    exit /b 1
)
cd ..\..\..
echo.

echo ======================================================================
echo ✓✓✓ TODAS LAS PRUEBAS PASARON ✓✓✓
echo ======================================================================
echo.
echo FASES 0, 1, 2 COMPLETADAS EXITOSAMENTE
echo.
echo Proximo paso:
echo   - FASE 3: Test de JTAG con LEDs
echo.
echo ======================================================================
pause
