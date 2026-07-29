@echo off
setlocal
cd /d "%~dp0"
title S688LN v0.8-ksun - STEP 3 TEST - this window stays open
color 0B
echo ==============================================================
echo   STEP 3 - TEST after the v0.8-ksun flash.
echo   Checks WiFi/BT and the fix module, then packs all logs
echo   for Viktor. Read-only - changes nothing on the phone.
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
platform-tools\adb.exe shell "cat /proc/version" > logs\proc_version.txt

echo.
echo --- Are the WiFi/BT modules loaded? ---
platform-tools\adb.exe shell lsmod > logs\lsmod.txt
findstr /c:"sprd_wlan_combo" logs\lsmod.txt >nul 2>&1
if not errorlevel 1 goto modules_ok
echo WiFi driver NOT loaded. Collecting evidence for Viktor...
goto collect

:modules_ok
echo EXCELLENT: the WiFi driver is loaded.
echo Try the WiFi and Bluetooth switches on the phone now.

:collect
echo.
echo --- Collecting logs for Viktor - tap GRANT if asked ---
platform-tools\adb.exe shell su -c "cat /data/adb/modules/s688ln_wifi_fix/last-run.log" > logs\fix_module_log.txt 2>&1
platform-tools\adb.exe shell su -c "ls -l /data/adb/modules/s688ln_wifi_fix /data/adb/modules/s688ln_wifi_fix/gki" > logs\fix_module_files.txt 2>&1
platform-tools\adb.exe shell su -c dmesg > logs\dmesg.txt 2>nul
platform-tools\adb.exe shell "logcat -d -t 3000" > logs\logcat_tail.txt 2>nul
platform-tools\adb.exe shell "getprop | grep -iE 'wifi|wlan|bluetooth'" > logs\props_wifi_bt.txt
platform-tools\adb.exe shell "settings get global wifi_on" > logs\switch_states.txt
platform-tools\adb.exe shell "settings get global bluetooth_on" >> logs\switch_states.txt
platform-tools\adb.exe shell "ip link" > logs\ip_link.txt 2>&1

echo.
echo Packing logs into  S688LN-v06-logs.zip ...
if exist S688LN-v06-logs.zip del S688LN-v06-logs.zip
powershell -NoProfile -Command "Compress-Archive -Path logs -DestinationPath S688LN-v06-logs.zip -Force" >nul 2>&1
if exist S688LN-v06-logs.zip goto zip_ok
echo *** Zip step failed - send Viktor the whole "logs" folder instead.
goto wrapup

:zip_ok
echo Done: S688LN-v06-logs.zip

:wrapup
echo.
echo ==============================================================
echo   NOW DO THIS:
echo   1. On the phone: try the WiFi switch, then Bluetooth.
echo   2. Check Magisk still shows root, camera, fingerprint.
echo   3. Send  S688LN-v06-logs.zip  to Viktor on Slack and say
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
