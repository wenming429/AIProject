@echo off
chcp 65001 >nul
echo ========================================
echo  LumenIM 开发环境一键启动脚本
echo ========================================
echo.

set BACKEND_DIR=%~dp0backend
set FRONTEND_DIR=%~dp0front

echo 检查 Node.js 环境...
node --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js
    echo 下载地址: https://nodejs.org/
    pause
    exit /b 1
)
echo [OK] Node.js 已安装
echo.

echo 检查后端服务...
if not exist "%BACKEND_DIR%\lumenim.exe" (
    echo [错误] 未找到后端可执行文件: %BACKEND_DIR%\lumenim.exe
    echo 请先编译后端服务
    pause
    exit /b 1
)
echo [OK] 后端服务已就绪
echo.

echo 检查前端依赖...
if not exist "%FRONTEND_DIR%\node_modules" (
    echo [提示] 前端依赖未安装，请先运行 install-deps.bat 安装依赖
    echo.
)

echo ========================================
echo  正在启动服务...
echo ========================================
echo.

cd /d "%BACKEND_DIR%"

echo [1/4] 启动 MinIO 对象存储服务...
start "MinIO" cmd /k "minio.exe server data --console-address "":9090""
echo 等待 MinIO 启动...
timeout /t 3 /nobreak >nul
echo [OK] MinIO 已启动
echo.

echo [2/4] 配置 MinIO Bucket...
mc alias set local http://localhost:9000 minioadmin minioadmin123 >nul 2>&1
mc mb local/im-static --ignore-existing >nul 2>&1
mc mb local/im-private --ignore-existing >nul 2>&1
mc anonymous set public local/im-static >nul 2>&1
echo [OK] MinIO Bucket 配置完成
echo.

echo [3/4] 启动后端 HTTP 服务...
start "LumenIM-HTTP" cmd /k "lumenim.exe http"
echo [OK] HTTP 服务已启动
echo.

echo [4/4] 启动 WebSocket 长连接服务...
start "LumenIM-Comet" cmd /k "lumenim.exe comet"
echo [OK] WebSocket 服务已启动
echo.

echo ========================================
echo  后端服务启动完成！
echo ========================================
echo.
echo 后端服务地址:
echo   - 后端 API:   http://localhost:9501
echo   - WebSocket: ws://localhost:9502
echo   - MinIO:     http://localhost:9000
echo   - MinIO控制台: http://localhost:9090
echo.
echo 默认账号: 13800000001 / admin123
echo.

:: 启动前端
cd /d "%FRONTEND_DIR%"

echo 检查包管理器...
where pnpm >nul 2>&1
if %errorlevel% == 0 (
    set PKG_MGR=pnpm
    echo 使用 pnpm
) else (
    set PKG_MGR=npm
    echo 使用 npm
)

echo.
echo ========================================
echo  正在启动前端开发服务器...
echo ========================================
echo.
echo 前端访问地址: http://localhost:5173
echo.

%PKG_MGR% run dev

echo.
echo 前端服务器已停止
echo.
pause
