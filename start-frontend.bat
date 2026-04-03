@echo off
chcp 65001 >nul
echo ========================================
echo  LumenIM 前端开发服务器启动脚本
echo ========================================
echo.

cd /d "%~dp0front"

echo 检查 Node.js 环境...
node --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js
    echo 下载地址: https://nodejs.org/
    pause
    exit /b 1
)

echo Node.js 版本:
node --version
echo.

echo 检查包管理器...
where pnpm >nul 2>&1
if %errorlevel% == 0 (
    set PKG_MGR=pnpm
    echo 使用 pnpm 包管理器
) else (
    where npm >nul 2>&1
    if %errorlevel% == 0 (
        set PKG_MGR=npm
        echo 使用 npm 包管理器
    ) else (
        echo [错误] 未检测到包管理器，请安装 npm 或 pnpm
        pause
        exit /b 1
    )
)
echo.

echo 检查依赖是否安装...
if not exist "node_modules" (
    echo [提示] 未检测到 node_modules，正在安装依赖...
    echo 这可能需要几分钟时间...
    echo.
    %PKG_MGR% install
    if errorlevel 1 (
        echo [错误] 依赖安装失败
        pause
        exit /b 1
    )
    echo [成功] 依赖安装完成
    echo.
)

echo ========================================
echo  正在启动前端开发服务器...
echo ========================================
echo.
echo 访问地址: http://localhost:5173
echo.
echo 快捷键:
echo   - 按 Ctrl+C 停止服务器
echo   - 按 O 键在浏览器中打开
echo.
echo ========================================
echo.

%PKG_MGR% run dev

echo.
echo 服务器已停止
echo.
pause
