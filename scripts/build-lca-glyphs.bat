@echo off
setlocal EnableDelayedExpansion
set "ROOT=%~dp0.."
set "GLYPH_DIR=%ROOT%\packages\LcaDesignSystem\res\glyphs"
set "OUT_RES=%ROOT%\packages\LcaDesignSystem\res\lca_design_glyphs.res"

set "LAZRES="
if defined LAZRES goto :have_lazres
if defined LAZARUS_DIR if exist "%LAZARUS_DIR%\tools\lazres.exe" set "LAZRES=%LAZARUS_DIR%\tools\lazres.exe"
if not defined LAZRES if defined LAZBUILD for %%I in ("%LAZBUILD%") do if exist "%%~dpItools\lazres.exe" set "LAZRES=%%~dpItools\lazres.exe"
if not defined LAZRES if exist "C:\lazarus\tools\lazres.exe" set "LAZRES=C:\lazarus\tools\lazres.exe"
if not defined LAZRES if exist "C:\Program Files\Lazarus\tools\lazres.exe" set "LAZRES=C:\Program Files\Lazarus\tools\lazres.exe"
:have_lazres
if not defined LAZRES (
  echo lazres not found
  exit /b 1
)

set "PNG_ARGS="
set "GLYPH_COUNT=0"
pushd "%GLYPH_DIR%"
for %%F in (*.png) do (
  set /a GLYPH_COUNT+=1
  set "PNG_ARGS=!PNG_ARGS! %%F"
)
popd
if !GLYPH_COUNT! equ 0 (
  echo No PNG glyphs in %GLYPH_DIR%
  exit /b 1
)

del /f /q "%OUT_RES%" 2>nul
pushd "%GLYPH_DIR%"
"%LAZRES%" "%OUT_RES%"!PNG_ARGS!
set ERR=!ERRORLEVEL!
popd
if !ERR! neq 0 exit /b !ERR!
if not exist "%OUT_RES%" (
  echo lazres did not create %OUT_RES%
  exit /b 1
)
echo Wrote %OUT_RES% (!GLYPH_COUNT! glyph(s))
exit /b 0
