@echo off
chcp 65001 >nul
title LumenIM PC版构建工具

:: 设置颜色
color 0A

echo ===================================================
echo    LumenIM 桌面客户端构建工具
echo ===================================================
echo.

:: 检查Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到Node.js，请先安装Node.js 18+
    echo 下载地址: https://nodejs.org/
    pause
    exit /b 1
)

for /f "tokens=*" %%a in ('node -v') do set NODE_VERSION=%%a
echo [信息] Node.js版本: %NODE_VERSION%

:: 检查pnpm
where pnpm >nul 2>nul
if %errorlevel% neq 0 (
    echo [信息] 正在安装pnpm...
    npm install -g pnpm
)

for /f "tokens=*" %%a in ('pnpm -v') do set PNPM_VERSION=%%a
echo [信息] pnpm版本: %PNPM_VERSION%

echo.
echo ===================================================
echo    选择构建模式
echo ===================================================
echo.
echo [1] 开发模式 (热重载，用于调试)
echo [2] 构建Windows安装包 (NSIS)
echo [3] 构建Windows便携版 (Portable)
echo [4] 构建所有Windows版本
echo [5] 仅构建前端 (不打包Electron)
echo [0] 退出
echo.

set /p choice="请输入选项 [0-5]: "

if "%choice%"=="1" goto dev
if "%choice%"=="2" goto build_nsis
if "%choice%"=="3" goto build_portable
if "%choice%"=="4" goto build_all
if "%choice%"=="5" goto build_web
if "%choice%"=="0" goto exit
goto invalid

:dev
echo.
echo [信息] 启动开发模式...
cd /d "%~dp0front"
call pnpm install
call pnpm run electron:dev
pause
goto menu

:build_nsis
echo.
echo [信息] 开始构建Windows安装包...
cd /d "%~dp0front"

echo [步骤 1/3] 安装依赖...
call pnpm install
if %errorlevel% neq 0 (
    echo [错误] 依赖安装失败
    pause
    exit /b 1
)

echo [步骤 2/3] 构建前端...
call pnpm run build:electron
if %errorlevel% neq 0 (
    echo [错误] 前端构建失败
    pause
    exit /b 1
)

echo [步骤 3/3] 打包Electron应用...
call pnpm run electron:build:win
if %errorlevel% neq 0 (
    echo [错误] Electron打包失败
    pause
    exit /b 1
)

echo.
echo ===================================================
echo    构建完成！
echo ===================================================
echo 安装包位置: %~dp0front\release\
echo.
dir /b "%~dp0front\release\*.exe" 2>nul
echo.
pause
goto menu

:build_portable
echo.
echo [信息] 开始构建Windows便携版...
cd /d "%~dp0front"

echo [步骤 1/3] 安装依赖...
call pnpm install

echo [步骤 2/3] 构建前端...
call pnpm run build:electron

echo [步骤 3/3] 打包便携版...
call pnpm electron-builder --config electron-builder.json --win portable

echo.
echo ===================================================
echo    便携版构建完成！
echo ===================================================
echo 文件位置: %~dp0front\release\
dir /b "%~dp0front\release\*.exe" 2>nul
pause
goto menu

:build_all
echo.
echo [信息] 开始构建所有Windows版本...
cd /d "%~dp0front"

echo [步骤 1/3] 安装依赖...
call pnpm install

echo [步骤 2/3] 构建前端...
call pnpm run build:electron

echo [步骤 3/3] 打包所有版本...
call pnpm electron-builder --config electron-builder.json --win

echo.
echo ===================================================
echo    所有版本构建完成！
echo ===================================================
echo 文件位置: %~dp0front\release\
echo.
dir /b "%~dp0front\release\*.*" 2>nul
echo.
pause
goto menu

:build_web
echo.
echo [信息] 仅构建前端应用...
cd /d "%~dp0front"

echo [步骤 1/2] 安装依赖...
call pnpm install

echo [步骤 2/2] 构建前端...
call pnpm run build

echo.
echo ===================================================
echo    前端构建完成！
echo ===================================================
echo 输出位置: %~dp0front\dist\
pause
goto menu

:invalid
echo.
echo [错误] 无效选项，请重新选择
pause
goto menu

:exit
echo.
echo 感谢使用 LumenIM 构建工具！
timeout /t 2 >nul
exit /b 0

:menu
cls
goto start
