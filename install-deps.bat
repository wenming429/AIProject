@echo off
chcp 65001 >nul
echo ========================================
echo  LumenIM 前端依赖安装脚本
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
    echo [OK] 使用 pnpm 包管理器
) else (
    where npm >nul 2>&1
    if %errorlevel% == 0 (
        set PKG_MGR=npm
        echo [OK] 使用 npm 包管理器
    ) else (
        echo [错误] 未检测到包管理器
        pause
        exit /b 1
    )
)
echo.

echo 正在安装前端依赖...
echo 这可能需要几分钟时间，请耐心等待...
echo.

%PKG_MGR% install

if errorlevel 1 (
    echo.
    echo [错误] 依赖安装失败
    echo 请检查网络连接或手动运行: cd front ^&^& %PKG_MGR% install
    pause
    exit /b 1
)

echo.
echo ========================================
echo  [成功] 依赖安装完成！
echo ========================================
echo.
echo 现在可以运行以下命令启动前端：
echo   - start-frontend.bat  : 仅启动前端
echo   - start-dev.bat       : 启动后端+前端
echo.
pause
