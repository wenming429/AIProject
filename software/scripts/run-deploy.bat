@echo off
REM ============================================================================
REM LumenIM 一键部署脚本 (Windows)
REM 版本: 1.0.0
REM 日期: 2026-04-09
REM ============================================================================

echo ========================================
echo   LumenIM 打包与部署
echo ========================================
echo.

REM 检查 PowerShell
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 PowerShell，请使用 PowerShell 执行 build-deploy.ps1
    pause
    exit /b 1
)

REM 设置默认参数
set SERVER_IP=192.168.23.131
set SERVER_USER=root
set SERVER_PORT=22
set MODE=

REM 解析参数
:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="--deploy" set MODE=--deploy& shift & goto :parse_args
if /i "%~1"=="--upload" set MODE=--upload& shift & goto :parse_args
if /i "%~1"=="--build-only" set MODE=--build-only& shift & goto :parse_args
if /i "%~1"=="--rollback" set MODE=--rollback& shift & goto :parse_args
if /i "%~1"=="--skip-backup" set MODE=%MODE% --skip-backup& shift & goto :parse_args
if /i "%~1"=="--verbose" set MODE=%MODE% --verbose& shift & goto :parse_args
if /i "%~1"=="--server-ip" (
    set SERVER_IP=%~2
    shift & shift & goto :parse_args
)
if /i "%~1"=="--server-user" (
    set SERVER_USER=%~2
    shift & shift & goto :parse_args
)
if /i "%~1"=="--server-port" (
    set SERVER_PORT=%~2
    shift & shift & goto :parse_args
)
shift
goto :parse_args

:done_args
if "%MODE%"=="" set MODE=--build-only

REM 执行 PowerShell 脚本
echo [信息] 执行部署脚本...
echo [信息] 服务器: %SERVER_IP%:%SERVER_PORT%
echo [信息] 用户: %SERVER_USER%
echo [信息] 模式: %MODE%
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0build-deploy.ps1" %MODE% --server-ip=%SERVER_IP% --server-user=%SERVER_USER% --server-port=%SERVER_PORT%

if %errorlevel% neq 0 (
    echo.
    echo [错误] 部署失败，退出码: %errorlevel%
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================
echo   部署完成
echo ========================================
pause
exit /b 0

:show_help
echo.
echo 用法: run-deploy.bat [选项]
echo.
echo 选项:
echo   --deploy           完整部署
echo   --upload           打包并上传
echo   --build-only       仅打包（默认）
echo   --rollback         回滚到上一版本
echo   --skip-backup      跳过备份
echo   --verbose          详细输出
echo.
echo   --server-ip=IP     服务器 IP（默认: 192.168.23.131）
echo   --server-user=USER SSH 用户（默认: root）
echo   --server-port=PORT SSH 端口（默认: 22）
echo.
echo 示例:
echo   run-deploy.bat --build-only
echo   run-deploy.bat --upload --server-ip=192.168.23.131
echo   run-deploy.bat --deploy --server-ip=192.168.23.131 --server-user=root
echo.
pause
