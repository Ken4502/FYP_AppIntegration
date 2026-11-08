@echo off
title PhytoCare AI - Online Diagnostic Server (Cloudflare Tunnel)
echo =======================================================================
echo          Starting PhytoCare AI Online Diagnostic Server
echo =======================================================================
echo.
cd /d "%~dp0"
CoreTech\.venv\Scripts\python.exe start_online_tunnel.py
if %errorlevel% neq 0 (
    echo.
    echo [!] Server exited with an error. Falling back to system python...
    python start_online_tunnel.py
)
echo.
pause
