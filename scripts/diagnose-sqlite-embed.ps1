# Log undefined symbols in MSVC sqlite3_embed.o (dev / CI diagnostics).
param(
  [string]$EmbedObj = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $EmbedObj) {
  $EmbedObj = Join-Path $Root 'packages\LazySqliteStatic\src\sqlite3_embed.o'
}
if (-not (Test-Path -LiteralPath $EmbedObj -PathType Leaf)) {
  throw "diagnose-sqlite-embed: missing $EmbedObj"
}

function Get-EmbedNm {
  $winGetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if (Test-Path -LiteralPath $winGetRoot -PathType Container) {
    foreach ($pkg in Get-ChildItem -Path $winGetRoot -Filter 'BrechtSanders.WinLibs*' -Directory -ErrorAction SilentlyContinue) {
      $p = Join-Path $pkg.FullName 'mingw64\bin\nm.exe'
      if (Test-Path $p) { return $p }
    }
  }
  $p = 'C:\Program Files\Git\usr\bin\nm.exe'
  if (Test-Path $p) { return $p }
  throw 'diagnose-sqlite-embed: nm not found'
}

$nm = Get-EmbedNm
Write-Host "diagnose-sqlite-embed: $EmbedObj"
& $nm -u $EmbedObj 2>&1 | ForEach-Object { Write-Host $_ }
