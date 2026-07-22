@echo off
setlocal
title S688LN - GATHER INFO (read-only)
echo ============================================================
echo   S688LN GATHER INFO  --  READ-ONLY. Writes NOTHING.
echo ============================================================
echo.
echo  Phone: plugged in, screen UNLOCKED, USB debugging ON.
echo  If the phone shows "Allow USB debugging" tap ALLOW.
echo  If the phone shows a "Superuser request" popup tap GRANT.
echo.

set ADB=platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb.exe
"%ADB%" version >nul 2>&1
if errorlevel 1 (
    echo [FAIL] adb.exe not found. Put this .bat NEXT TO the platform-tools folder.
    pause
    exit /b 1
)

echo Waiting for the phone...
"%ADB%" wait-for-device

set MODEL=
for /f "delims=" %%i in ('"%ADB%" shell getprop ro.product.model') do set MODEL=%%i
if "%MODEL%"=="" (
    echo [WARN] Phone not answering - check the "Allow USB debugging" popup on the phone, then run this again.
    pause
    exit /b 1
)
echo Found device: %MODEL%
echo.

if exist evidence rmdir /s /q evidence
mkdir evidence
mkdir evidence\modules

set OUT=evidence\kernel_evidence.txt
echo ============ S688LN KERNEL EVIDENCE ============>"%OUT%"
echo Collected: %date% %time%>>"%OUT%"
echo.>>"%OUT%"

echo [1/8] Kernel version...
echo === uname -a ===>>"%OUT%"
"%ADB%" shell uname -a>>"%OUT%"
echo === /proc/version ===>>"%OUT%"
"%ADB%" shell cat /proc/version>>"%OUT%"
echo === slot / fingerprints ===>>"%OUT%"
"%ADB%" shell getprop ro.boot.slot_suffix>>"%OUT%"
"%ADB%" shell getprop ro.build.fingerprint>>"%OUT%"
"%ADB%" shell getprop ro.vendor.build.fingerprint>>"%OUT%"

echo [2/8] Device properties...
"%ADB%" shell getprop > evidence\props.txt

echo [3/8] Loaded kernel modules...
echo.>>"%OUT%"
echo === /proc/modules ===>>"%OUT%"
"%ADB%" shell cat /proc/modules>>"%OUT%"

echo [4/8] WiFi/WCN kernel entries...
echo.>>"%OUT%"
echo === /sys/module wcn-sprd-wlan entries ===>>"%OUT%"
"%ADB%" shell "ls /sys/module 2>/dev/null | grep -iE 'wcn|sprd|wlan|marlin'">>"%OUT%"

echo [5/8] Vendor module file tree...
echo.>>"%OUT%"
echo === vendor module files ===>>"%OUT%"
"%ADB%" shell "ls -lR /vendor/lib/modules /vendor_dlkm 2>/dev/null">>"%OUT%"

echo [6/8] Pulling WiFi/BT driver files + module metadata...
"%ADB%" shell "find /vendor/lib/modules /vendor_dlkm /lib/modules -type f 2>/dev/null | grep -iE 'wcn|wlan|sprd|marlin|modules\.'" > evidence\ko_list.txt
for /f "usebackq delims=" %%m in ("evidence\ko_list.txt") do "%ADB%" pull "%%m" evidence\modules\ >nul 2>&1

echo [7/8] Stock kernel config...
"%ADB%" exec-out cat /proc/config.gz > evidence\stock_config.gz 2>nul
set CFGSIZE=0
for %%A in (evidence\stock_config.gz) do set CFGSIZE=%%~zA
if "%CFGSIZE%"=="0" (
    echo    ...needs root: tap GRANT on the phone if a popup appears
    "%ADB%" exec-out su -c "cat /proc/config.gz" > evidence\stock_config.gz 2>nul
)

echo [8/8] WiFi boot logs - tap GRANT on the phone if a popup appears...
"%ADB%" shell su -c dmesg > evidence\dmesg.txt 2>nul
"%ADB%" shell su -c "cat /proc/cmdline" > evidence\cmdline.txt 2>nul
"%ADB%" shell "logcat -d -t 4000" > evidence\logcat_tail.txt 2>nul

echo.
echo Packing everything into S688LN-evidence.zip ...
if exist S688LN-evidence.zip del S688LN-evidence.zip
powershell -NoProfile -Command "Compress-Archive -Path evidence -DestinationPath S688LN-evidence.zip -Force" >nul 2>&1

echo.
echo ============================================================
if exist S688LN-evidence.zip (
    echo   DONE. Send the file  S688LN-evidence.zip  to Viktor on Slack.
) else (
    echo   Zip step failed - send Viktor the whole "evidence" folder instead.
)
echo   Nothing was written to the phone. Safe to unplug.
echo ============================================================
pause
