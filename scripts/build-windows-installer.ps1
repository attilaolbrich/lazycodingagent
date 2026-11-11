# Build LazyCodingAgent Windows installer with Inno Setup (ISCC).
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'resolve-lazycodingagent-output.ps1')

function Format-IsccDefinePath {
    param([string]$Path)
    # Inno preprocessor treats backslashes as escapes in /D values (e.g. D:\a\... -> \a).
    return ($Path -replace '\\', '/')
}

function Resolve-Iscc {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    foreach ($path in @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        )) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw 'build-windows-installer: ISCC.exe not found. Install Inno Setup 6 or add ISCC to PATH.'
}

if ($Version -match '[^\d\.\-\+a-zA-Z]') {
    throw "build-windows-installer: invalid version string: $Version"
}

$sourceDirRaw = Get-LazyCodingAgentOutputDir -ProjectRoot $ProjDir -Explicit $TargetDir -Context 'build-windows-installer'
$sourceDir = (Resolve-Path -LiteralPath $sourceDirRaw).Path

$repoDir = (Resolve-Path -LiteralPath $ProjDir).Path
$issPath = Join-Path $ProjDir 'installer\lazycodingagent.iss'
if (-not (Test-Path -LiteralPath $issPath)) {
    throw "build-windows-installer: missing $issPath"
}

$distDir = Join-Path $ProjDir 'dist'
if (-not (Test-Path -LiteralPath $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

$iscc = Resolve-Iscc
$setupName = "LazyCodingAgent-$Version-win64-Setup.exe"
$setupPath = Join-Path $distDir $setupName

Write-Host "build-windows-installer: ISCC $iscc"
Write-Host "build-windows-installer: version=$Version source=$sourceDir"

$sourceDirIscc = Format-IsccDefinePath $sourceDir
$repoDirIscc = Format-IsccDefinePath $repoDir

& $iscc `
    "/DMyAppVersion=$Version" `
    "/DSourceDir=$sourceDirIscc" `
    "/DRepoDir=$repoDirIscc" `
    $issPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -LiteralPath $setupPath)) {
    throw "build-windows-installer: expected output not found: $setupPath"
}

Write-Host "build-windows-installer: $setupPath"
Write-Output $setupPath
