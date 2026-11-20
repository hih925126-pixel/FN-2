@echo off
setlocal
cd /d "%~dp0"
title Flux
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Flux.ps1"
if errorlevel 1 (
    echo.
    echo Flux exited with an error. See %%APPDATA%%\Flux\logs
    pause
)
endlocal
