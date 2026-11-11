# Brief launch smoke test for lazycodingagent.exe (Windows CI).
param(
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'resolve-lazycodingagent-output.ps1')

$outDir = Get-LazyCodingAgentOutputDir -ProjectRoot $ProjDir -Context 'smoke-windows-exe'
$exe = Join-Path $outDir $Script:LazyCodingAgentExeName
if (-not (Test-Path -LiteralPath $exe)) {
    throw "smoke-windows-exe: missing $exe"
}

Write-Host "smoke-windows-exe: launching $exe"
$p = Start-Process -FilePath $exe -PassThru
for ($i = 0; $i -lt 15; $i++) {
    if ($p.HasExited) {
        throw "smoke-windows-exe: process exited early with code $($p.ExitCode)"
    }
    Start-Sleep -Seconds 1
}

Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Write-Host 'Smoke test: app still running after 15s (OK)'
