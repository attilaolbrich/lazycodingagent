# Download CI Lazarus/FPC artifacts into tools/lazarus-artifacts/.
param(
    [string[]]$TargetId
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$OutDir = if ($env:LAZARUS_ARTIFACTS_DIR) { $env:LAZARUS_ARTIFACTS_DIR } else { Join-Path $RootDir 'tools/lazarus-artifacts' }
$ManifestPath = Join-Path $ScriptDir 'lazarus-ci-artifacts.json'

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$targets = @($TargetId)
if ($targets.Count -eq 0 -or ($targets.Count -eq 1 -and [string]::IsNullOrWhiteSpace($targets[0]))) {
    $targets = @($manifest.targets.PSObject.Properties.Name | Sort-Object)
}

foreach ($tid in $targets) {
    $t = $manifest.targets.$tid
    if (-not $t) {
        throw "prefetch-lazarus-ci-artifacts: unknown target $tid"
    }
    foreach ($ent in $t.files) {
        $dest = Join-Path $OutDir $ent.name
        & (Join-Path $ScriptDir 'ci-resolve-lazarus-artifact.ps1') -TargetId $tid -FileName $ent.name -DestPath $dest
    }
}

Write-Host "prefetch-lazarus-ci-artifacts: done -> $OutDir"
