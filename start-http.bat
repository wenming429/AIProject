@echo off
chcp 65001 >nul
cd /d "%~dp0backend"

echo 启动后端 HTTP 服务...
start "LumenIM-HTTP" cmd /k "lumenim.exe http"
