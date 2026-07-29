@echo off
setlocal
cd /d "%~dp0"
title S688LN v0.7.1-ksun - STEP 2 FLASH plus WIFI FIX - this window stays open
color 0E
echo ==============================================================
echo   STEP 2 - v0.7.1-ksun: installs the WiFi-fix module, then
echo   flashes the exact-stamp KernelSU kernel - boot, slot a.
echo   Undo is always available: RESTORE-STOCK-v2.bat
echo ==============================================================
echo.

set WIFIZIP=s688ln-wifi-fix-v0.7.1-ksun.zip
set BOOTSHA=48a88d980dcfd429884bdda851064d597e8692b994f6077ed905d54449f7d2a5
set ZIPSHA=67f38ca571c118ef0122a7b4dda456b190d773baf096caa1d79d2772bdb3b5dc

if exist "platform-tools\fastboot.exe" goto have_tools
echo *** PROBLEM: platform-tools\fastboot.exe not found.
echo     Run me from inside the unzipped v0.7.1 kit folder.
goto the_end

:have_tools
if exist "boot.img" goto have_img
echo *** PROBLEM: boot.img not found in this folder.
goto the_end

:have_img
if exist "%WIFIZIP%" goto have_mod
echo *** PROBLEM: %WIFIZIP% not found in this folder.
echo     It ships inside the v0.7.1 kit zip. If you renamed it,
echo     rename it back to exactly:  %WIFIZIP%
goto the_end

:have_mod
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
echo Checking boot.img is really the v0.7.1 kernel - a few seconds...
set GOTHASH=
for /f "skip=1 tokens=1" %%h in ('certutil -hashfile boot.img SHA256') do if not defined GOTHASH set GOTHASH=%%h
if /i "%GOTHASH%"=="%BOOTSHA%" goto img_ok
echo *** PROBLEM: this boot.img is NOT the v0.7.1-ksun kernel.
echo     expected %BOOTSHA%
echo     got      %GOTHASH%
echo     Wrong folder or an old kit. Use only the files from the
echo     v0.7.1-ksun release. Do NOT flash this file.
goto the_end

:img_ok
echo boot.img OK - genuine v0.7.1-ksun.
echo Checking the WiFi-fix zip is from the SAME build...
set GOTZIP=
for /f "skip=1 tokens=1" %%h in ('certutil -hashfile "%WIFIZIP%" SHA256') do if not defined GOTZIP set GOTZIP=%%h
if /i "%GOTZIP%"=="%ZIPSHA%" goto zip_ok
echo *** PROBLEM: this WiFi-fix zip is NOT from the v0.7.1 build.
echo     Kernel keys are per-build. A zip from another build is
echo     exactly what killed WiFi and Bluetooth last time.
echo     Do NOT continue. Re-download the v0.7.1 kit and use the
echo     zip that comes inside it.
goto the_end

:zip_ok
echo WiFi-fix zip OK - matches the v0.7.1 build.
echo.
echo Phone: ON, unlocked, USB cable in, USB debugging ON.
echo WATCH THE PHONE - tap ALLOW / GRANT if it asks.
echo.
echo --- Part A: installing the WiFi-fix module (Magisk or KernelSU) ---
echo     This is staged only - it does nothing until the reboot,
echo     and it does nothing at all on the stock kernel.
platform-tools\adb.exe wait-for-device
platform-tools\adb.exe push "%WIFIZIP%" /data/local/tmp/%WIFIZIP% > nul
platform-tools\adb.exe shell su -c "if [ -x /data/adb/ksud ]; then /data/adb/ksud module install /data/local/tmp/%WIFIZIP%; else magisk --install-module /data/local/tmp/%WIFIZIP%; fi" > "%TEMP%\s688ln_modinst.txt" 2>&1
type "%TEMP%\s688ln_modinst.txt"
platform-tools\adb.exe shell su -c "ls /data/adb/modules_update/s688ln_wifi_fix/module.prop /data/adb/modules/s688ln_wifi_fix/module.prop 2>/dev/null" > "%TEMP%\s688ln_modchk.txt" 2>&1
findstr /c:"module.prop" "%TEMP%\s688ln_modchk.txt" >nul 2>&1
if not errorlevel 1 goto mod_ok
echo.
echo *** PROBLEM: the module did not land on the phone.
echo     Did you tap GRANT on the root popup on the phone screen?
echo     Run me again and watch the phone.
echo     If it keeps failing, send a photo of this window to Viktor.
goto the_end

:mod_ok
echo Module staged OK - it replaces any older s688ln_wifi_fix
echo module automatically on the next reboot.
echo.
echo --- Part B: flashing the kernel ---
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
echo Confirmed: FASTBOOTD. Ready to flash v0.7.1-ksun.
echo.
echo ==============================================================
echo  Press any key to FLASH THE v0.7.1-ksun KERNEL now.
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
echo  Phone is rebooting on the v0.7.1-ksun kernel + WiFi fix.
echo  First boot can take a few minutes. When Android is up:
echo    1. Try the WiFi switch. Try the Bluetooth switch.
echo    2. Open the KernelSU Next app - it should say Working
echo       and show version 33214.
echo    3. Run STEP-3-TEST.bat - it checks everything and packs
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
