@echo off
chcp 65001 >nul 2>&1
REM ========================================
REM LumenIM Desktop - Build All Environments
REM ========================================

REM 切换到脚本目录
cd /d "%~dp0"

REM 设置项目路径
set "PROJECT_ROOT=%~dp0..\..\front"

REM 验证 build-tauri.bat 存在
if not exist "build-tauri.bat" (
    echo [ERROR] build-tauri.bat not found
    echo Current path: %CD%
    pause
    exit /b 1
)

REM 设置日志
set "LOG_DIR=%~dp0..\..\software\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\build_all_%date:~0,4%%date:~5,2%%date:~8,2%.log"

echo ========================================
echo   LumenIM Build All Environments
echo ========================================
echo.

REM 确认提示
set /p CONFIRM="Start build? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled
    exit /b 0
)

echo [%date% %time%] Build started >> "%LOG_FILE%"

set "BUILD_LOCAL=0"
set "BUILD_TEST=0"
set "BUILD_PROD=0"

echo.
echo [1/3] Building Local...
echo ========================================
call build-tauri.bat local >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    set "BUILD_LOCAL=1"
    echo [FAIL] Local build failed
) else (
    echo [OK] Local build completed
)

echo.
echo [2/3] Building Test...
echo ========================================
call build-tauri.bat test >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    set "BUILD_TEST=1"
    echo [FAIL] Test build failed
) else (
    echo [OK] Test build completed
)

echo.
echo [3/3] Building Production...
echo ========================================
call build-tauri.bat prod >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    set "BUILD_PROD=1"
    echo [FAIL] Production build failed
) else (
    echo [OK] Production build completed
)

echo.
echo ========================================
echo   Build Summary
echo ========================================
echo.
echo   Output:
echo   - Local:  %PROJECT_ROOT%\src-tauri\target\release_local
echo   - Test:   %PROJECT_ROOT%\src-tauri\target\release_test
echo   - Prod:   %PROJECT_ROOT%\src-tauri\target\release
echo.
echo ========================================

set "FAILED=0"
if "%BUILD_LOCAL%"=="1" set /a FAILED+=1
if "%BUILD_TEST%"=="1" set /a FAILED+=1
if "%BUILD_PROD%"=="1" set /a FAILED+=1

if "%FAILED%"=="0" (
    echo [SUCCESS] All builds completed
    echo [%date% %time%] All builds SUCCESS >> "%LOG_FILE%"
) else (
    echo [WARNING] %FAILED% build(s) failed
    echo [%date% %time%] %FAILED% builds FAILED >> "%LOG_FILE%"
)

echo.
set /p OPEN="Open output directory? (Y/N): "
if /i "%OPEN%"=="Y" (
    if exist "%PROJECT_ROOT%\src-tauri\target" (
        explorer "%PROJECT_ROOT%\src-tauri\target"
    )
)

echo.
echo Log: %LOG_FILE%
pause
