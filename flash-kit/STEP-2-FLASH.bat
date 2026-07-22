@echo off
setlocal
cd /d "%~dp0"
title S688LN Kernel - STEP 2 FLASH (writes boot, only after Viktor says go)
echo ============================================================
echo   STEP 2 - FLASH THE KERNEL. Only run AFTER the STEP 1
echo   probe passed AND Viktor said go.
echo ============================================================
echo.
if not exist "backup\boot_stock_a.img" (
    echo *** No backup found in backup\ - run STEP 1 first. STOPPING. ***
    pause
    exit /b 1
)
echo Backup found: backup\boot_stock_a.img  (undo is always possible)
echo.
echo This writes the new kernel to the boot partition (slot a).
echo It does NOT touch init_boot, so Magisk root stays.
echo It is REVERSIBLE with UNDO-RESTORE-STOCK.bat.
echo.
echo Get the phone into FASTBOOT mode:
echo   - If the phone is ON with USB debugging: just press any key,
echo     this script will reboot it to fastboot for you.
echo   - Or manually: power OFF, hold VOLUME DOWN, plug in the cable.
echo.
echo Press any key to continue...
pause >nul
echo.
platform-tools\adb.exe reboot bootloader 2>nul
echo Waiting 20 seconds for fastboot...
timeout /t 20 /nobreak >nul
echo --- Confirming device is connected ---
platform-tools\fastboot.exe devices
echo.
echo If you do NOT see a device serial above, CLOSE this window
echo and get the phone into fastboot mode first. Otherwise:
echo.
echo Press any key to FLASH now (or close the window to cancel)...
pause >nul
echo.
echo --- Flashing new kernel to boot (active slot a) ---
platform-tools\fastboot.exe flash boot boot.img
echo.
echo Exit code was %errorlevel%
echo.
echo ============================================================
echo   If it said "OKAY" / "Finished" with no red errors:
echo     -^> Success. Reboot with the button below.
echo   If it said FAILED / not found:
echo     -^> STOP. Do NOT reboot. Send the full text to Viktor.
echo ============================================================
echo.
echo Press any key to REBOOT the phone (only if flash said OKAY)...
pause >nul
platform-tools\fastboot.exe reboot
echo.
echo Phone is rebooting. First boot can take a few minutes.
echo When it's up: check Magisk app (root), WiFi, camera,
echo fingerprint, and make a short call.
echo Send Viktor a message that all is well.
echo.
pause
