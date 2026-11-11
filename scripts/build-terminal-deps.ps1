# Register and compile TerminalEmulator Lazarus packages for lazycodingagent.
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$TE = Join-Path $Root 'third_party\TerminalEmulator'
$LpkTF = Join-Path $TE 'TerminalFramework\TerminalFramework.lpk'
$LpkView = Join-Path $TE 'ViewLCL\ViewLCL.lpk'

if (-not (Test-Path -LiteralPath $LpkTF)) {
    Write-Error 'Missing vendored terminal: third_party/TerminalEmulator (TerminalFramework.lpk not found)'
}

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
    $candidates = @(
        'C:\lazarus\lazbuild.exe',
        'C:\Program Files\Lazarus\lazbuild.exe'
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    Write-Error 'lazbuild not found. Add Lazarus to PATH or set LAZBUILD to lazbuild.exe'
}

$LazBuild = Resolve-LazBuild

& $LazBuild --add-package-link $LpkTF
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $LazBuild --add-package-link $LpkView
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'TerminalFramework and ViewLCL are linked for lazbuild.'
