@echo off
REM Build embedded SQLite and link LazySqliteStatic (works when PowerShell script execution is restricted).
REM Direct .\install-lazarus-sqlite.ps1 may fail with PSSecurityException; this wrapper bypasses policy.
echo Building and linking LazySqliteStatic ^(ExecutionPolicy Bypass^)...
setlocal
set "SCRIPT=%~dp0install-lazarus-sqlite.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
