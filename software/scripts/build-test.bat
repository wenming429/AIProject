@echo off
chcp 65001 >nul 2>&1
REM ========================================
REM LumenIM Desktop - Build Test Version
REM ========================================

cd /d "%~dp0"

REM 检查 build-tauri.bat
if not exist "build-tauri.bat" (
    echo [ERROR] build-tauri.bat not found
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Building TEST Environment
echo ========================================
echo.

call build-tauri.bat test

if errorlevel 1 (
    echo.
    echo Build FAILED
    pause
    exit /b 1
)

echo.
echo ========================================
echo   TEST Build SUCCESS!
echo ========================================
echo.
echo Output: ..\..\front\src-tauri\target\release_test
echo.

set /p OPEN="Open output folder? (Y/N): "
if /i "%OPEN%"=="Y" (
    explorer "%~dp0..\..\front\src-tauri\target\release_test"
)

pause
