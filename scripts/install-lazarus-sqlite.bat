@echo off
REM Same as install-lazarus-sqlite.cmd — use when .\install-lazarus-sqlite.ps1 is blocked by execution policy.
call "%~dp0install-lazarus-sqlite.cmd" %*
exit /b %ERRORLEVEL%
