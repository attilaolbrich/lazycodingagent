@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0.."
set "TEST_OUTPUT=%TEMP%\lazycodingagent-tests-%RANDOM%"
mkdir "%TEST_OUTPUT%" || exit /b 1
set "LAZARUS_DIR=%LAZARUS_DIR%"
if not defined LAZARUS_DIR if defined ProgramFiles if exist "%ProgramFiles%\Lazarus" set "LAZARUS_DIR=%ProgramFiles%\Lazarus"
if not defined LAZARUS_DIR if defined ProgramFiles(x86) if exist "%ProgramFiles(x86)%\Lazarus" set "LAZARUS_DIR=%ProgramFiles(x86)%\Lazarus"
if not defined LAZARUS_DIR set "LAZARUS_DIR=C:\lazarus"
if not exist "%LAZARUS_DIR%\components\lazutils" (
  echo Error: Set LAZARUS_DIR to the Lazarus installation directory.
  goto :fail
)
set "FLAGS=-Mobjfpc -Scghi -Fu. -Fu"%LAZARUS_DIR%\components\lazutils\lib\x86_64-win64" -FU"%TEST_OUTPUT%" -FE"%TEST_OUTPUT%""
fpc %FLAGS% tests\tool_driver.lpr >"%TEST_OUTPUT%\tool-build.log" 2>&1 || goto :show_tool
fpc %FLAGS% tests\test_agent_rules.pas >"%TEST_OUTPUT%\rules-build.log" 2>&1 || goto :show_rules
fpc %FLAGS% tests\test_web_fetch.lpr >"%TEST_OUTPUT%\web-fetch-build.log" 2>&1 || goto :show_web_fetch
"%TEST_OUTPUT%\test_agent_rules.exe" "%TEST_OUTPUT%\rules-fixture" || goto :fail
"%TEST_OUTPUT%\test_web_fetch.exe" "tests\fixtures\web_fetch\sample.html" || goto :fail
where python >nul 2>&1 && set "PY=python"
if not defined PY where py >nul 2>&1 && set "PY=py -3"
if not defined PY (
  echo Error: Python 3 is required for integration tests.
  goto :fail
)
%PY% tests\test_local_tools.py "%TEST_OUTPUT%\tool_driver.exe" || goto :fail
echo All LazyCodingAgent tool tests passed.
goto :cleanup

:show_tool
type "%TEST_OUTPUT%\tool-build.log"
goto :fail

:show_rules
type "%TEST_OUTPUT%\rules-build.log"
goto :fail

:show_web_fetch
type "%TEST_OUTPUT%\web-fetch-build.log"
goto :fail

:fail
echo Tests failed. Logs are in %TEST_OUTPUT%
exit /b 1

:cleanup
rmdir /s /q "%TEST_OUTPUT%"
exit /b 0
