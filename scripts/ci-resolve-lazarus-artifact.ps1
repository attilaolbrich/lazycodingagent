# Resolve a CI Lazarus/FPC blob: optional repo cache -> workdir -> SourceForge.
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetId,
    [Parameter(Mandatory = $true)]
    [string]$FileName,
    [Parameter(Mandatory = $true)]
    [string]$DestPath
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$ManifestPath = Join-Path $ScriptDir 'lazarus-ci-artifacts.json'

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "ci-resolve-lazarus-artifact: missing manifest $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$target = $manifest.targets.$TargetId
if (-not $target) {
    throw "ci-resolve-lazarus-artifact: unknown target $TargetId"
}

$fileEntry = $target.files | Where-Object { $_.name -eq $FileName } | Select-Object -First 1
if (-not $fileEntry) {
    throw "ci-resolve-lazarus-artifact: file $FileName not in target $TargetId"
}

$sfBase = if ($env:LAZARUS_SF_MIRROR) { $env:LAZARUS_SF_MIRROR } else { $target.sfBase }
$minBytes = if ($null -ne $fileEntry.minBytes) { [int]$fileEntry.minBytes } else { 0 }
$validatePeMz = if ($null -ne $fileEntry.validatePeMz) { [bool]$fileEntry.validatePeMz } else { $false }

$workDir = if ($env:CI_LAZARUS_WORKDIR) {
    $env:CI_LAZARUS_WORKDIR
} else {
    switch ($TargetId) {
        'windows-win64' { Join-Path $env:RUNNER_TEMP 'lazarus-ci-win64' }
        default { Join-Path $env:RUNNER_TEMP 'lazarus-ci-win64' }
    }
}

$artifactsDir = if ($env:LAZARUS_ARTIFACTS_DIR) {
    $env:LAZARUS_ARTIFACTS_DIR
} else {
    Join-Path $RootDir 'tools/lazarus-artifacts'
}

$destParent = Split-Path -Parent $DestPath
if ($destParent -and -not (Test-Path -LiteralPath $destParent)) {
    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
}

function Test-ArtifactValid {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $len = (Get-Item -LiteralPath $Path).Length
    if ($minBytes -gt 0 -and $len -lt $minBytes) {
        return $false
    }
    if ($validatePeMz) {
        $header = [System.IO.File]::ReadAllBytes($Path)[0..1]
        if ($header[0] -ne 0x4D -or $header[1] -ne 0x5A) {
            return $false
        }
    }
    return $true
}

function Copy-ArtifactIfValid {
    param([string]$Source)

    if (-not (Test-ArtifactValid -Path $Source)) {
        return $false
    }
  $srcFull = (Resolve-Path -LiteralPath $Source).Path
  $destFull = [System.IO.Path]::GetFullPath($DestPath)
  if ($srcFull -ne $destFull) {
    Copy-Item -LiteralPath $Source -Destination $DestPath -Force
  }
    Write-Host "ci-resolve-lazarus-artifact: using $Source"
    return $true
}

if (Test-ArtifactValid -Path $DestPath) {
    Write-Host "ci-resolve-lazarus-artifact: dest already valid: $DestPath"
    exit 0
}

$candidates = @(
    (Join-Path $artifactsDir $FileName),
    (Join-Path $workDir $FileName)
)

foreach ($c in $candidates) {
    if (Copy-ArtifactIfValid -Source $c) {
        exit 0
    }
}

$url = "$($sfBase.TrimEnd('/'))/$FileName"
Write-Host "ci-resolve-lazarus-artifact: downloading $url"

$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($curl) {
    & curl.exe -fL --retry 3 --retry-delay 5 -o $DestPath $url
    if ($LASTEXITCODE -ne 0) {
        throw "ci-resolve-lazarus-artifact: curl.exe failed with exit code $LASTEXITCODE"
    }
} else {
    Invoke-WebRequest -Uri $url -OutFile $DestPath -UseBasicParsing -UserAgent 'curl/8.0'
}

if (-not (Test-ArtifactValid -Path $DestPath)) {
    $size = if (Test-Path -LiteralPath $DestPath) { (Get-Item -LiteralPath $DestPath).Length } else { 0 }
    Remove-Item -LiteralPath $DestPath -Force -ErrorAction SilentlyContinue
    throw "ci-resolve-lazarus-artifact: downloaded file failed validation ($size bytes)"
}

$len = (Get-Item -LiteralPath $DestPath).Length
Write-Host "ci-resolve-lazarus-artifact: download OK ($len bytes)"
