@echo off
setlocal enabledelayedexpansion
title S688LN - RESTORE-CUSTOM v1.3 (tailored from diagnostics 2026-07-28)
echo ============================================================
echo   RESTORE-CUSTOM   itel S688LN  -  tailored restore plan
echo ------------------------------------------------------------
echo   Generated from YOUR S688LN-diagnostics.zip (2026-07-28).
echo   Findings on this phone:
echo     - 23 stock apps hidden with "uninstall for user"
echo     - 0 apps YOU disabled (the 4 disabled ones are
echo       FACTORY-disabled - stock phones ship that way)
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
choice /m "Restore the 23 hidden apps + reset the 4 factory states now"
if errorlevel 2 exit /b 1
echo.

rem The exact 23 packages hidden on THIS phone (from 14_hidden.txt).
set HIDDEN=com.facebook.appmanager com.facebook.services com.facebook.system com.idea.questionnaire com.smartlife.nebula com.transsion.aiwallpaper com.transsion.chromecustomization com.transsion.dualapp com.transsion.iotservice com.transsion.kolun.aiservice com.transsion.kolun.assistant com.transsion.letswitch com.transsion.livewallpaper.pictorial com.transsion.magazineservice.itel com.transsion.nephilim com.transsion.personalizedService.itel com.transsion.phonemanager com.transsion.phonemaster com.transsion.smartpanel com.transsion.statisticalsales com.transsion.tabe com.transsion.trancare com.transsnet.store

rem These 4 were disabled in the FACTORY baseline (July-21 recon,
rem packages_disabled.txt - identical list). They are dormant security /
rem financing / parental modules that stock phones ship disabled:
rem   devicelockcontroller = Google financed-device lock (kiosk lock!)
rem   scorpio.securitycom  = Transsion payment-lock counterpart
rem   gms.supervision      = Google Kids parental supervision
rem   iotcard              = IoT card service (dormant until used)
rem Correct restore = leave them exactly as the factory left them.
rem v1.2 wrongly tried to enable them; 3 failed (protected packages -
rem the OS itself refused, which confirms they must stay off) and
rem iotcard got enabled, so we set it back to its factory DEFAULT state.
set FACTORY_DEFAULT=com.transsion.iotcard

echo [1/3] Re-installing the 23 hidden stock apps (user 0)...
rem Loop runs ON THE DEVICE (dodges Windows CRLF parsing issues).
"%ADB%" shell "for p in %HIDDEN%; do out=$(cmd package install-existing --user 0 $p 2>&1); case $out in *installed*) echo '  ok      '$p;; *) echo '  FAILED  '$p' -> '$out;; esac; done"

echo.
echo [2/3] Resetting factory-disabled apps to stock state...
echo   (v1.2 enabled iotcard by mistake - putting it back to DEFAULT.
echo    The other 3 were never changed: the OS refused, correctly.)
"%ADB%" shell "for p in %FACTORY_DEFAULT%; do pm default-state --user 0 $p >/dev/null 2>&1; if pm list packages -d | grep -q ^package:$p$; then echo '  stock (disabled) '$p; else pm disable-user --user 0 $p >/dev/null 2>&1 && echo '  re-disabled (factory state) '$p || echo '  FAILED '$p; fi; done"

echo.
echo [3/3] Verifying...
echo   Packages from the plan still not installed (empty = success):
"%ADB%" shell "for p in %HIDDEN%; do pm path --user 0 $p >/dev/null 2>&1 || echo '  STILL-HIDDEN: '$p; done"
echo   Factory-disabled packages (expect 4 - that IS stock state):
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
echo it should report 0 hidden / 4 disabled (4 = factory stock).
echo.
echo To UNDO any single app later:
echo   adb shell pm uninstall --user 0 ^<package^>     (hide again)
echo   adb shell pm disable-user --user 0 ^<package^>  (freeze again)
echo.
pause
endlocal
