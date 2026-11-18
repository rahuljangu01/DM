@echo off
title DM Lace Surat - APK Builder
color 0A
echo ========================================================
echo         DM LACE SURAT - RELEASE APK BUILDER
echo ========================================================
echo.
echo [1/3] Navigating to project directory...
cd /d "D:\DM"

echo [2/3] Building Release APK (Please wait 1-2 minutes)...
echo.
call flutter build apk --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] APK build me koi dikkat aayi!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] APK Successfully Built!
echo ========================================================
echo APK File Location:
echo D:\DM\build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
echo.
echo Opening APK folder...
explorer "D:\DM\build\app\outputs\flutter-apk"

pause
