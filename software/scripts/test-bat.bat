@echo off
echo Testing script path resolution
echo.
echo SCRIPT_DIR=%~dp0
echo.
set "SCRIPT_DIR=%~dp0"
echo SCRIPT_DIR=%SCRIPT_DIR%
echo.
set "PROJECT_ROOT=%SCRIPT_DIR%..\front"
echo PROJECT_ROOT=%PROJECT_ROOT%
echo.
echo Testing directory listing:
if exist "%PROJECT_ROOT%" (
    echo [OK] Project root exists
    dir "%PROJECT_ROOT%" /b | findstr /i "package"
) else (
    echo [FAIL] Project root does not exist
)
echo.
pause
