@echo off
chcp 65001 >nul 2>&1
echo ========================================
echo   LumenIM Build Environment Check v2.0.2
echo ========================================
echo.

REM 检查 Node.js
echo [1] Node.js:
where node >nul 2>&1
if errorlevel 1 (
    echo    FAIL - Not installed
) else (
    for /f "delims=" %%v in ('node --version 2^>nul') do echo    OK - %%v
)

REM 检查 npm
echo [2] npm:
where npm >nul 2>&1
if errorlevel 1 (
    echo    FAIL - Not installed
) else (
    for /f "delims=" %%v in ('npm --version 2^>nul') do echo    OK - %%v
)

REM 检查 Rust
echo [3] Rust:
where rustc >nul 2>&1
if errorlevel 1 (
    echo    FAIL - Not installed
) else (
    for /f "delims=" %%v in ('rustc --version 2^>nul') do echo    OK - %%v
)

REM 检查 Tauri
echo [4] Tauri CLI:
where tauri >nul 2>&1
if errorlevel 1 (
    npx tauri --version >nul 2>&1
    if errorlevel 1 (
        echo    WARN - Not installed
    ) else (
        for /f "delims=" %%v in ('npx tauri --version 2^>nul') do echo    OK - %%v
    )
) else (
    for /f "delims=" %%v in ('tauri --version 2^>nul') do echo    OK - %%v
)

REM 检查项目文件 - front 在 LumenIM 根目录，不是 software 目录下
set "PROJECT_ROOT=%~dp0..\..\front"
echo.
echo [5] Project Files (%PROJECT_ROOT%):
if exist "%PROJECT_ROOT%\package.json" (
    echo    OK - package.json
) else (
    echo    FAIL - package.json missing
)

if exist "%PROJECT_ROOT%\vite.config.ts" (
    echo    OK - vite.config.ts
) else (
    echo    FAIL - vite.config.ts missing
)

if exist "%PROJECT_ROOT%\src-tauri\tauri.conf.json" (
    echo    OK - src-tauri\tauri.conf.json
) else (
    echo    FAIL - src-tauri\tauri.conf.json missing
)

if exist "%PROJECT_ROOT%\src-tauri\Cargo.toml" (
    echo    OK - src-tauri\Cargo.toml
) else (
    echo    FAIL - src-tauri\Cargo.toml missing
)

if exist "%PROJECT_ROOT%\node_modules" (
    echo    OK - node_modules
) else (
    echo    WARN - node_modules missing
)

echo.
echo ========================================
echo   Check Complete
echo ========================================
pause
