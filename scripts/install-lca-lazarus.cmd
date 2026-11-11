@echo off
REM Install LCA + terminal Lazarus packages (works when PowerShell script execution is restricted).
REM Direct .\install-lca-lazarus.ps1 may fail with PSSecurityException; this wrapper bypasses policy.
echo Installing LCA Design packages ^(ExecutionPolicy Bypass^)...
setlocal
set "SCRIPT=%~dp0install-lca-lazarus.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
