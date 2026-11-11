# Master owl_icon.png -> BMP resource + EXE .ico (see gen-owl-branding.bat).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'gen-owl-branding.bat')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
