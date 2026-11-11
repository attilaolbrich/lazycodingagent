@echo off
REM Install LCA + terminal Lazarus packages (same as install-lca-lazarus.cmd).
REM Uses PowerShell -ExecutionPolicy Bypass. Do not run install-lca-lazarus.ps1 directly
REM if your policy blocks scripts; use this .bat instead.
echo Installing LCA Design packages via PowerShell ^(ExecutionPolicy Bypass^)...
call "%~dp0install-lca-lazarus.cmd" %*
exit /b %ERRORLEVEL%
