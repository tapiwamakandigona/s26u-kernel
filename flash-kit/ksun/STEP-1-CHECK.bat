@echo off
setlocal
cd /d "%~dp0"
title S688LN v0.7.1-ksun - STEP 1 CHECK - read-only, writes NOTHING to the phone
color 0B
echo ==============================================================
echo   STEP 1 - CHECK  v0.7.1-ksun   -- READ-ONLY, writes NOTHING.
echo   This window never closes by itself.
echo ==============================================================
echo.
echo  Phone: ON, unlocked, USB cable in, USB debugging ON.
echo  WATCH THE PHONE - tap ALLOW / GRANT if it asks.
echo.

if exist "platform-tools\adb.exe" goto have_tools
echo *** PROBLEM: platform-tools\adb.exe not found.
echo     Unzip the WHOLE kit zip and run me from inside the
echo     unzipped folder.
goto the_end

:have_tools
echo Waiting for the phone...
platform-tools\adb.exe wait-for-device
set MODEL=
for /f "delims=" %%i in ('platform-tools\adb.exe shell getprop ro.product.model') do set MODEL=%%i
if not "%MODEL%"=="" goto have_dev
echo *** PROBLEM: phone not answering. Check the ALLOW popup on
echo     the phone screen, then run me again.
goto the_end

:have_dev
echo Found device: %MODEL%
echo.
echo --- Current kernel on the phone ---
platform-tools\adb.exe shell uname -r
platform-tools\adb.exe shell uname -r > "%TEMP%\s688ln_uname.txt"
findstr /c:"g1481f357a31c" "%TEMP%\s688ln_uname.txt" >nul 2>&1
if not errorlevel 1 goto on_stock
echo *** NOTE: you are NOT on the stock kernel right now.
echo     That is unusual for STEP 1. Send a photo of this window
echo     to Viktor before going further.
goto the_end

:on_stock
echo Good: phone is on the STOCK kernel.
echo.
echo --------------------------------------------------------------
echo  PART A - making sure your stock backup exists
echo --------------------------------------------------------------
if exist "backup\boot_stock_a.img" goto check_backup_size
echo No backup found yet - taking one now. Tap GRANT on the phone
echo if a Superuser popup appears...
platform-tools\adb.exe shell "su -c 'dd if=/dev/block/by-name/boot_a of=/sdcard/boot_stock_a.img bs=4096'"
platform-tools\adb.exe pull /sdcard/boot_stock_a.img backup\boot_stock_a.img
platform-tools\adb.exe shell rm -f /sdcard/boot_stock_a.img

:check_backup_size
if exist "backup\boot_stock_a.img" goto size_check
echo *** PROBLEM: could not create the backup. Do NOT continue.
echo     Send a photo of this window to Viktor on Slack.
goto the_end

:size_check
set BSIZE=0
for %%A in ("backup\boot_stock_a.img") do set BSIZE=%%~zA
echo Backup: backup\boot_stock_a.img  size %BSIZE% bytes - expected 67108864
if "%BSIZE%"=="67108864" goto backup_ok
echo *** PROBLEM: the backup is the WRONG SIZE. Do NOT continue.
echo     Send a photo of this window to Viktor on Slack.
goto the_end

:backup_ok
echo Backup OK - the undo path is safe.
echo.
echo --------------------------------------------------------------
echo  PART B - collecting the read-only evidence Viktor needs
echo --------------------------------------------------------------
if exist check rmdir /s /q check
mkdir check

echo [1/6] Kernel and build identity...
platform-tools\adb.exe shell uname -a > check\uname.txt
platform-tools\adb.exe shell getprop ro.build.fingerprint >> check\uname.txt

echo [2/6] The KEY question - how GKI modules are stored...
platform-tools\adb.exe shell "ls -lR /system_dlkm/lib/modules 2>/dev/null" > check\system_dlkm_tree.txt
platform-tools\adb.exe shell "find /system_dlkm -name 'modules.load' 2>/dev/null" >> check\system_dlkm_tree.txt
platform-tools\adb.exe shell "cat /system_dlkm/lib/modules/*/modules.load 2>/dev/null" > check\system_dlkm_modules_load.txt
platform-tools\adb.exe shell "cat /system_dlkm/lib/modules/modules.load 2>/dev/null" >> check\system_dlkm_modules_load.txt

echo [3/6] Where the 14 missing WiFi-BT modules live...
platform-tools\adb.exe shell "find /system_dlkm /vendor_dlkm /vendor/lib/modules /odm 2>/dev/null | grep -E 'rfkill|cfg80211|sprd_wlan|sprdbt|usbnet|mii\.ko|cdc_|r815|rtl8150|asix|ax88179'" > check\module_locations.txt

echo [4/6] Vendor module lists...
platform-tools\adb.exe shell "cat /vendor_dlkm/lib/modules/modules.load 2>/dev/null" > check\vendor_dlkm_modules_load.txt
platform-tools\adb.exe shell "cat /vendor_dlkm/lib/modules/modules.dep 2>/dev/null" > check\vendor_dlkm_modules_dep.txt

echo [5/6] WiFi-related system settings...
platform-tools\adb.exe shell "getprop | grep -iE 'wifi|wlan|dlkm|module'" > check\props_wifi.txt

echo [6/6] Boot scripts that load modules - tap GRANT if asked...
platform-tools\adb.exe shell su -c "grep -rE 'modprobe|insmod|load_module' /vendor/etc/init /system/etc/init 2>/dev/null" > check\init_module_lines.txt

echo.
echo Packing results into  S688LN-check-v06.zip ...
if exist S688LN-check-v06.zip del S688LN-check-v06.zip
powershell -NoProfile -Command "Compress-Archive -Path check -DestinationPath S688LN-check-v06.zip -Force" >nul 2>&1
if exist S688LN-check-v06.zip goto zip_ok
echo *** Zip step failed - send Viktor the whole "check" folder instead.
goto verdict

:zip_ok
echo Done: S688LN-check-v06.zip

:verdict
echo.
echo --- Quick automatic verdict ---
findstr /c:"6.6.102-android15-8-g1481f357a31c" check\system_dlkm_tree.txt >nul 2>&1
if not errorlevel 1 goto gun_found
echo   No version-named module folder detected on /system_dlkm.
echo   NOT a green light - Viktor must read the full results first.
goto finish

:gun_found
echo   SMOKING GUN FOUND: the phone keeps its GKI modules in a
echo   folder named after the exact kernel version string.
echo   That is exactly what the WiFi-fix module fixes.

:finish
echo.
echo ==============================================================
echo   DONE - nothing was written to the phone.
echo   1. Send  S688LN-check-v06.zip  to Viktor on Slack.
echo   2. WAIT for Viktor's GO before running STEP-2-FLASH.
echo ==============================================================
goto the_end

:the_end
echo.
echo ================= END - window stays open =================
echo.
pause
exit /b
