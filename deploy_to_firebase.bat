@echo off
title Deploy PhytoCare AI to Firebase (urbangreenfyp)
echo =======================================================================
echo          Deploy PhytoCare AI to Firebase / Google Cloud Run
echo          Project: urbangreenfyp
echo =======================================================================
echo.
cd /d "%~dp0CoreTech"
call deploy_to_firebase.bat

