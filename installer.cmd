@echo off

rem
rem ----------------
rem DotMan Installer
rem Windows Launcher
rem ----------------
rem
rem A modular, open-source and multiplatform manager for .NET
rem
rem https://github.com/reallukee/dotman
rem
rem By Luca Pollicino (https://github.com/reallukee)
rem
rem installer.cmd
rem
rem Licensed under the MIT license!
rem

setlocal

where pwsh >nul 2>&1

if errorlevel 0 (
    set shell="pwsh"
) else (
    set shell="powershell"

    echo "Using Windows PowerShell!"
    echo "PowerShell 7+ is recommended!"
)

set module="%~dp0installer.ps1"

if exist "%module%" (
    %shell% -NoProfile -ExecutionPolicy Bypass -File "%module%" %*
) else (
    echo "Module is missing!"

    exit /b 1
)

endlocal
