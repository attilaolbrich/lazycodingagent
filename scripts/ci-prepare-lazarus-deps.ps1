# Link SynEdit for headless lazbuild (CI or fresh Windows install).
param(
    [string]$LazBuild = $env:LAZBUILD
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot

function Resolve-LazBuild {
    param([string]$Candidate)
    if ($Candidate) {
        if (Test-Path -LiteralPath $Candidate -PathType Container) {
            $Candidate = Join-Path $Candidate 'lazbuild.exe'
        }
        if (Test-Path -LiteralPath $Candidate) { return $Candidate }
    }
    $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($path in @('C:\lazarus\lazbuild.exe', 'C:\Program Files\Lazarus\lazbuild.exe')) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw 'ci-prepare-lazarus-deps: lazbuild not found'
}

function Test-LazarusRoot {
    param([string]$Root)
    if (-not $Root) { return $false }
    return Test-Path -LiteralPath (Join-Path $Root 'components\synedit\synedit.lpk')
}

function Resolve-LazarusRoot {
    param([string]$LazBuildExe)

    $root = Split-Path -Parent $LazBuildExe
    if (Test-LazarusRoot $root) { return $root }

    $roots = @(
        $env:LAZARUS_DIR,
        'C:\lazarus',
        'C:\Program Files\Lazarus'
    ) | Where-Object { $_ }

    foreach ($candidate in $roots) {
        if (Test-LazarusRoot $candidate) { return $candidate }
    }

    throw "ci-prepare-lazarus-deps: Lazarus root not found (lazbuild=$LazBuildExe, LAZARUS_DIR=$($env:LAZARUS_DIR))"
}

function Link-And-Build {
    param([string]$Lpk, [string]$Laz)
    if (-not (Test-Path -LiteralPath $Lpk)) { throw "missing $Lpk" }
    if (-not [string]::IsNullOrWhiteSpace($env:LAZARUS_PRIMARY_CONFIG)) {
        $ciLazbuild = Join-Path $ScriptDir 'ci-lazbuild.ps1'
        & $ciLazbuild -VerifyExe:$false --add-package-link $Lpk
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $ciLazbuild -VerifyExe:$false $Lpk
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        return
    }
    & $Laz --add-package-link $Lpk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $Laz $Lpk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$LazBuildExe = Resolve-LazBuild -Candidate $LazBuild
$LazarusRoot = Resolve-LazarusRoot -LazBuildExe $LazBuildExe

$synLpk = Join-Path $LazarusRoot 'components\synedit\synedit.lpk'

Link-And-Build -Lpk $synLpk -Laz $LazBuildExe
$dsgn = Join-Path (Split-Path $synLpk) 'syneditdsgn.lpk'
if (Test-Path -LiteralPath $dsgn) {
    Link-And-Build -Lpk $dsgn -Laz $LazBuildExe
}

Write-Host "ci-prepare-lazarus-deps: SynEdit linked (LAZARUS_ROOT=$LazarusRoot)."
