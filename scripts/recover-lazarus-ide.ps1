# Remove LCA packages from the IDE link list and rebuild lazarus.exe (emergency recovery).
param(
    [switch]$SkipBuildIde
)

$ErrorActionPreference = 'Stop'

function Resolve-LazBuild {
    if ($env:LAZBUILD) {
        $candidate = $env:LAZBUILD
        if ((Test-Path -LiteralPath $candidate -PathType Container)) {
            $candidate = Join-Path $candidate 'lazbuild.exe'
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }
    foreach ($path in @('C:\lazarus\lazbuild.exe', 'C:\Program Files\Lazarus\lazbuild.exe')) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    Write-Error 'lazbuild not found. Add Lazarus to PATH or set LAZBUILD to lazbuild.exe'
}

$ConfigDir = if ($env:LAZARUSCONFIG) { $env:LAZARUSCONFIG } else { Join-Path $env:LOCALAPPDATA 'lazarus' }
$StaticInc = Join-Path $ConfigDir 'staticpackages.inc'

if (-not (Test-Path -LiteralPath $StaticInc)) {
    Write-Error "staticpackages.inc not found: $StaticInc"
}

Write-Host 'Close Lazarus completely before continuing.'
$lines = Get-Content -LiteralPath $StaticInc
$remove = @('LcaDesignSystem', 'LcaDesignSystemDesign')
$newLines = $lines | Where-Object {
    $trim = $_.Trim().TrimEnd(',')
    $remove -notcontains $trim
}
if ($newLines.Count -eq $lines.Count) {
    Write-Host 'No LCA design packages in staticpackages.inc (nothing to remove).'
} else {
    Set-Content -LiteralPath $StaticInc -Value $newLines -Encoding UTF8
    Write-Host "Updated: $StaticInc (removed LcaDesignSystem / LcaDesignSystemDesign)"
}

if ($SkipBuildIde) {
    Write-Host 'Skipped --build-ide. Run lazbuild --build-ide after closing Lazarus.'
    exit 0
}

$LazBuild = Resolve-LazBuild
Write-Host 'Rebuilding Lazarus IDE...'
& $LazBuild --build-ide
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Recovery complete. Start Lazarus.'
Write-Host 'If startup still hangs, set CodingAgentChatForm Visible=False in environmentoptions.xml (desktop layout), then rebuild IDE again.'
Write-Host 'Reinstall the palette later: scripts\install-lca-lazarus.bat'
