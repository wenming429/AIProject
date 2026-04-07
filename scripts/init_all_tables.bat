@echo off
chcp 65001 >nul
echo.
echo ╔══════════════════════════════════════════════════════════╗
echo ║         LumenIM 数据库核心表一键初始化                   ║
echo ╚══════════════════════════════════════════════════════════╝
echo.
echo 执行顺序:
echo   1. users (用户表)
echo   2. organize_dept (部门表)
echo   3. organize_position (岗位表)
echo   4. organize (组织关系表)
echo.
echo 提示: 如果需要取消，请按 Ctrl+C
echo.
pause

echo.
echo 正在启动初始化脚本...
echo.

cd /d "%~dp0"

:: 检查 Node.js 是否安装
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js
    pause
    exit /b 1
)

:: 执行初始化脚本
node init_all_tables.js

if %errorlevel% equ 0 (
    echo.
    echo ══════════════════════════════════════════════════════
    echo           初始化完成! 按任意键退出...
    echo ══════════════════════════════════════════════════════
    pause >nul
) else (
    echo.
    echo [错误] 初始化过程中出现错误，请检查上方日志
    pause
)

