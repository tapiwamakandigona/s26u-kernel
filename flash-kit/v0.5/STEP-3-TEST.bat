@echo off
setlocal
cd /d "%~dp0"
title S688LN v0.5 - STEP 3 TEST - this window stays open
color 0B
echo ==============================================================
echo   STEP 3 - TEST after the v0.5 flash.
echo   Checks WiFi/BT, tries an automatic rescue if needed, and
echo   packs all logs for Viktor. Read-only except the rescue,
echo   which only loads the phone's own stock drivers.
echo ==============================================================
echo.
echo  Phone: booted into Android, unlocked, USB debugging ON.
echo  WATCH THE PHONE - tap ALLOW / GRANT if it asks.
echo.

if exist "platform-tools\adb.exe" goto have_tools
echo *** PROBLEM: platform-tools\adb.exe not found.
echo     Run me from inside the unzipped kit folder.
goto the_end

:have_tools
echo Waiting for the phone...
platform-tools\adb.exe wait-for-device
if exist logs rmdir /s /q logs
mkdir logs

echo.
echo --- Which kernel are we on? ---
platform-tools\adb.exe shell uname -a
platform-tools\adb.exe shell uname -a > logs\uname.txt
findstr /c:"g1481f357a31c" logs\uname.txt >nul 2>&1
if not errorlevel 1 goto kernel_ok
echo *** The phone does NOT report the v0.5 kernel string.
echo     Either the flash did not stick or you are on stock.
echo     Continuing to collect logs anyway...
goto collect

:kernel_ok
echo Good: v0.5 exact-stamp kernel is running.
echo.
echo --- Are the WiFi/BT modules loaded? ---
platform-tools\adb.exe shell lsmod > logs\lsmod.txt
findstr /c:"sprd_wlan_combo" logs\lsmod.txt >nul 2>&1
if not errorlevel 1 goto modules_ok
echo Modules NOT auto-loaded. Trying the automatic rescue now.
echo Tap GRANT on the phone if a Superuser popup appears...
platform-tools\adb.exe push rescue.sh /data/local/tmp/rescue.sh > nul
platform-tools\adb.exe shell su -c "sh /data/local/tmp/rescue.sh" > logs\rescue_output.txt 2>&1
type logs\rescue_output.txt
platform-tools\adb.exe shell lsmod > logs\lsmod_after_rescue.txt
findstr /c:"sprd_wlan_combo" logs\lsmod_after_rescue.txt >nul 2>&1
if not errorlevel 1 goto rescue_worked
echo.
echo Rescue could NOT load the WiFi driver. Collecting logs...
goto collect

:rescue_worked
echo.
echo RESCUE LOADED THE WIFI DRIVER. Now try the WiFi switch on
echo the phone - it may just work.
goto collect

:modules_ok
echo EXCELLENT: WiFi driver auto-loaded - v0.5 hypothesis CONFIRMED.
echo Try the WiFi and Bluetooth switches on the phone now.

:collect
echo.
echo --- Collecting logs for Viktor - tap GRANT if asked ---
platform-tools\adb.exe shell su -c dmesg > logs\dmesg.txt 2>nul
platform-tools\adb.exe shell "logcat -d -t 3000" > logs\logcat_tail.txt 2>nul
platform-tools\adb.exe shell "ls -lR /system_dlkm/lib/modules 2>/dev/null" > logs\system_dlkm_tree.txt
platform-tools\adb.exe shell "getprop | grep -iE 'wifi|wlan|bluetooth'" > logs\props_wifi_bt.txt
platform-tools\adb.exe shell "settings get global wifi_on" > logs\switch_states.txt
platform-tools\adb.exe shell "settings get global bluetooth_on" >> logs\switch_states.txt

echo.
echo Packing logs into  S688LN-v05-logs.zip ...
if exist S688LN-v05-logs.zip del S688LN-v05-logs.zip
powershell -NoProfile -Command "Compress-Archive -Path logs -DestinationPath S688LN-v05-logs.zip -Force" >nul 2>&1
if exist S688LN-v05-logs.zip goto zip_ok
echo *** Zip step failed - send Viktor the whole "logs" folder instead.
goto wrapup

:zip_ok
echo Done: S688LN-v05-logs.zip

:wrapup
echo.
echo ==============================================================
echo   NOW DO THIS:
echo   1. On the phone: try the WiFi switch, then Bluetooth.
echo   2. Check Magisk still shows root, camera, fingerprint.
echo   3. Send  S688LN-v05-logs.zip  to Viktor on Slack and say
echo      whether WiFi and Bluetooth work - PASS or FAIL.
echo.
echo   Not happy with anything? RESTORE-STOCK-v2.bat puts your
echo   stock kernel back in 2 minutes. Banking stays safe.
echo ==============================================================
goto the_end

:the_end
echo.
echo ================= END - window stays open =================
echo.
pause
exit /b
