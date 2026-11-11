# Resolve Win64 MinGW-w64 bin/lib (WinLibs, MSYS2, or PATH). Used for SQLite embed link.
param(
  [ValidateSet('Bin', 'Lib', 'Gcc')]
  [string]$What = 'Lib'
)

$ErrorActionPreference = 'Stop'

function Find-MingwRoot {
  $candidates = @(
    'C:\tools\mingw64',
    'C:\msys64\mingw64',
    'C:\Program Files\mingw-w64\x86_64-8.1.0-win32-seh-rt_v6-rev0\mingw64'
  )
  $winGetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if (Test-Path -LiteralPath $winGetRoot -PathType Container) {
    foreach ($pkg in Get-ChildItem -Path $winGetRoot -Filter 'BrechtSanders.WinLibs*' -Directory -ErrorAction SilentlyContinue) {
      $candidates += Join-Path $pkg.FullName 'mingw64'
    }
  }
  foreach ($root in ($candidates | Select-Object -Unique)) {
    $gcc = Join-Path $root 'bin\x86_64-w64-mingw32-gcc.exe'
    if (Test-Path -LiteralPath $gcc -PathType Leaf) {
      return $root
    }
  }
  $gccCmd = Get-Command x86_64-w64-mingw32-gcc -ErrorAction SilentlyContinue
  if ($gccCmd -and $gccCmd.Source) {
    return (Split-Path -Parent (Split-Path -Parent $gccCmd.Source))
  }
  return $null
}

$root = Find-MingwRoot
if (-not $root) {
  throw 'resolve-mingw-win64: MinGW-w64 not found (install WinLibs via winget or MSYS2 mingw64)'
}

switch ($What) {
  'Bin' { Write-Output (Join-Path $root 'bin') }
  'Lib' { Write-Output (Join-Path $root 'lib') }
  'Gcc' { Write-Output (Join-Path $root 'bin\x86_64-w64-mingw32-gcc.exe') }
}
