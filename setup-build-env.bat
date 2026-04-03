@echo off
chcp 65001 >nul
title LumenIM 构建环境配置工具

echo ===================================================
echo    LumenIM PC版构建环境配置
echo ===================================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 建议以管理员身份运行以获得最佳体验
    echo.
    pause
)

echo [步骤 1/5] 检查系统环境...
echo 操作系统: %OS%
echo 处理器架构: %PROCESSOR_ARCHITECTURE%
echo.

:: 检查Node.js
echo [步骤 2/5] 检查 Node.js...
where node >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%a in ('node -v') do echo [信息] Node.js 版本: %%a
    
    :: 检查版本号
    node -e "const v = process.version.slice(1).split('.'); if(parseInt(v[0]) < 18) process.exit(1)"
    if %errorlevel% neq 0 (
        echo [警告] Node.js 版本过低，建议升级到 18.x 或更高版本
        echo 下载地址: https://nodejs.org/
    )
) else (
    echo [信息] 未检测到 Node.js，正在引导安装...
    echo.
    echo 请访问 https://nodejs.org/ 下载并安装 Node.js 18.x LTS 版本
    echo 安装完成后重新运行此脚本
    start https://nodejs.org/
    pause
    exit /b 1
)
echo.

:: 检查pnpm
echo [步骤 3/5] 检查 pnpm...
where pnpm >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%a in ('pnpm -v') do echo [信息] pnpm 版本: %%a
) else (
    echo [信息] 正在安装 pnpm...
    npm install -g pnpm
    if %errorlevel% neq 0 (
        echo [错误] pnpm 安装失败，请手动运行: npm install -g pnpm
        pause
        exit /b 1
    )
    echo [成功] pnpm 安装完成
)
echo.

:: 检查Git
echo [步骤 4/5] 检查 Git...
where git >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%a in ('git --version') do echo [信息] %%a
) else (
    echo [警告] 未检测到 Git，建议安装以便更新代码
    echo 下载地址: https://git-scm.com/
)
echo.

:: 安装依赖
echo [步骤 5/5] 安装项目依赖...
cd /d "%~dp0front"
echo 工作目录: %cd%
echo.

if exist "node_modules" (
    echo [信息] 检测到已存在的 node_modules
    set /p reinstall="是否重新安装依赖? (y/N): "
    if /i "!reinstall!"=="y" (
        echo [信息] 删除旧依赖...
        rmdir /s /q node_modules
        del package-lock.json 2>nul
        del pnpm-lock.yaml 2>nul
    ) else (
        goto skip_install
    )
)

echo [信息] 正在安装依赖，请耐心等待...
call pnpm install
if %errorlevel% neq 0 (
    echo [错误] 依赖安装失败，请检查网络连接
    pause
    exit /b 1
)
echo [成功] 依赖安装完成

:skip_install
echo.
echo ===================================================
echo    环境配置完成！
echo ===================================================
echo.
echo 现在可以运行以下命令：
echo.
echo   开发模式:     pnpm run electron:dev
echo   构建Windows:  pnpm run electron:build:win
echo   构建所有:     pnpm run electron:build:all
echo.
echo 或运行自动构建脚本：
echo   ..\\build-pc-app.bat
echo.
pause
