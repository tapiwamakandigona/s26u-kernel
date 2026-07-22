@echo off
setlocal
cd /d "%~dp0"
title S688LN Kernel - UNDO (FASTBOOTD) restore stock kernel
echo ============================================================
echo   UNDO (FASTBOOTD) - restores your original stock kernel
echo   from the STEP-1 backup. Safe to run any time.
echo.
echo   USE THIS IF THE PHONE WON'T BOOT after a flash:
echo     1. Hold POWER ~10s to force the phone OFF.
echo     2. Hold VOLUME DOWN and plug in the USB cable
echo        -^> phone enters bootloader (60s-timer) fastboot.
echo     3. Then run this script.
echo ============================================================
echo.
if not exist "backup\boot_stock_a.img" (
    echo *** No backup found in backup\boot_stock_a.img - STOPPING. ***
    echo Tell Viktor - stock kernel can also be restored from the
    echo firmware .pac if needed.
    pause
    exit /b 1
)
echo Backup found: backup\boot_stock_a.img
echo.
echo Press any key to continue (phone should be in fastboot OR on
echo with USB debugging)...
pause >nul
echo.
echo --- Trying to enter fastbootd from a running phone ---
platform-tools\adb.exe reboot fastboot 2>nul
echo --- If phone is already in bootloader fastboot, switching to fastbootd ---
platform-tools\fastboot.exe reboot fastboot 2>nul
echo Waiting 25 seconds for fastbootd...
timeout /t 25 /nobreak >nul
echo.
echo --- Devices ---
platform-tools\fastboot.exe devices
platform-tools\fastboot.exe getvar is-userspace
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
