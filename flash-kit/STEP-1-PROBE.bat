@echo off
setlocal
cd /d "%~dp0"
title S688LN Kernel - STEP 1 PROBE (test boot only, nothing permanent)
echo ============================================================
echo   STEP 1 - BACKUP + TEST BOOT. Writes NOTHING permanent.
echo   The new kernel only runs from memory. Any normal reboot
echo   puts you back on the stock kernel automatically.
echo ============================================================
echo.
echo Before starting:
echo   1. Phone is ON and unlocked, USB cable connected.
echo   2. USB debugging is ON (Settings ^> Developer options).
echo   3. WATCH THE PHONE SCREEN - Magisk will ask permission,
echo      tap GRANT when it pops up.
echo.
echo Press any key to start...
pause >nul
echo.
echo --- Checking the phone is connected (adb) ---
platform-tools\adb.exe devices
echo.
echo If you see "unauthorized", tap ALLOW on the phone, then
echo close this window and run STEP 1 again.
echo Press any key to continue...
pause >nul
echo.
echo --- Backing up your CURRENT stock kernel (safety net) ---
echo     (tap GRANT on the phone if Magisk asks)
platform-tools\adb.exe shell "su -c 'dd if=/dev/block/by-name/boot_a of=/sdcard/boot_stock_a.img bs=4096'"
platform-tools\adb.exe pull /sdcard/boot_stock_a.img backup\boot_stock_a.img
if not exist "backup\boot_stock_a.img" (
    echo.
    echo *** BACKUP FAILED - STOP HERE. Send this window's text to Viktor. ***
    pause
    exit /b 1
)
for %%A in ("backup\boot_stock_a.img") do set BSIZE=%%~zA
echo Backup size: %BSIZE% bytes (should be 67108864)
if not "%BSIZE%"=="67108864" (
    echo.
    echo *** BACKUP WRONG SIZE - STOP HERE. Send this text to Viktor. ***
    pause
    exit /b 1
)
echo Backup OK: backup\boot_stock_a.img
echo.
echo --- Rebooting the phone into fastboot mode ---
platform-tools\adb.exe reboot bootloader
echo Waiting 20 seconds for fastboot...
timeout /t 20 /nobreak >nul
platform-tools\fastboot.exe devices
echo.
echo You should see ONE device serial above. Press any key to
echo TEST-BOOT the new kernel (nothing is written)...
pause >nul
echo.
echo --- Test-booting the new kernel from RAM ---
platform-tools\fastboot.exe boot boot.img
echo.
echo Exit code was %errorlevel%
echo If it hangs or the phone stays black for over 3 minutes:
echo hold POWER until it reboots - you are back on stock, no harm.
echo.
echo --- Waiting for the phone to finish booting ---
platform-tools\adb.exe wait-for-device
timeout /t 10 /nobreak >nul
echo.
echo --- Kernel version now running ---
platform-tools\adb.exe shell uname -r
platform-tools\adb.exe shell uname -r | findstr /c:"6.6.139" >nul
if %errorlevel%==0 (
    echo.
    echo   PROBE LOOKS GOOD: new kernel 6.6.139 is running.
) else (
    echo.
    echo   Version above does NOT show 6.6.139 - send this text to Viktor.
)
echo.
echo ============================================================
echo   NOW CHECK ON THE PHONE (takes 2 minutes):
echo     - Magisk app still shows Installed 30.7 (root kept)
echo     - WiFi works
echo     - Camera opens
echo     - Fingerprint unlock works
echo     - Make a short phone call
echo     - Phone does not get unusually hot
echo.
echo   When done checking, just REBOOT the phone normally.
echo   That puts it back on the stock kernel by itself.
echo.
echo   COPY everything in this window and send it to Viktor,
echo   plus what worked/failed on the phone.
echo   Do NOT run STEP 2 until Viktor says go.
echo ============================================================
echo.
pause
