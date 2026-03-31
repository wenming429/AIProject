@echo off
chcp 65001 >nul
echo ========================================
echo  LumenIM 补充安装脚本
echo ========================================
echo.

echo [步骤1] 检查Redis安装状态...
where redis-server >nul 2>&1
if %errorlevel% equ 0 (
    echo   Redis 已安装
) else (
    echo   Redis 未安装，需要安装 Memurai (Redis Windows兼容版)
    echo.
    echo   请访问: https://www.memurai.com/get-memurai
    echo   下载 Memurai Developer Edition 并安装
    echo.
    echo   或使用 winget (管理员PowerShell):
    echo   winget install Memurai.MemuraiDeveloper --accept-source-agreements --accept-package-agreements
    echo.
)

echo.
echo [步骤2] 安装Memurai后，启动Redis服务...
sc query Memuraiv4 >nul 2>&1
if %errorlevel% equ 0 (
    echo   Memurai 服务已安装
    echo   启动服务...
    net start Memuraiv4
) else (
    echo   Memurai 服务未安装，请先安装
)

echo.
echo [步骤3] 验证Redis连接...
redis-cli ping 2>nul
if %errorlevel% equ 0 (
    echo   Redis 连接成功！
) else (
    echo   Redis 连接失败，请检查服务状态
)

echo.
echo [步骤4] 启动后端服务...
cd /d "%~dp0backend"

echo   启动HTTP服务...
start "LumenIM-HTTP" cmd /k "lumenim.exe http"

echo   启动WebSocket服务...
start "LumenIM-Comet" cmd /k "lumenim.exe comet"

echo   启动消息队列服务...
start "LumenIM-Queue" cmd /k "lumenim.exe queue"

echo.
echo ========================================
echo  请确保MinIO正在运行 (端口9000)
echo  然后启动前端: cd front ^&^& pnpm dev
echo ========================================
echo.
pause
