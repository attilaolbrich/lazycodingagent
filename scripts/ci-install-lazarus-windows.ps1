# Install pinned FPC + Lazarus 4.8 from SourceForge for GitHub Actions (Chocolatey lags behind IDE).
param(
    [string]$InstallDir = $env:CI_LAZARUS_ROOT
)

$ErrorActionPreference = 'Stop'

$TargetId = 'windows-win64'
$InstallerName = 'lazarus-4.8-fpc-3.2.2-win64.exe'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$workDir = if ($env:CI_LAZARUS_WORKDIR) { $env:CI_LAZARUS_WORKDIR } else { Join-Path $env:RUNNER_TEMP 'lazarus-ci-win64' }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

if (-not $InstallDir) {
    $InstallDir = Join-Path $workDir 'lazarus-install'
}

$lazBuild = Join-Path $InstallDir 'lazbuild.exe'
if (Test-Path -LiteralPath $lazBuild) {
    Write-Host "ci-install-lazarus-windows: Lazarus already present at $InstallDir"
} else {
    $installerPath = Join-Path $workDir $InstallerName
    & (Join-Path $ScriptDir 'ci-resolve-lazarus-artifact.ps1') -TargetId $TargetId -FileName $InstallerName -DestPath $installerPath

    if (Test-Path -LiteralPath $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
    }

    Write-Host "ci-install-lazarus-windows: installing to $InstallDir"
    $proc = Start-Process -FilePath $installerPath -ArgumentList @(
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        "/DIR=$InstallDir"
    ) -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "ci-install-lazarus-windows: installer exit code $($proc.ExitCode)"
    }
    if (-not (Test-Path -LiteralPath $lazBuild)) {
        throw "ci-install-lazarus-windows: lazbuild not found after install: $lazBuild"
    }
}

$env:LAZARUS_DIR = $InstallDir
$env:LAZBUILD = $lazBuild
if (-not $env:LAZARUS_PRIMARY_CONFIG) {
    $primaryConfig = Join-Path $workDir 'primary-config'
    New-Item -ItemType Directory -Path $primaryConfig -Force | Out-Null
    $env:LAZARUS_PRIMARY_CONFIG = $primaryConfig
}

& $env:LAZBUILD --version

if ($env:GITHUB_ENV) {
    function Format-GithubEnvPath {
        param([string]$Path)
        if (-not $Path) { return $Path }
        return $Path.Replace('\', '/')
    }

    @(
        "LAZARUS_DIR=$(Format-GithubEnvPath $InstallDir)"
        "LAZBUILD=$(Format-GithubEnvPath $lazBuild)"
        "LAZARUS_PRIMARY_CONFIG=$(Format-GithubEnvPath $env:LAZARUS_PRIMARY_CONFIG)"
    ) | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8NoBOM
}

Write-Host "ci-install-lazarus-windows: ready (LAZARUS_DIR=$InstallDir, LAZBUILD=$lazBuild)"
