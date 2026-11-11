# Compile third_party/sqlite/sqlite3.c to a COFF object for LazySqliteStatic (Windows).
# Windows default: MinGW-w64 gcc object + FPC internal linker, MinGW import .a via ci-lazbuild -k.
# Optional SQLITE_CC=msvc|clang for experimental MSVC COFF objects (see third_party/sqlite/README.md).
param(
  [ValidateSet('win32', 'win64')]
  [string]$Arch = 'win64'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root 'third_party\sqlite\sqlite3.c'
if (-not (Test-Path -LiteralPath $Src)) {
  throw "Missing $Src"
}

if ($Arch -eq 'win32') {
  $OutDir = Join-Path $Root 'packages\LazySqliteStatic\lib\i386-win32'
} else {
  $OutDir = Join-Path $Root 'packages\LazySqliteStatic\lib\x86_64-win64'
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Out = Join-Path $OutDir 'sqlite3.obj'

$MinEmbedBytes = 500000

function Assert-SqliteEmbedObject {
  param(
    [string]$Path,
    [string]$Label
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "build-sqlite-static: missing $Label at $Path"
  }
  $len = (Get-Item -LiteralPath $Path).Length
  if ($len -lt $MinEmbedBytes) {
    throw "build-sqlite-static: $Label too small ($len bytes, expected >= $MinEmbedBytes): $Path"
  }
}

function Get-VcVarsBatchName {
  param([string]$TargetArch)
  if ($TargetArch -eq 'win32') { 'vcvars32.bat' } else { 'vcvars64.bat' }
}

function Resolve-VcVarsBatch {
  param([string]$TargetArch)

  if ($env:SQLITE_MSVC_VCVARS) {
    if (Test-Path -LiteralPath $env:SQLITE_MSVC_VCVARS -PathType Leaf) {
      return $env:SQLITE_MSVC_VCVARS
    }
    throw "SQLITE_MSVC_VCVARS is set but not found: $($env:SQLITE_MSVC_VCVARS)"
  }

  $name = Get-VcVarsBatchName -TargetArch $TargetArch
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
    foreach ($requires in @(
        'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        $null
      )) {
      if ($requires) {
        $installRoot = & $vswhere -latest -products * -requires $requires -property installationPath 2>$null
      } else {
        $installRoot = & $vswhere -latest -products * -property installationPath 2>$null
      }
      if (-not [string]::IsNullOrWhiteSpace($installRoot)) {
        $vcvars = Join-Path $installRoot "VC\Auxiliary\Build\$name"
        if (Test-Path -LiteralPath $vcvars -PathType Leaf) {
          return $vcvars
        }
      }
    }
  }

  foreach ($root in @(
      (Join-Path $env:ProgramFiles 'Microsoft Visual Studio'),
      (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio')
    )) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
    $hit = Get-ChildItem -Path $root -Recurse -Filter $name -File -ErrorAction SilentlyContinue |
      Where-Object { $_.DirectoryName -match '\\Auxiliary\\Build$' } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($hit) {
      return $hit.FullName
    }
  }
  return $null
}

function Test-MsvcClInPath {
  $cl = Get-Command cl.exe -ErrorAction SilentlyContinue
  if (-not $cl -or -not $cl.Source) {
    return $false
  }
  if ($cl.Source -match '\\fpc\\') {
    return $false
  }
  $testC = Join-Path $env:TEMP "sqlite-cl-test-$([Guid]::NewGuid().ToString('N')).c"
  $testO = Join-Path $env:TEMP "sqlite-cl-test-$([Guid]::NewGuid().ToString('N')).obj"
  try {
    Set-Content -LiteralPath $testC -Value 'int x(void){return 0;}' -Encoding ASCII
    & $cl.Source /nologo /c /W0 /Fo$testO $testC 2>$null
    return ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $testO -PathType Leaf))
  } finally {
    Remove-Item -LiteralPath $testC, $testO -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-SqliteCompileMingw {
  param(
    [string]$OutObj,
    [string]$SourceC
  )

  if (Test-Path -LiteralPath $OutObj -PathType Leaf) {
    Remove-Item -LiteralPath $OutObj -Force
  }

  $resolve = Join-Path $PSScriptRoot 'resolve-mingw-win64.ps1'
  $gcc = & $resolve -What Gcc
  $defines = '-DSQLITE_ENABLE_FTS5=1 -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_JSON1=1'
  $flags = '-c -O2 -Wno-discarded-qualifiers'
  $line = "`"$gcc`" $flags $defines -o `"$OutObj`" `"$SourceC`""
  Write-Host "build-sqlite-static: $line"
  cmd /c $line
  if ($LASTEXITCODE -ne 0) {
    throw "build-sqlite-static: MinGW gcc failed compiling sqlite3.c (exit $LASTEXITCODE)"
  }
  if (-not (Test-Path -LiteralPath $OutObj -PathType Leaf)) {
    throw "build-sqlite-static: MinGW gcc did not produce $OutObj"
  }
}

function Invoke-SqliteCompileClangMsvc {
  param(
    [string]$OutObj,
    [string]$SourceC
  )

  if (Test-Path -LiteralPath $OutObj -PathType Leaf) {
    Remove-Item -LiteralPath $OutObj -Force
  }

  $clang = Get-Command clang -ErrorAction SilentlyContinue
  if (-not $clang -or -not $clang.Source) {
    throw 'build-sqlite-static: SQLITE_CC=clang but clang not found on PATH (install LLVM)'
  }

  $defines = '-DSQLITE_ENABLE_FTS5=1 -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_JSON1=1'
  $flags = @(
    '-c', '-O2', '-w', '-target', 'x86_64-pc-windows-msvc',
    '-fno-function-sections', '-fno-data-sections',
    '-D_CRT_SECURE_NO_WARNINGS'
  ) -join ' '
  $line = "`"$($clang.Source)`" $flags $defines -o `"$OutObj`" `"$SourceC`""
  Write-Host "build-sqlite-static: $line"
  cmd /c $line
  if ($LASTEXITCODE -ne 0) {
    throw "build-sqlite-static: clang failed compiling sqlite3.c (exit $LASTEXITCODE)"
  }
  if (-not (Test-Path -LiteralPath $OutObj -PathType Leaf)) {
    throw "build-sqlite-static: clang did not produce $OutObj"
  }
  Remove-MsvcObjectDrectve -Path $OutObj
}

function Invoke-SqliteCompileMsvc {
  param(
    [string]$OutObj,
    [string]$SourceC,
    [string]$VcVars = ''
  )

  if (Test-Path -LiteralPath $OutObj -PathType Leaf) {
    Remove-Item -LiteralPath $OutObj -Force
  }

  $defines = '/DSQLITE_ENABLE_FTS5=1 /DSQLITE_THREADSAFE=1 /DSQLITE_ENABLE_JSON1=1'
  # FPC 3.2.x internal linker rejects MSVC associative COMDAT .pdata/.xdata (function-level linking).
  $clFlags = @(
    '/nologo', '/c', '/TC', '/O2', '/W0', '/utf-8', '/MD', '/Zl',
    '/Gy-', '/GS-', '/guard:cf-'
  ) -join ' '
  $clLine = "cl.exe $clFlags $defines /Fo`"$OutObj`" `"$SourceC`""
  Write-Host "build-sqlite-static: $clLine"
  if ($VcVars) {
    $cmd = "`"$VcVars`" >nul && $clLine"
    cmd /c $cmd
  } else {
    cmd /c $clLine
  }
  if ($LASTEXITCODE -ne 0) {
    throw "build-sqlite-static: cl.exe failed compiling sqlite3.c (exit $LASTEXITCODE)"
  }
  if (-not (Test-Path -LiteralPath $OutObj -PathType Leaf)) {
    throw "build-sqlite-static: cl.exe did not produce $OutObj"
  }
  Remove-MsvcObjectDrectve -Path $OutObj
}

function Resolve-ObjCopy {
  $candidates = @(
    'C:\Program Files\Git\usr\bin\objcopy.exe',
    'C:\tools\mingw64\bin\objcopy.exe',
    'C:\msys64\mingw64\bin\objcopy.exe'
  )
  $winGetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if (Test-Path -LiteralPath $winGetRoot -PathType Container) {
    foreach ($pkg in Get-ChildItem -Path $winGetRoot -Filter 'BrechtSanders.WinLibs*' -Directory -ErrorAction SilentlyContinue) {
      $candidates += Join-Path $pkg.FullName 'mingw64\bin\objcopy.exe'
    }
  }
  $pathObjcopy = Get-Command objcopy -ErrorAction SilentlyContinue
  if ($pathObjcopy -and $pathObjcopy.Source -notmatch '\\fpc\\') {
    $candidates += $pathObjcopy.Source
  }
  foreach ($path in ($candidates | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      return $path
    }
  }
  return $null
}

function Remove-MsvcObjectDrectve {
  param([string]$Path)

  $objcopy = Resolve-ObjCopy
  if (-not $objcopy) {
    $msg = 'build-sqlite-static: objcopy not found; cannot strip .drectve (install Git for Windows usr bin, WinLibs, or MSYS2 mingw64)'
    if ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true') {
      throw $msg
    }
    Write-Host "$msg — continuing; lazbuild -Xe link may fail"
    return
  }
  $tmp = "$Path.drectve-stripped"
  & $objcopy -R .drectve $Path $tmp
  if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    throw "build-sqlite-static: objcopy failed stripping .drectve (exit $LASTEXITCODE)"
  }
  Move-Item -LiteralPath $tmp -Destination $Path -Force
  Write-Host "build-sqlite-static: stripped .drectve from $Path"
}

function Throw-MsvcNotFound {
  throw @'
build-sqlite-static: MSVC cl.exe not found (Visual Studio BUILD TOOLS with "Desktop development with C++").
Visual Studio Code is only an editor — it does NOT include cl.exe. MinGW gcc objects cannot be used here.

Install (pick one):
  • From repo root: scripts\install-msvc-build-tools.bat
  • winget install --id Microsoft.VisualStudio.BuildTools -e
    then add workload "Desktop development with C++" in Visual Studio Installer
  • https://visualstudio.microsoft.com/visual-cpp-build-tools/

After install, open a NEW terminal and run: scripts\install-lazarus-sqlite.bat
Or use "x64 Native Tools Command Prompt for VS". Optional: SQLITE_MSVC_VCVARS=path\to\vcvars64.bat
'@
}

$vcvars = Resolve-VcVarsBatch -TargetArch $Arch
$ccMode = if ($env:SQLITE_CC) { $env:SQLITE_CC.ToLowerInvariant() } else { '' }

function Test-MingwGccAvailable {
  try {
    $resolve = Join-Path $PSScriptRoot 'resolve-mingw-win64.ps1'
    if (-not (Test-Path -LiteralPath $resolve)) { return $false }
    $null = & $resolve -What Gcc 2>$null
    return $true
  } catch {
    return $false
  }
}

if ($ccMode -eq 'mingw' -or (($ccMode -eq '') -and (Test-MingwGccAvailable))) {
  Write-Host 'build-sqlite-static: MinGW-w64 gcc (Windows static embed)'
  Invoke-SqliteCompileMingw -OutObj $Out -SourceC $Src
} elseif ($ccMode -eq 'clang') {
  Write-Host 'build-sqlite-static: SQLITE_CC=clang (MSVC ABI via LLVM)'
  Invoke-SqliteCompileClangMsvc -OutObj $Out -SourceC $Src
} elseif ($vcvars) {
  Write-Host "build-sqlite-static: using MSVC via $vcvars"
  Invoke-SqliteCompileMsvc -VcVars $vcvars -OutObj $Out -SourceC $Src
} elseif (Test-MsvcClInPath) {
  Write-Host 'build-sqlite-static: using cl.exe from PATH (Developer Command Prompt environment)'
  Invoke-SqliteCompileMsvc -OutObj $Out -SourceC $Src
} elseif ($ccMode -eq 'msvc' -or $ccMode -eq 'cl') {
  Throw-MsvcNotFound
} else {
  throw "build-sqlite-static: unknown SQLITE_CC=$($env:SQLITE_CC) (use mingw, msvc, or clang)"
}

$SrcObj = Join-Path $Root 'packages\LazySqliteStatic\src\sqlite3_embed.o'
$LibEmbed = Join-Path $OutDir 'sqlite3_embed.o'
Copy-Item -Force $Out $SrcObj
Copy-Item -Force $Out $LibEmbed
Assert-SqliteEmbedObject -Path $SrcObj -Label 'sqlite3_embed.o (src)'
Assert-SqliteEmbedObject -Path $LibEmbed -Label 'sqlite3_embed.o (lib)'
Write-Host "Built $Out ($SrcObj and $LibEmbed)"
