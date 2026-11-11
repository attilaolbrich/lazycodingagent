# Build sqlite3 embed object and link LazySqliteStatic for lazbuild.
#
# Windows: prefer scripts\install-lazarus-sqlite.bat — it runs this file with
# -ExecutionPolicy Bypass. Running .\install-lazarus-sqlite.ps1 directly often fails
# with PSSecurityException when local scripts are disabled.
param(
  [ValidateSet('win32', 'win64')]
  [string]$Arch = 'win64'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Lpk = Join-Path $Root 'packages\LazySqliteStatic\LazySqliteStatic.lpk'

& "$Root\scripts\build-sqlite-static.ps1" -Arch $Arch
& "$Root\scripts\ci-lazbuild.ps1" -VerifyExe:$false --add-package-link $Lpk
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& "$Root\scripts\ci-lazbuild.ps1" -VerifyExe:$false $Lpk
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
Write-Host 'LazySqliteStatic is linked and compiled for lazbuild.'
