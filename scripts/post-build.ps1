# Copy help/ and assets/ next to the built executable (post lazbuild).
param(
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

. (Join-Path $ScriptDir 'resolve-lazycodingagent-output.ps1')

function Copy-TreeReplace {
    param(
        [string]$Source,
        [string]$Dest
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Host "post-build: skip missing $Source"
        return
    }
    $srcFull = [System.IO.Path]::GetFullPath($Source)
    $destFull = [System.IO.Path]::GetFullPath($Dest)
    if ($srcFull -eq $destFull) {
        return
    }
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Dest -Recurse -Force
}

$outDir = Get-LazyCodingAgentOutputDir -ProjectRoot $ProjDir -Explicit $TargetDir -Context 'post-build'
foreach ($destRoot in @($outDir, $ProjDir)) {
    Copy-TreeReplace -Source (Join-Path $ProjDir 'help') -Dest (Join-Path $destRoot 'help')
    Copy-TreeReplace -Source (Join-Path $ProjDir 'assets') -Dest (Join-Path $destRoot 'assets')
    Write-Host "post-build: deployed help/ and assets/ to $destRoot"
}
