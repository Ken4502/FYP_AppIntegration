@echo off
setlocal enabledelayedexpansion
title Deploy PhytoCare AI to Firebase Cloud Run (urbangreenfyp)
echo =======================================================================
echo     Deploying PhytoCare AI CoreTech to Firebase / Google Cloud Run
echo     Target Project: urbangreenfyp
echo =======================================================================
echo.

:: 1. Ensure gcloud is found on PATH or via LocalAppData
where gcloud >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" (
        set "PATH=%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin;!PATH!"
        echo [*] Located Google Cloud SDK in LocalAppData.
    ) else (
        echo [ERROR] 'gcloud' was not found on your system PATH!
        echo Please restart your terminal or ensure Google Cloud SDK is installed.
        echo.
        pause
        exit /b 1
    )
)

:: 2. Check active auth
echo [*] Checking Google Cloud authentication...
call gcloud auth print-access-token >nul 2>nul
if %errorlevel% neq 0 (
    echo [*] Logging into Google Cloud (your Firebase account)...
    call gcloud auth login
)

:: 3. Set Project
echo [*] Setting Google Cloud project to urbangreenfyp...
call gcloud config set project urbangreenfyp

:: 4. Enable Required Google Cloud APIs
echo [*] Enabling Cloud Run, Cloud Build, and Artifact Registry APIs...
call gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

:: 5. Deploy Container to Cloud Run
echo.
echo [*] Packaging and deploying CoreTech AI container to Cloud Run...
echo [*] This will take 2-4 minutes while Google Cloud builds the container.
echo.
call gcloud run deploy phytonet-ai ^
  --source . ^
  --platform managed ^
  --region us-central1 ^
  --allow-unauthenticated ^
  --memory 2Gi ^
  --cpu 2

if %errorlevel% equ 0 (
    echo.
    echo =======================================================================
    echo [SUCCESS] Your AI model is now live on Google Cloud / Firebase!
    echo Copy the Service URL printed above and paste it into your Flutter app.
    echo =======================================================================
) else (
    echo.
    echo [!] Deployment encountered an issue.
    echo Please make sure your Firebase project 'urbangreenfyp' has Blaze billing enabled
    echo at: https://console.firebase.google.com/project/urbangreenfyp/usage/details
)

echo.
pause
