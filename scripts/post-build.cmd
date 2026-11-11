@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0post-build.ps1" %*
