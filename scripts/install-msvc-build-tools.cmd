@echo off
REM Install MSVC for scripts\build-sqlite-static.ps1 (NOT the same as Visual Studio Code).
echo.
echo This installs Microsoft Visual Studio BUILD TOOLS with the C++ workload.
echo Visual Studio Code ^(the editor^) does NOT include cl.exe.
echo.
echo You may be prompted for administrator approval; the download is large ^(several GB^).
echo.
setlocal
winget install --id Microsoft.VisualStudio.BuildTools -e ^
  --accept-package-agreements --accept-source-agreements ^
  --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
set ERR=%ERRORLEVEL%
if not %ERR%==0 (
  echo.
  echo winget exit code %ERR%. If install failed, open Visual Studio Installer manually
  echo and add workload "Desktop development with C++".
  exit /b %ERR%
)
echo.
echo Build Tools install finished. Close this window, open a NEW terminal, then run:
echo   scripts\install-lazarus-sqlite.bat
exit /b 0
