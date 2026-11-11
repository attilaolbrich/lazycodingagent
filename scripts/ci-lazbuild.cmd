@echo off
REM lazbuild wrapper for Windows CI/local builds (works when PowerShell script execution is restricted).
setlocal
set "SCRIPT=%~dp0ci-lazbuild.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
