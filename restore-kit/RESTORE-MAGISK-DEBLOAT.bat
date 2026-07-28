@echo off
setlocal enabledelayedexpansion
title S688LN - RESTORE via disabling a Magisk debloat module (root)
echo ============================================================
echo   MAGISK DEBLOAT RESTORE   itel S688LN
echo ------------------------------------------------------------
echo   Use this ONLY if apps are still missing after STEP-2 + reboot.
echo   Some de-skin setups hide apps with a Magisk module that mounts
echo   an empty folder over them. install-existing cannot see those.
echo   This script lists your Magisk modules and lets you DISABLE one
echo   (reversible: it just drops a 'disable' flag file). Needs root.
echo ============================================================
echo.

set ADB=platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb.exe
"%ADB%" version >nul 2>&1
if errorlevel 1 ( echo [FAIL] adb.exe not found next to platform-tools. & pause & exit /b 1 )

echo Waiting for the phone...
"%ADB%" wait-for-device

echo Checking for root (Magisk su)...
for /f "delims=" %%r in ('"%ADB%" shell "su -c id 2>/dev/null"') do set ROOT=%%r
echo %ROOT% | find /i "uid=0" >nul
if errorlevel 1 (
    echo [FAIL] No root shell. On the phone, approve the Superuser request
    echo        popup when it appears, then re-run. (Magisk required.)
    pause & exit /b 1
)
echo [OK] Root granted.
echo.

echo Your installed Magisk modules:
echo ------------------------------------------------------------
"%ADB%" shell "su -c 'for m in /data/adb/modules/*/; do n=$(basename $m); st=enabled; [ -f ${m}disable ] && st=DISABLED; nm=$(grep -m1 ^name= ${m}module.prop 2>/dev/null | cut -d= -f2); echo \"$n  [$st]  $nm\"; done'"
echo ------------------------------------------------------------
echo.
echo Look for a debloater (names like: debloat, deskin, remove-apps, terminator).
set MOD=
set /p MOD=Type the module FOLDER name to DISABLE (or just press ENTER to cancel): 
if "%MOD%"=="" ( echo Cancelled. No change made. & pause & exit /b 0 )

"%ADB%" shell "su -c 'test -d /data/adb/modules/%MOD%'"
if errorlevel 1 ( echo [FAIL] No module folder named "%MOD%". & pause & exit /b 1 )

echo Disabling module: %MOD%
"%ADB%" shell "su -c 'touch /data/adb/modules/%MOD%/disable'"
echo [OK] Flagged disabled. This is reversible: delete that 'disable' file to re-enable.
echo.
choice /m "Reboot now to apply (required)"
if not errorlevel 2 (
    echo Rebooting...
    "%ADB%" reboot
    echo After it boots, run STEP-2-RESTORE-ALL.bat again (the apps are now
    echo visible to PackageManager), then STEP-3-VERIFY.bat.
)
echo.
pause
endlocal
