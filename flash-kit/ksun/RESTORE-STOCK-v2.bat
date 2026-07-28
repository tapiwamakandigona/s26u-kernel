@echo off
setlocal
cd /d "%~dp0"
title S688LN - RESTORE STOCK KERNEL v2 - this window stays open
color 0A
echo ==============================================================
echo   RESTORE STOCK KERNEL - v2
echo   This window will NEVER close by itself. Every stop ends
echo   with "Press any key", so you can always read what happened.
echo ==============================================================
echo.

rem ---- sanity: are we inside the kit folder? ----
if exist "platform-tools\fastboot.exe" goto have_tools
echo *** PROBLEM: I cannot find  platform-tools\fastboot.exe
echo.
echo     This .bat must be placed INSIDE the kit folder
echo     S688LN-kernel-v0.5-exact-stamp  - right next to the
echo     "platform-tools" and "backup" folders.
echo.
echo     I am currently running from:
echo       %CD%
echo.
echo     Move me into the kit folder and double-click me again.
goto the_end

:have_tools
if exist "backup\boot_stock_a.img" goto have_backup
echo *** PROBLEM: I cannot find  backup\boot_stock_a.img
echo     That is your stock kernel backup from STEP 1.
echo     Do NOT flash anything. Send a photo of this window to
echo     Viktor on Slack - stock can also be restored another way.
goto the_end

:have_backup
for %%A in ("backup\boot_stock_a.img") do set BSIZE=%%~zA
echo Backup found: backup\boot_stock_a.img
echo Backup size : %BSIZE% bytes  - expected 67108864
if "%BSIZE%"=="67108864" goto size_ok
echo *** PROBLEM: the backup is the WRONG SIZE. Do NOT flash it.
echo     Send a photo of this window to Viktor on Slack.
goto the_end

:size_ok
echo Backup looks good.
echo.
echo --------------------------------------------------------------
echo  STEP A - get the phone connected
echo --------------------------------------------------------------
echo  If the phone is ON and working:
echo     just plug in the USB cable - I will do the rest.
echo  If the phone will NOT boot:
echo     1. Hold POWER about 15 seconds to force it off.
echo     2. Hold POWER + VOLUME UP until the Recovery menu shows.
echo     3. Use Volume keys to pick "Enter fastboot", press Power.
echo     4. Plug in the USB cable.
echo --------------------------------------------------------------
echo.
echo Press any key when the cable is plugged in...
pause >nul
echo.
echo --- Asking Android to reboot into fastbootd - adb route ---
echo     If the next line says "no devices/emulators found" that is
echo     FINE - it just means the phone is not in Android right now.
platform-tools\adb.exe reboot fastboot
echo.
echo Waiting for a fastboot device - up to 90 seconds...
set TRIES=0
set SWITCHED=0

:waitloop
platform-tools\fastboot.exe devices > "%TEMP%\s688ln_fbdev.txt" 2>&1
findstr "fastboot" "%TEMP%\s688ln_fbdev.txt" >nul 2>&1
if not errorlevel 1 goto found_dev
set /a TRIES+=1
if %TRIES% GEQ 18 goto no_dev
echo    ...still waiting  %TRIES% of 18
timeout /t 5 /nobreak >nul
goto waitloop

:found_dev
echo.
echo --- Device found: ---
type "%TEMP%\s688ln_fbdev.txt"
echo.
echo --- Checking we are in FASTBOOTD - the mode that works ---
platform-tools\fastboot.exe getvar is-userspace > "%TEMP%\s688ln_fbus.txt" 2>&1
findstr /c:"is-userspace: yes" "%TEMP%\s688ln_fbus.txt" >nul 2>&1
if not errorlevel 1 goto flash_ready
if "%SWITCHED%"=="1" goto not_userspace
echo Phone is in the OLD bootloader fastboot - that one does not
echo flash on this device. Switching it to FASTBOOTD now...
platform-tools\fastboot.exe reboot fastboot
set SWITCHED=1
set TRIES=0
echo Waiting for fastbootd - up to 90 seconds...
goto waitloop

:not_userspace
echo *** PROBLEM: the phone will not report fastbootd mode.
type "%TEMP%\s688ln_fbus.txt"
echo     Send a photo of this window to Viktor on Slack.
goto the_end

:flash_ready
echo Confirmed: FASTBOOTD. Ready to restore.
echo.
echo ==============================================================
echo  Press any key to FLASH THE STOCK KERNEL BACK now.
echo  Or close this window to cancel - nothing written yet.
echo ==============================================================
pause >nul
echo.
platform-tools\fastboot.exe flash boot backup\boot_stock_a.img
set RC=%ERRORLEVEL%
echo.
echo Flash finished with exit code %RC%
if "%RC%"=="0" goto flash_ok
echo *** FAILED - do NOT reboot the phone. Take a photo of this
echo     whole window and send it to Viktor on Slack.
goto the_end

:flash_ok
echo Flash reported OK.
echo.
echo Press any key to REBOOT the phone into normal Android...
pause >nul
platform-tools\fastboot.exe reboot
echo.
echo ==============================================================
echo  DONE. The phone is rebooting on your STOCK kernel.
echo  First boot can take a couple of minutes. WiFi, Bluetooth,
echo  root, banking - everything back to normal.
echo ==============================================================
goto the_end

:no_dev
echo.
echo *** PROBLEM: no fastboot device appeared after 90 seconds.
echo     Things to try, then run me again:
echo       - Different USB port - prefer one directly on the PC.
echo       - Different cable.
echo       - Make sure the phone screen shows the fastboot menu.
echo       - Unplug and replug the cable.
goto the_end

:the_end
echo.
echo ================= END - window stays open =================
echo If anything above says PROBLEM or FAILED, send a photo of
echo this window to Viktor on Slack.
echo.
pause
exit /b
