@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

REM ========================================
REM LumenIM 桌面应用 - 多环境构建脚本
REM ========================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\..\front"
set "BUILD_MODE=%~1"

REM 设置默认值
if "%BUILD_MODE%"=="" set "BUILD_MODE=local"

REM 日志目录 - logs 在 software/logs
set "LOG_DIR=%SCRIPT_DIR%..\..\software\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\build_%BUILD_MODE%_%date:~0,4%%date:~5,2%%date:~8,2%.log"

goto :main

REM ========================================
REM 日志函数
REM ========================================
:log
    set "msg=%~1"
    set "level=%~2"
    set "timestamp=[%date:~0,4%-%date:~5,2%-%date:~8,2% %time:~0,2%:%time:~3,2%:%time:~6,2%]"
    echo !timestamp! [!level!] !msg!
    echo !timestamp! [!level!] !msg! >> "%LOG_FILE%"
    exit /b 0

:log_error
    call :log "%~1" "ERROR"
    exit /b 1

:log_warn
    call :log "%~1" "WARN"
    exit /b 0

:log_info
    call :log "%~1" "INFO"
    exit /b 0

:log_success
    call :log "%~1" "SUCCESS"
    exit /b 0

REM ========================================
REM 显示帮助
REM ========================================
:show_help
    echo.
    echo LumenIM Desktop Build Script
    echo.
    echo Usage: build-tauri.bat [env]
    echo.
    echo Available:
    echo   local  - Local dev version
    echo   test   - Test version
    echo   prod   - Production version
    echo   all    - Build all
    echo.
    echo Examples:
    echo   build-tauri.bat local
    echo   build-tauri.bat test
    echo   build-tauri.bat prod
    echo   build-tauri.bat all
    echo.
    exit /b 0

REM ========================================
REM 环境配置映射
REM ========================================
:get_env_config
    set "ENV_NAME=%~1"
    
    if "%ENV_NAME%"=="local" (
        set "APP_TITLE=LumenIM-Local"
        set "APP_ID=com.lumenim.desktop.local"
        set "PRODUCT_NAME=LumenIM-Local"
        set "API_URL=http://localhost:9501"
        set "WS_URL=ws://localhost:9502"
        set "CSP_ALLOW_HOSTS=http://localhost:*"
        set "CSP_ALLOW_WS=ws://localhost:* wss://localhost:*"
        set "DEBUG_MODE=true"
        set "LOG_LEVEL=debug"
        set "OUTPUT_DIR=release_local"
        set "VITE_MODE=development"
    ) else if "%ENV_NAME%"=="test" (
        set "APP_TITLE=LumenIM-Test"
        set "APP_ID=com.lumenim.desktop.test"
        set "PRODUCT_NAME=LumenIM-Test"
        set "API_URL=http://192.168.23.131:9501"
        set "WS_URL=ws://192.168.23.131:9502"
        set "CSP_ALLOW_HOSTS=http://localhost:* http://192.168.23.131:*"
        set "CSP_ALLOW_WS=ws://localhost:* wss://localhost:* ws://192.168.23.131:* wss://192.168.23.131:*"
        set "DEBUG_MODE=true"
        set "LOG_LEVEL=debug"
        set "OUTPUT_DIR=release_test"
        set "VITE_MODE=test"
    ) else if "%ENV_NAME%"=="prod" (
        set "APP_TITLE=LumenIM"
        set "APP_ID=com.lumenim.desktop"
        set "PRODUCT_NAME=LumenIM"
        set "API_URL=https://api.lumenim.com"
        set "WS_URL=wss://api.lumenim.com"
        set "CSP_ALLOW_HOSTS=https://api.lumenim.com https://*"
        set "CSP_ALLOW_WS=wss://api.lumenim.com:*"
        set "DEBUG_MODE=false"
        set "LOG_LEVEL=error"
        set "OUTPUT_DIR=release"
        set "VITE_MODE=production"
    ) else (
        exit /b 1
    )
    
    exit /b 0

REM ========================================
REM 生成环境配置文件
REM ========================================
:generate_env_file
    set "ENV=%~1"
    set "ENV_FILE=%PROJECT_ROOT%\.env.%ENV%"
    
    call :log_info "Generating env config: .env.%ENV%"
    
    (
        echo # LumenIM Env Config - %ENV%
        echo VITE_APP_ENV=%ENV%
        echo VITE_APP_TITLE=%APP_TITLE%
        echo VITE_BASE=/
        echo VITE_BASE_API=%API_URL%
        echo VITE_SOCKET_API=%WS_URL%
        echo VITE_ENABLE_DEBUG=%DEBUG_MODE%
        echo VITE_ENABLE_MOCK=false
        echo VITE_ENABLE_ANALYTICS=%DEBUG_MODE%
        echo VITE_LOG_LEVEL=%LOG_LEVEL%
    ) > "%ENV_FILE%"
    
    call :log_success "Env file created: %ENV_FILE%"
    exit /b 0

REM ========================================
REM 生成 Tauri 配置文件
REM ========================================
:generate_tauri_config
    set "ENV=%~1"
    set "CONFIG_FILE=%PROJECT_ROOT%\src-tauri\tauri.conf.%ENV%.json"
    
    call :log_info "Generating Tauri config: tauri.conf.%ENV%.json"
    
    (
        echo {
        echo   "$schema": "../../node_modules/@tauri-apps/cli/config.schema.json",
        echo   "productName": "%PRODUCT_NAME%",
        echo   "version": "1.0.0",
        echo   "identifier": "%APP_ID%",
        echo   "build": {
        echo     "frontendDist": "../dist",
        echo     "devUrl": "http://localhost:5173",
        echo     "beforeDevCommand": "npm run dev",
        echo     "beforeBuildCommand": ""
        echo   },
        echo   "app": {
        echo     "withGlobalTauri": true,
        echo     "windows": [
        echo       {
        echo         "title": "%APP_TITLE%",
        echo         "width": 1200,
        echo         "height": 800,
        echo         "minWidth": 800,
        echo         "minHeight": 600,
        echo         "resizable": true,
        echo         "fullscreen": false,
        echo         "center": true
        echo       }
        echo     ],
        echo     "security": {
        echo       "csp": "default-src 'self' %CSP_ALLOW_HOSTS%; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' data: blob: asset:; img-src 'self' data: blob: asset: %CSP_ALLOW_HOSTS%; font-src 'self' data:; connect-src 'self' ipc: %CSP_ALLOW_HOSTS% https://* %CSP_ALLOW_WS% ws://* wss://*; frame-src 'self' blob:; media-src 'self' blob: %CSP_ALLOW_HOSTS%; object-src 'self' blob:"
        echo     }
        echo   },
        echo   "bundle": {
        echo     "active": true,
        echo     "targets": ["nsis"],
        echo     "icon": [
        echo       "icons/32x32.png",
        echo       "icons/128x128.png",
        echo       "icons/128x128@2x.png",
        echo       "icons/icon.icns",
        echo       "icons/icon.ico"
        echo     ],
        echo     "windows": {
        echo       "nsis": {
        echo         "installMode": "currentUser"
        echo       }
        echo     }
        echo   }
        echo }
    ) > "%CONFIG_FILE%"
    
    call :log_success "Tauri config created: %CONFIG_FILE%"
    exit /b 0

REM ========================================
REM 复制配置文件到构建目录
REM ========================================
:prepare_build
    set "ENV=%~1"
    
    call :log_info "Preparing build: %ENV%"
    
    REM 复制 Tauri 配置
    set "SRC_TAURI_CONFIG=%PROJECT_ROOT%\src-tauri\tauri.conf.%ENV%.json"
    set "DST_TAURI_CONFIG=%PROJECT_ROOT%\src-tauri\tauri.conf.json"
    
    if exist "%SRC_TAURI_CONFIG%" (
        copy /y "%SRC_TAURI_CONFIG%" "%DST_TAURI_CONFIG%" >nul
        call :log_success "Tauri config applied: %ENV%"
    ) else (
        call :log_error "Tauri config not found: %SRC_TAURI_CONFIG%"
        exit /b 1
    )
    
    exit /b 0

REM ========================================
REM 构建前端
REM ========================================
:build_frontend
    call :log_info "Building frontend (mode: %VITE_MODE%)"
    
    cd /d "%PROJECT_ROOT%"
    
    call npm run build -- --mode %VITE_MODE%
    if errorlevel 1 (
        call :log_error "Frontend build failed"
        exit /b 1
    )
    
    call :log_success "Frontend build completed"
    exit /b 0

REM ========================================
REM 构建 Tauri 应用
REM ========================================
:build_tauri
    call :log_info "Building Tauri app"
    
    cd /d "%PROJECT_ROOT%"
    
    REM 清理旧构建
    if exist "src-tauri\target\%OUTPUT_DIR%" (
        call :log_info "Cleaning old build"
        rmdir /s /q "src-tauri\target\%OUTPUT_DIR%" 2>nul
    )
    
    call npx tauri build
    if errorlevel 1 (
        call :log_error "Tauri build failed"
        exit /b 1
    )
    
    call :log_success "Tauri build completed"
    exit /b 0

REM ========================================
REM 移动构建产物
REM ========================================
:move_artifacts
    call :log_info "Moving build artifacts"
    
    set "SRC_DIR=%PROJECT_ROOT%\src-tauri\target\release"
    set "DST_DIR=%PROJECT_ROOT%\src-tauri\target\%OUTPUT_DIR%"
    
    if not exist "%DST_DIR%" mkdir "%DST_DIR%"
    
    REM 复制可执行文件
    if exist "%SRC_DIR%\lumenim-desktop.exe" (
        copy /y "%SRC_DIR%\lumenim-desktop.exe" "%DST_DIR%\" >nul
    )
    
    REM 复制安装包
    if exist "%SRC_DIR%\bundle" (
        if not exist "%DST_DIR%\bundle" mkdir "%DST_DIR%\bundle"
        xcopy /y /e /i "%SRC_DIR%\bundle\*" "%DST_DIR%\bundle\" >nul
    )
    
    call :log_success "Artifacts moved to: %DST_DIR%"
    exit /b 0

REM ========================================
REM 构建单个环境
REM ========================================
:build_single_env
    set "ENV=%~1"
    
    echo.
    echo ========================================
    echo   Building: %ENV%
    echo ========================================
    
    call :log_info "========================================"
    call :log_info "Starting build: %ENV%"
    call :log_info "========================================"
    
    REM 获取环境配置
    call :get_env_config %ENV%
    if errorlevel 1 (
        call :log_error "Invalid env: %ENV%"
        exit /b 1
    )
    
    REM 生成配置文件
    call :generate_env_file %ENV%
    call :generate_tauri_config %ENV%
    
    REM 准备构建
    call :prepare_build %ENV%
    if errorlevel 1 exit /b 1
    
    REM 构建前端
    call :build_frontend
    if errorlevel 1 exit /b 1
    
    REM 构建 Tauri
    call :build_tauri
    if errorlevel 1 exit /b 1
    
    REM 移动产物
    call :move_artifacts
    
    call :log_success "Build completed: %ENV%"
    exit /b 0

REM ========================================
REM 显示构建结果
REM ========================================
:show_result
    set "ENV=%~1"
    
    echo.
    echo ========================================
    echo   %ENV% Build Result
    echo ========================================
    
    set "OUTPUT_DIR=%PROJECT_ROOT%\src-tauri\target\%OUTPUT_DIR%"
    
    if exist "%OUTPUT_DIR%\lumenim-desktop.exe" (
        echo   Executable: %OUTPUT_DIR%\lumenim-desktop.exe
        for %%F in ("%OUTPUT_DIR%\lumenim-desktop.exe") do echo   Size:       %%~zF bytes
    )
    
    if exist "%OUTPUT_DIR%\bundle\nsis" (
        for %%F in ("%OUTPUT_DIR%\bundle\nsis\*.exe") do (
            echo   Installer:   %%~nxF
            for %%S in ("%%~nxF") do echo   Size:       %%~zF bytes
        )
    )
    
    echo ========================================
    exit /b 0

REM ========================================
REM 主函数
REM ========================================
:main
    echo.
    echo ========================================
    echo   LumenIM Desktop Build Script
    echo   Build Mode: %BUILD_MODE%
    echo ========================================
    echo.

    REM 解析构建模式
    if /i "%BUILD_MODE%"=="help" goto :show_help
    if /i "%BUILD_MODE%"=="-h" goto :show_help
    if /i "%BUILD_MODE%"=="/?" goto :show_help
    
    if /i "%BUILD_MODE%"=="all" (
        call :build_single_env local
        if errorlevel 1 exit /b 1
        
        call :build_single_env test
        if errorlevel 1 exit /b 1
        
        call :build_single_env prod
        if errorlevel 1 exit /b 1
        
        echo.
        echo ========================================
        echo   All Builds Completed!
        echo ========================================
        echo.
        echo   Local:  src-tauri\target\release_local
        echo   Test:   src-tauri\target\release_test
        echo   Prod:   src-tauri\target\release
        echo ========================================
        
        call :log_success "All environments built"
        exit /b 0
    )
    
    REM 构建单个环境
    call :build_single_env %BUILD_MODE%
    if errorlevel 1 (
        call :log_error "Build failed: %BUILD_MODE%"
        echo.
        echo Build failed, see log: %LOG_FILE%
        exit /b 1
    )
    
    call :show_result %BUILD_MODE%
    
    echo.
    echo Build successful!
    echo Log: %LOG_FILE%
    echo ========================================
    
    call :log_success "Build completed: %BUILD_MODE%"
    exit /b 0
