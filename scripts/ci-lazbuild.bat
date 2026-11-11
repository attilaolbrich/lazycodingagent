@echo off
call "%~dp0ci-lazbuild.cmd" %*
exit /b %ERRORLEVEL%
