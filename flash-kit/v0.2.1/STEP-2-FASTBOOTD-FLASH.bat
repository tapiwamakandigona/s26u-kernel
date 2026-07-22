@echo off
setlocal
cd /d "%~dp0"
title S688LN Kernel - STEP 2 (FASTBOOTD) flash boot
echo ============================================================
echo   STEP 2 (FASTBOOTD) - FLASH THE KERNEL to boot, slot a.
echo   Use this INSTEAD of the old STEP-2. It routes into
echo   fastbootd - the same mode you rooted init_boot in.
echo   Reversible with UNDO-FASTBOOTD.bat. Does NOT touch
echo   init_boot, so Magisk root stays.
echo ============================================================
echo.
if not exist "boot.img" (
    echo *** boot.img not found in this folder. Put this .bat in the
    echo     same folder as boot.img and platform-tools. STOPPING. ***
    pause
    exit /b 1
)
if not exist "backup\boot_stock_a.img" (
    echo *** No backup found in backup\ - run STEP 1 first so undo
    echo     is available. STOPPING. ***
    pause
    exit /b 1
)
echo Backup found: backup\boot_stock_a.img  (undo is always possible)
echo.
echo Make sure the phone is ON, unlocked, USB cable connected,
echo and USB debugging is ON.
echo   (WATCH THE PHONE - tap ALLOW / GRANT if it asks.)
echo.
echo Press any key to reboot the phone into FASTBOOTD...
pause >nul
echo.
echo --- Rebooting into fastbootd (adb reboot fastboot) ---
platform-tools\adb.exe reboot fastboot
echo Waiting 25 seconds for fastbootd...
timeout /t 25 /nobreak >nul
echo.
echo --- Devices seen by fastboot ---
platform-tools\fastboot.exe devices
echo.
echo --- Confirming we are in fastbootd (is-userspace should say yes) ---
platform-tools\fastboot.exe getvar is-userspace
echo.
echo If is-userspace says "yes" and you see ONE serial above, good.
echo If is-userspace says "no", you are in the wrong mode - CLOSE
echo this window and send Viktor the text.
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
echo     -^> Success. Press a key to reboot.
echo   If it said FAILED:
echo     -^> STOP. Do NOT reboot. Send the full text to Viktor.
echo ============================================================
echo.
echo Press any key to REBOOT the phone (only if flash said OKAY)...
pause >nul
platform-tools\fastboot.exe reboot
echo.
echo Phone is rebooting. First boot can take a few minutes.
echo When it's up, check IN THIS ORDER: WIFI turns on and connects,
echo then Magisk 30.7 (root), camera, fingerprint, a short call,
echo phone not hot. Kernel version should show 6.6.102.
echo Copy this whole window to Viktor - pass or fail.
echo.
pause
