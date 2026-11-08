@echo off
title Start PhytoCare AI Backend Server
echo =======================================================================
echo          Starting FYP CoreTech AI Diagnostic Backend
echo =======================================================================
echo.
echo [*] Changing directory to CoreTech...
cd /d "%~dp0CoreTech"
echo [*] Executing CoreTech startup sequence...
call start.bat %*
if %errorlevel% neq 0 (
    echo.
    echo [!] Server exited or failed to start.
)
echo.
pause
