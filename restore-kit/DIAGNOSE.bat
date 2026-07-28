@echo off
setlocal enabledelayedexpansion
title S688LN - DIAGNOSE (read-only) - collect app inventory for analysis
echo ============================================================
echo   DIAGNOSE   itel S688LN system-app restore kit
echo ------------------------------------------------------------
echo   READ-ONLY. Collects a full app inventory so the exact
echo   restore plan can be generated from the logs:
echo     - installed / disabled / hidden (uninstalled-for-user)
echo     - packages whose APK FILE IS GONE (root-deleted)
echo     - Magisk modules (to spot systemless debloat masks)
echo   Result: one zip file -> send it back for analysis.
echo ============================================================
echo.
echo  Phone: plugged in, screen UNLOCKED, USB debugging ON.
echo  If a "Superuser request" popup appears, tap GRANT (optional,
echo  only used to LIST Magisk modules - nothing is changed).
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
    echo [WARN] Phone not answering - accept the USB debugging popup, then re-run.
    pause & exit /b 1
)
echo Found device: %MODEL%
echo.

if exist diagnostics rmdir /s /q diagnostics
mkdir diagnostics
set D=diagnostics

echo [1/8] Device identity...
> "%D%\00_device.txt" echo ==== S688LN DIAGNOSE  %date% %time% ====
"%ADB%" shell getprop ro.product.model               >> "%D%\00_device.txt"
"%ADB%" shell getprop ro.build.fingerprint           >> "%D%\00_device.txt"
"%ADB%" shell getprop ro.build.display.id            >> "%D%\00_device.txt"
"%ADB%" shell getprop ro.build.version.security_patch>> "%D%\00_device.txt"
"%ADB%" shell pm list users                          >> "%D%\00_device.txt"

echo [2/8] Package lists (all variants)...
"%ADB%" shell "cmd package list packages -u    | cut -d: -f2" > "%D%\01_all_known.txt"
"%ADB%" shell "pm list packages                | cut -d: -f2" > "%D%\02_installed.txt"
"%ADB%" shell "pm list packages -s             | cut -d: -f2" > "%D%\03_installed_system.txt"
"%ADB%" shell "cmd package list packages -u -s | cut -d: -f2" > "%D%\04_all_system.txt"
"%ADB%" shell "pm list packages -d             | cut -d: -f2" > "%D%\05_disabled.txt"
"%ADB%" shell "pm list packages -3             | cut -d: -f2" > "%D%\06_user_apps.txt"

echo [3/8] Package paths (APK locations)...
"%ADB%" shell "cmd package list packages -u -f" > "%D%\07_paths.txt"

echo [4/8] Checking for packages whose APK file is GONE (root-deleted)...
rem Runs on the device: for every package PMS knows (incl. hidden), test
rem whether its codePath still exists on disk.
rem v1.2 fix: codePaths under /data/app contain '=' padding (base64 dirs), so
rem cut the ':pkg' off the END (last '='), never truncate the path at the first '='.
"%ADB%" shell "cmd package list packages -u -f | while read l; do l=${l#package:}; p=${l##*=}; f=${l%%%%=$p}; [ -e \"$f\" ] || echo MISSING_FILE:$p:$f; done" > "%D%\08_missing_files.txt"

echo [5/8] Listing stock app directories on disk...
"%ADB%" shell "ls -1 /system/app /system/priv-app /product/app /product/priv-app /product/operator/app /system_ext/app /system_ext/priv-app /vendor/app 2>/dev/null" > "%D%\09_app_dirs.txt"

echo [6/8] Overlay / enabled-state detail (safe, read-only)...
"%ADB%" shell "pm list packages -e | cut -d: -f2" > "%D%\10_enabled.txt"

echo [7/8] Magisk modules (optional - needs root; grant the popup if asked)...
"%ADB%" shell "su -c 'for m in /data/adb/modules/*/; do n=$(basename $m); st=enabled; [ -f ${m}disable ] && st=DISABLED; nm=$(grep -m1 ^name= ${m}module.prop 2>/dev/null | cut -d= -f2); echo \"$n [$st] $nm\"; done' 2>/dev/null" > "%D%\11_magisk_modules.txt"
"%ADB%" shell "su -c 'find /data/adb/modules -maxdepth 4 \( -name .replace -o -path *system/app* -o -path *system/priv-app* -o -path *product/app* \) 2>/dev/null'" > "%D%\12_magisk_masks.txt"
"%ADB%" shell "su -c 'debloat status' 2>/dev/null" > "%D%\13_debloat_status.txt"

echo [8/8] Zipping...
powershell -NoProfile -Command "Compress-Archive -Path 'diagnostics\*' -DestinationPath 'S688LN-diagnostics.zip' -Force"

set /a NHID=0, NDIS=0, NMISS=0
powershell -NoProfile -Command "$i=@(Get-Content '%D%\03_installed_system.txt' -EA SilentlyContinue); $a=@(Get-Content '%D%\04_all_system.txt' -EA SilentlyContinue); $d=Compare-Object $i $a | ?{$_.SideIndicator -eq '=>'} | %%{$_.InputObject}; $d | Sort-Object | Set-Content '%D%\14_hidden.txt'"
if exist "%D%\14_hidden.txt"        for /f %%c in ('type "%D%\14_hidden.txt"        ^| find /c /v ""') do set NHID=%%c
if exist "%D%\05_disabled.txt"      for /f %%c in ('type "%D%\05_disabled.txt"      ^| find /c /v ""') do set NDIS=%%c
if exist "%D%\08_missing_files.txt" for /f %%c in ('type "%D%\08_missing_files.txt" ^| find /c /v ""') do set NMISS=%%c

echo.
echo ============================================================
echo   DIAGNOSE RESULT (nothing was changed on the phone)
echo ------------------------------------------------------------
echo   Hidden (uninstalled-for-user) .... %NHID%
echo   Disabled ......................... %NDIS%
echo   APK file GONE (root-deleted) ..... %NMISS%
echo ============================================================
echo.
echo   ==^> Send the file  S688LN-diagnostics.zip  back for analysis.
echo       A tailored RESTORE .bat will be generated from it.
echo.
echo   Note: apps masked by a Magisk module can look "normal" here;
echo   the module list in the zip is what reveals those.
echo.
pause
endlocal
