@echo off
chcp 65001 > nul
echo ========================================
echo   Lumen IM 后端启动脚本
echo ========================================
echo.

cd /d "d:\学习资料\AI_Projects\LumenIM\backend"

REM 检查配置文件是否存在
if not exist "config.yaml" (
    echo [错误] 配置文件 config.yaml 不存在！
    echo 请先编辑 config.yaml 配置数据库密码
    pause
    exit /b 1
)

REM 设置 Go 环境变量
set GOPROXY=https://goproxy.cn,direct
set GOROOT=C:\Go
set PATH=%GOROOT%\bin;%PATH%

echo [1/4] 启动 HTTP 服务 (端口 9501)...
start "LumenIM-HTTP" cmd /k "cd /d "d:\学习资料\AI_Projects\LumenIM\backend" && lumenim.exe http"

timeout /t 2 /nobreak > nul

echo [2/4] 启动 WebSocket 服务 (端口 9502)...
start "LumenIM-Comet" cmd /k "cd /d "d:\学习资料\AI_Projects\LumenIM\backend" && lumenim.exe comet"

timeout /t 2 /nobreak > nul

echo [3/4] 启动队列服务...
start "LumenIM-Queue" cmd /k "cd /d "d:\学习资料\AI_Projects\LumenIM\backend" && lumenim.exe queue"

timeout /t 2 /nobreak > nul

echo [4/4] 启动定时任务服务...
start "LumenIM-Cron" cmd /k "cd /d "d:\学习资料\AI_Projects\LumenIM\backend" && lumenim.exe crontab"

echo.
echo ========================================
echo   后端服务已启动！
echo ========================================
echo.
echo HTTP API:  http://127.0.0.1:9501
echo WebSocket: ws://127.0.0.1:9502
echo.
echo 请按任意键打开前端开发服务器...
pause > nul

REM 启动前端
cd /d "d:\学习资料\AI_Projects\LumenIM\front"
start "LumenIM-Frontend" cmd /k "pnpm dev"
