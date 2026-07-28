@echo off
setlocal
cd /d "%~dp0"
title S688LN v0.5 - STEP 2 FLASH - this window stays open
color 0E
echo ==============================================================
echo   STEP 2 - FLASH the v0.5 exact-stamp kernel - boot, slot a
echo   Run this ONLY after Viktor gave you the GO on STEP 1.
echo   Undo is always available: RESTORE-STOCK-v2.bat
echo ==============================================================
echo.

if exist "platform-tools\fastboot.exe" goto have_tools
echo *** PROBLEM: platform-tools\fastboot.exe not found.
echo     Run me from inside the unzipped kit folder.
goto the_end

:have_tools
if exist "boot.img" goto have_img
echo *** PROBLEM: boot.img not found in this folder.
goto the_end

:have_img
if exist "backup\boot_stock_a.img" goto have_backup
echo *** PROBLEM: no backup in backup\ - run STEP-1-CHECK.bat first.
goto the_end

:have_backup
set BSIZE=0
for %%A in ("backup\boot_stock_a.img") do set BSIZE=%%~zA
if "%BSIZE%"=="67108864" goto verify_img
echo *** PROBLEM: backup has the wrong size - %BSIZE% bytes.
echo     Do NOT flash. Send a photo of this window to Viktor.
goto the_end

:verify_img
echo Checking boot.img is not corrupted - takes a few seconds...
if not exist "EXPECTED-SHA256.txt" goto hash_skip
set EXPECT=
set /p EXPECT=<EXPECTED-SHA256.txt
set GOTHASH=
for /f "skip=1 tokens=1" %%h in ('certutil -hashfile boot.img SHA256') do if not defined GOTHASH set GOTHASH=%%h
if /i "%GOTHASH%"=="%EXPECT%" goto hash_ok
echo *** PROBLEM: boot.img failed its integrity check.
echo     expected %EXPECT%
echo     got      %GOTHASH%
echo     Re-download the kit zip. Do NOT flash this file.
goto the_end

:hash_skip
echo NOTE: EXPECTED-SHA256.txt missing - skipping integrity check.
goto connect

:hash_ok
echo boot.img integrity OK.

:connect
echo.
echo Phone: ON, unlocked, USB cable in, USB debugging ON.
echo WATCH THE PHONE - tap ALLOW if it asks.
echo.
echo Press any key to reboot the phone into FASTBOOTD...
pause >nul
echo.
echo --- Asking Android to reboot into fastbootd ---
echo     If it says "no devices/emulators found" that is FINE -
echo     the phone may already be in fastboot mode.
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
echo Confirmed: FASTBOOTD. Ready to flash v0.5.
echo.
echo ==============================================================
echo  Press any key to FLASH THE v0.5 KERNEL now.
echo  Or close this window to cancel - nothing written yet.
echo ==============================================================
pause >nul
echo.
platform-tools\fastboot.exe flash boot boot.img
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
echo  Phone is rebooting on the v0.5 kernel. First boot can take
echo  a few minutes. When Android is up and unlocked:
echo    1. Try the WiFi switch. Try the Bluetooth switch.
echo    2. Run STEP-3-TEST.bat - it checks everything and packs
echo       the logs for Viktor, PASS or FAIL.
echo  If the phone will NOT boot: RESTORE-STOCK-v2.bat brings
echo  stock back in 2 minutes - you have done it before.
echo ==============================================================
goto the_end

:no_dev
echo.
echo *** PROBLEM: no fastboot device appeared after 90 seconds.
echo     Try a different USB port or cable, then run me again.
goto the_end

:the_end
echo.
echo ================= END - window stays open =================
echo If anything above says PROBLEM or FAILED, send a photo of
echo this window to Viktor on Slack.
echo.
pause
exit /b
