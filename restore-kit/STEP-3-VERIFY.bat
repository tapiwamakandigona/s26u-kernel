@echo off
setlocal enabledelayedexpansion
title S688LN - STEP 3 - VERIFY (read-only)
echo ============================================================
echo   STEP 3 - VERIFY   itel S688LN system-app restore kit
echo   READ-ONLY. Confirms the restore worked.
echo ============================================================
echo.

set ADB=platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb.exe
"%ADB%" version >nul 2>&1
if errorlevel 1 (
    echo [FAIL] adb.exe not found. Keep this .bat NEXT TO the platform-tools folder.
    pause & exit /b 1
)
echo Waiting for the phone...
"%ADB%" wait-for-device

if not exist restore-report mkdir restore-report
set R=restore-report

echo Re-scanning...
"%ADB%" shell "pm list packages -s | cut -d: -f2"            > "%R%\installed_system_after.txt"
"%ADB%" shell "cmd package list packages -u -s | cut -d: -f2" > "%R%\all_system_after.txt"
"%ADB%" shell "pm list packages -d | cut -d: -f2"            > "%R%\disabled_after.txt"

powershell -NoProfile -Command "$i=@(Get-Content '%R%\installed_system_after.txt' -EA SilentlyContinue); $a=@(Get-Content '%R%\all_system_after.txt' -EA SilentlyContinue); $d=Compare-Object $i $a | ?{$_.SideIndicator -eq '=>'} | %%{$_.InputObject}; $d | Sort-Object | Set-Content '%R%\still_hidden.txt'"

set /a NHID=0, NDIS=0
if exist "%R%\still_hidden.txt" for /f %%c in ('type "%R%\still_hidden.txt" ^| find /c /v ""') do set NHID=%%c
for /f %%c in ('type "%R%\disabled_after.txt" ^| find /c /v ""') do set NDIS=%%c

echo.
echo ============================================================
echo   VERIFY RESULT
echo ------------------------------------------------------------
echo   Still hidden (uninstalled-for-user) .. %NHID%
echo   Still disabled ....................... %NDIS%
echo ============================================================
echo.
if %NHID%==0 if %NDIS%==0 (
    echo [OK] All stock system apps are restored and enabled. You are done.
) else (
    echo Some apps are still hidden/disabled at the PMS level. See:
    echo   %R%\still_hidden.txt   %R%\disabled_after.txt
    echo These usually mean a Magisk debloat module is masking them ->
    echo run RESTORE-MAGISK-DEBLOAT.bat  (needs root), then reboot and re-verify.
)
echo.
pause
endlocal
