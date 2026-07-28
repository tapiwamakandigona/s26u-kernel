@echo off
setlocal enabledelayedexpansion
title S688LN - RESTORE-CUSTOM (tailored from diagnostics 2026-07-28)
echo ============================================================
echo   RESTORE-CUSTOM   itel S688LN  -  tailored restore plan
echo ------------------------------------------------------------
echo   Generated from YOUR S688LN-diagnostics.zip (2026-07-28).
echo   Findings on this phone:
echo     - 23 stock apps hidden with "uninstall for user"
echo     - 4 apps disabled
echo     - 0 APK files actually deleted (all stock files intact)
echo     - 0 Magisk-masked system apps
echo   So: PackageManager only. No root needed. No flashing.
echo   Reversible + idempotent (safe to run twice).
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
choice /m "Restore the 23 hidden + 4 disabled apps now"
if errorlevel 2 exit /b 1
echo.

rem The exact 23 packages hidden on THIS phone (from 14_hidden.txt).
set HIDDEN=com.facebook.appmanager com.facebook.services com.facebook.system com.idea.questionnaire com.smartlife.nebula com.transsion.aiwallpaper com.transsion.chromecustomization com.transsion.dualapp com.transsion.iotservice com.transsion.kolun.aiservice com.transsion.kolun.assistant com.transsion.letswitch com.transsion.livewallpaper.pictorial com.transsion.magazineservice.itel com.transsion.nephilim com.transsion.personalizedService.itel com.transsion.phonemanager com.transsion.phonemaster com.transsion.smartpanel com.transsion.statisticalsales com.transsion.tabe com.transsion.trancare com.transsnet.store

rem The exact 4 disabled packages on THIS phone (from 05_disabled.txt).
set DISABLED=com.google.android.devicelockcontroller com.transsion.iotcard com.scorpio.securitycom com.google.android.gms.supervision

echo [1/3] Re-installing the 23 hidden stock apps (user 0)...
rem Loop runs ON THE DEVICE (dodges Windows CRLF parsing issues).
"%ADB%" shell "for p in %HIDDEN%; do out=$(cmd package install-existing --user 0 $p 2>&1); case $out in *installed*) echo '  ok      '$p;; *) echo '  FAILED  '$p' -> '$out;; esac; done"

echo.
echo [2/3] Re-enabling the 4 disabled apps...
"%ADB%" shell "for p in %DISABLED%; do pm enable $p >/dev/null 2>&1 && echo '  enabled '$p || echo '  FAILED  '$p; done"

echo.
echo [3/3] Verifying...
echo   Packages from the plan still not installed (empty = success):
"%ADB%" shell "for p in %HIDDEN%; do pm path --user 0 $p >/dev/null 2>&1 || echo '  STILL-HIDDEN: '$p; done"
echo   Disabled packages remaining on the phone (expect 0):
"%ADB%" shell "pm list packages -d | wc -l"

echo.
echo ============================================================
echo   DONE. Reboot once so the launcher / app drawer refresh.
echo ============================================================
choice /m "Reboot the phone now"
if not errorlevel 2 (
    echo Rebooting...
    "%ADB%" reboot
)
echo.
echo Afterwards run DIAGNOSE.bat again if you want fresh proof:
echo it should report 0 hidden / 0 disabled.
echo.
echo To UNDO any single app later:
echo   adb shell pm uninstall --user 0 ^<package^>     (hide again)
echo   adb shell pm disable-user --user 0 ^<package^>  (freeze again)
echo.
pause
endlocal
