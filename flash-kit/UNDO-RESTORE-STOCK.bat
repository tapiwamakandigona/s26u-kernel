@echo off
setlocal
cd /d "%~dp0"
title S688LN Kernel - UNDO (puts the stock kernel back)
echo ============================================================
echo   UNDO - restores your original stock kernel from the
echo   backup made in STEP 1. Safe to run any time.
echo ============================================================
echo.
if not exist "backup\boot_stock_a.img" (
    echo *** No backup found in backup\boot_stock_a.img - STOPPING. ***
    echo Tell Viktor - the stock kernel can also be restored from
    echo the firmware .pac if needed.
    pause
    exit /b 1
)
echo Get the phone into FASTBOOT mode:
echo   - If the phone is ON with USB debugging: just press any key.
echo   - Or manually: power OFF, hold VOLUME DOWN, plug in the cable.
echo.
echo Press any key to continue...
pause >nul
echo.
platform-tools\adb.exe reboot bootloader 2>nul
echo Waiting 20 seconds for fastboot...
timeout /t 20 /nobreak >nul
platform-tools\fastboot.exe devices
echo.
echo Press any key to RESTORE the stock kernel...
pause >nul
echo.
platform-tools\fastboot.exe flash boot backup\boot_stock_a.img
echo.
echo Exit code was %errorlevel%
echo.
echo If it said "OKAY" / "Finished": press any key to reboot.
echo If it said FAILED: STOP, do not reboot, send the text to Viktor.
pause >nul
platform-tools\fastboot.exe reboot
echo.
echo Phone is rebooting on the stock kernel.
echo.
pause
