@echo off
setlocal enabledelayedexpansion
title S688LN - STEP 2 - RESTORE ALL SYSTEM APPS
echo ============================================================
echo   STEP 2 - RESTORE ALL   itel S688LN system-app restore kit
echo ------------------------------------------------------------
echo   Re-enables every disabled app and re-installs every hidden
echo   stock system app for your user. No reset. No flashing.
echo   Only PackageManager is used (install-existing / enable).
echo   Safe + idempotent: you can run this more than once.
echo ============================================================
echo.

set ADB=platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb.exe
"%ADB%" version >nul 2>&1
if errorlevel 1 (
    echo [FAIL] adb.exe not found. Keep this .bat NEXT TO the platform-tools folder.
    pause & exit /b 1
)

echo Waiting for the phone...
"%ADB%" wait-for-device
set MODEL=
for /f "delims=" %%i in ('"%ADB%" shell getprop ro.product.model') do set MODEL=%%i
if "%MODEL%"=="" (
    echo [WARN] Phone not answering - unlock it and accept the USB debugging popup, then re-run.
    pause & exit /b 1
)
echo Found device: %MODEL%
echo.
choice /m "Proceed to restore all stock system apps now"
if errorlevel 2 exit /b 1
echo.

rem --- Which user? default 0 (main profile) ---
set USER=0

echo [1/3] Re-enabling all DISABLED apps (user %USER%)...
rem Runs the loop ON THE DEVICE to avoid Windows line-ending / parsing issues.
"%ADB%" shell "for p in $(pm list packages -d | cut -d: -f2); do pm enable $p >/dev/null 2>&1 && echo enabled:$p; done"

echo.
echo [2/3] Re-installing all HIDDEN stock system apps (user %USER%)...
rem install-existing is idempotent: already-installed pkgs just report installed.
"%ADB%" shell "for p in $(cmd package list packages -u -s | cut -d: -f2); do cmd package install-existing --user %USER% $p 2>/dev/null | grep -qi installed && echo ok:$p; done"

echo.
echo [3/3] Re-scanning to confirm...
set /a LEFT=0
for /f %%c in ('"%ADB%" shell "pm list packages -d ^| wc -l"') do set DISLEFT=%%c
echo Disabled apps remaining: !DISLEFT!

echo.
echo ============================================================
echo   DONE. Now REBOOT the phone once so the launcher and app
echo   drawer refresh:   (or just power-cycle it)
echo ============================================================
choice /m "Reboot the phone now"
if not errorlevel 2 (
    echo Rebooting...
    "%ADB%" reboot
)
echo.
echo After it boots, run STEP-3-VERIFY.bat to confirm everything is back.
echo If a few apps are STILL missing, they were hidden by a Magisk module
echo -> run RESTORE-MAGISK-DEBLOAT.bat (needs root).
echo.
pause
endlocal
