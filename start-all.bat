@echo off
chcp 65001 >nul
echo ========================================
echo  LumenIM 服务启动脚本
echo ========================================
echo.

cd /d "%~dp0backend"

echo [1/5] 启动 MinIO 对象存储服务...
start "MinIO" cmd /k "minio.exe server data --console-address ":9090""

echo 等待 MinIO 启动...
timeout /t 3 /nobreak >nul

echo.
echo [2/5] 配置 MinIO Bucket...
mc alias set local http://localhost:9000 minioadmin minioadmin123
mc mb local/im-static --ignore-existing
mc mb local/im-private --ignore-existing
mc anonymous set public local/im-static

echo.
echo [3/5] 启动后端 HTTP 服务...
start "LumenIM-HTTP" cmd /k "lumenim.exe http"

echo.
echo [4/5] 启动 WebSocket 长连接服务...
start "LumenIM-Comet" cmd /k "lumenim.exe comet"

echo.
echo [5/5] 启动消息队列服务...
start "LumenIM-Queue" cmd /k "lumenim.exe queue"

echo.
echo ========================================
echo  所有服务已启动！
echo ========================================
echo.
echo 服务地址:
echo   - 后端 API:   http://localhost:9501
echo   - WebSocket: ws://localhost:9502
echo   - MinIO:     http://localhost:9000
echo   - MinIO控制台: http://localhost:9090
echo.
echo 默认账号: 13800000001 / admin123
echo.
echo 请手动启动前端: cd front ^&^& pnpm dev
echo.
pause
