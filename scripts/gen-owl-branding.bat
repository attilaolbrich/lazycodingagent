@echo off
REM Master owl_icon.png -> owl_icon.bmp + owl_icon.res + lazycodingagent.ico + appicon.res
setlocal
set "ROOT=%~dp0.."
set "PNG=%ROOT%\packages\LcaDesignSystem\res\owl_icon.png"
set "BMP=%ROOT%\packages\LcaDesignSystem\res\owl_icon.bmp"
set "OWLRES=%ROOT%\packages\LcaDesignSystem\res\owl_icon.res"
set "ICO=%ROOT%\res\lazycodingagent.ico"
set "RC=%ROOT%\lazycodingagent.rc"
set "APPICON=%ROOT%\lazycodingagent_appicon.res"

python "%~dp0write_bmp_ico.py" "%PNG%" "%BMP%" 128
if errorlevel 1 exit /b 1

set "LAZRES="
if not defined LAZRES if defined LAZARUS_DIR if exist "%LAZARUS_DIR%\tools\lazres.exe" set "LAZRES=%LAZARUS_DIR%\tools\lazres.exe"
if not defined LAZRES if defined LAZBUILD for %%I in ("%LAZBUILD%") do if exist "%%~dpItools\lazres.exe" set "LAZRES=%%~dpItools\lazres.exe"
if not defined LAZRES if exist "C:\lazarus\tools\lazres.exe" set "LAZRES=C:\lazarus\tools\lazres.exe"
if not defined LAZRES if exist "C:\Program Files\Lazarus\tools\lazres.exe" set "LAZRES=C:\Program Files\Lazarus\tools\lazres.exe"
if not defined LAZRES (
  echo lazres not found
  exit /b 1
)
pushd "%ROOT%\packages\LcaDesignSystem\res"
"%LAZRES%" owl_icon.res owl_icon.bmp=OWL_ICON
if errorlevel 1 (
  popd
  exit /b 1
)
popd

python "%~dp0write_bmp_ico.py" "%PNG%" "%ICO%"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0compile-lazycodingagent-appicon-res.ps1"
if errorlevel 1 exit /b 1

echo Wrote %BMP%, %OWLRES%, %ICO%, %APPICON%
