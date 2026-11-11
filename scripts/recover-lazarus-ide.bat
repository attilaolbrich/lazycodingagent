@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0recover-lazarus-ide.ps1" %*
exit /b %ERRORLEVEL%
