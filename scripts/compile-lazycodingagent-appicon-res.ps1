# Compile lazycodingagent.rc -> lazycodingagent_appicon.res (EXE shell icon).
# Primary: Windows SDK rc.exe. Fallback: FPC windres (local Lazarus / MinGW).
param(
    [string]$ProjRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$RcFile = '',
    [string]$OutRes = ''
)

$ErrorActionPreference = 'Stop'

if ($RcFile -eq '') {
    $RcFile = Join-Path $ProjRoot 'lazycodingagent.rc'
}
if ($OutRes -eq '') {
    $OutRes = Join-Path $ProjRoot 'lazycodingagent_appicon.res'
}

$RcFile = [System.IO.Path]::GetFullPath($RcFile)
$OutRes = [System.IO.Path]::GetFullPath($OutRes)
$ProjRoot = [System.IO.Path]::GetFullPath($ProjRoot)

if (-not (Test-Path -LiteralPath $RcFile)) {
    Write-Error "compile-appicon-res: missing $RcFile"
    exit 1
}

function Find-SdkRcExe {
    $kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (-not (Test-Path -LiteralPath $kitsRoot)) {
        return $null
    }
    $candidates = Get-ChildItem -LiteralPath $kitsRoot -Recurse -Filter rc.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\rc\.exe$' } |
        Sort-Object { $_.FullName } -Descending
    if ($candidates) {
        return $candidates[0]
    }
    return $null
}

function Find-FpcWindres {
    $paths = @(
        'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe',
        'C:\Program Files\Lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe'
    )
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) {
            return $p
        }
    }
    $globs = @()
    if ($env:LAZARUS_DIR) {
        $globs += Join-Path $env:LAZARUS_DIR 'fpc\*\bin\x86_64-win64\windres.exe'
    }
    if ($env:LAZBUILD) {
        $lazRoot = Split-Path -Parent $env:LAZBUILD
        $globs += Join-Path $lazRoot 'fpc\*\bin\x86_64-win64\windres.exe'
    }
    $globs += 'C:\lazarus\fpc\*\bin\x86_64-win64\windres.exe'
    foreach ($pattern in $globs) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName } -Descending |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    return $null
}

Push-Location -LiteralPath $ProjRoot
try {
    $rc = Find-SdkRcExe
    if ($rc) {
        Write-Host "compile-appicon-res: using $($rc.FullName)"
        & $rc.FullName /nologo '/fo', $OutRes, $RcFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "compile-appicon-res: wrote $OutRes"
            exit 0
        }
        Write-Warning "compile-appicon-res: rc.exe exited $LASTEXITCODE; trying windres fallback"
    }
    else {
        Write-Warning 'compile-appicon-res: Windows SDK rc.exe not found; trying windres fallback'
    }

    $windres = Find-FpcWindres
    if (-not $windres) {
        Write-Error 'compile-appicon-res: need Windows SDK rc.exe or FPC windres.exe'
        exit 1
    }

    $fpcBin = Split-Path -Parent $windres
    $env:PATH = "$fpcBin;$env:PATH"
    Write-Host "compile-appicon-res: using $windres"
    & $windres -J rc -O res -i $RcFile -o $OutRes
    if ($LASTEXITCODE -ne 0) {
        Write-Error "compile-appicon-res: windres failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Host "compile-appicon-res: wrote $OutRes"
}
finally {
    Pop-Location
}
