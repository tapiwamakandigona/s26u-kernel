@echo off
setlocal enabledelayedexpansion
title S688LN - STEP 1 - SCAN (read-only)
echo ============================================================
echo   STEP 1 - SCAN   itel S688LN system-app restore kit
echo   READ-ONLY. This writes NOTHING to the phone.
echo ============================================================
echo.
echo  Phone: plugged in, screen UNLOCKED, USB debugging ON.
echo  If the phone shows "Allow USB debugging" tap ALLOW.
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
    echo [WARN] Phone not answering - check the "Allow USB debugging" popup, then re-run.
    pause & exit /b 1
)
echo Found device: %MODEL%
echo %MODEL% | find /i "S688LN" >nul
if errorlevel 1 (
    echo [WARN] This kit was made for itel S688LN. Detected: %MODEL%
    echo        The commands are generic and safe, but package sets differ per model.
    choice /m "Continue anyway"
    if errorlevel 2 exit /b 1
)
echo.

if not exist restore-report mkdir restore-report
set R=restore-report

echo [1/5] Saving device info...
> "%R%\device.txt" echo ==== S688LN restore scan  %date% %time% ====
"%ADB%" shell getprop ro.product.model      >> "%R%\device.txt"
"%ADB%" shell getprop ro.build.fingerprint  >> "%R%\device.txt"
"%ADB%" shell getprop ro.build.version.release >> "%R%\device.txt"

echo [2/5] Listing installed system apps...
"%ADB%" shell "pm list packages -s | cut -d: -f2" > "%R%\installed_system.txt"

echo [3/5] Listing ALL system apps (incl. hidden/uninstalled-for-user)...
"%ADB%" shell "cmd package list packages -u -s | cut -d: -f2" > "%R%\all_system.txt"

echo [4/5] Listing DISABLED apps...
"%ADB%" shell "pm list packages -d | cut -d: -f2" > "%R%\disabled.txt"

echo [5/5] Computing what will be restored...
rem to_restore = all_system MINUS installed_system  (the hidden ones)
powershell -NoProfile -Command "$i=@(Get-Content '%R%\installed_system.txt' -EA SilentlyContinue); $a=@(Get-Content '%R%\all_system.txt' -EA SilentlyContinue); $d=Compare-Object $i $a | ?{$_.SideIndicator -eq '=>'} | %%{$_.InputObject}; $d | Sort-Object | Set-Content '%R%\to_restore.txt'"

set /a NINST=0, NALL=0, NDIS=0, NRES=0
for /f %%c in ('type "%R%\installed_system.txt" ^| find /c /v ""') do set NINST=%%c
for /f %%c in ('type "%R%\all_system.txt"       ^| find /c /v ""') do set NALL=%%c
for /f %%c in ('type "%R%\disabled.txt"         ^| find /c /v ""') do set NDIS=%%c
if exist "%R%\to_restore.txt" for /f %%c in ('type "%R%\to_restore.txt" ^| find /c /v ""') do set NRES=%%c

echo.
echo ============================================================
echo   SCAN RESULT
echo ------------------------------------------------------------
echo   Installed system apps ........ %NINST%
echo   Total system apps on device .. %NALL%
echo   HIDDEN (uninstalled-for-user)  %NRES%   <- STEP-2 restores these
echo   DISABLED (switched off) ...... %NDIS%   <- STEP-2 re-enables these
echo ============================================================
echo.
echo Full lists saved in the "%R%" folder:
echo   to_restore.txt  - exactly which hidden apps STEP-2 will bring back
echo   disabled.txt    - which apps STEP-2 will re-enable
echo.
if %NRES%==0 if %NDIS%==0 (
    echo Nothing is hidden or disabled at the PMS level. If apps are still
    echo missing, they were removed by a Magisk module -> run
    echo RESTORE-MAGISK-DEBLOAT.bat  (needs root).
)
echo Review to_restore.txt, then run STEP-2-RESTORE-ALL.bat
echo.
pause
endlocal
