# Install TerminalEmulator + LCA Design System packages for Lazarus IDE and lazbuild.
#
# Windows: prefer scripts\install-lca-lazarus.bat — it runs this file with
# -ExecutionPolicy Bypass. Running .\install-lca-lazarus.ps1 directly often fails
# with PSSecurityException when local scripts are disabled.
param(
    [switch]$LinkOnly,
    [switch]$SkipTerminal,
    [string]$WidgetSet = $env:LCL_WIDGETSET
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$TE = Join-Path $Root 'third_party\TerminalEmulator'
$LpkTF = Join-Path $TE 'TerminalFramework\TerminalFramework.lpk'
$LpkView = Join-Path $TE 'ViewLCL\ViewLCL.lpk'
$LpkRuntime = Join-Path $Root 'packages\LcaDesignSystem\LcaDesignSystem.lpk'
$LpkDesign = Join-Path $Root 'packages\LcaDesignSystem\LcaDesignSystemDesign.lpk'
$LcaDesignLib = Join-Path $Root 'packages\LcaDesignSystem\lib\x86_64-win64-design'

function Invoke-LcaGlyphBuild {
    $glyphScript = Join-Path $PSScriptRoot 'build-lca-glyphs.bat'
    $outRes = Join-Path $Root 'packages\LcaDesignSystem\res\lca_design_glyphs.res'
    if (-not (Test-Path -LiteralPath $glyphScript)) {
        if (-not (Test-Path -LiteralPath $outRes)) {
            Write-Error "Missing LCA palette glyphs: $outRes (build-lca-glyphs.bat not found)"
        }
        Write-Warning "Skipping glyph rebuild; using existing $outRes"
        return
    }
    & $glyphScript
    if ($LASTEXITCODE -ne 0) {
        if (-not (Test-Path -LiteralPath $outRes)) {
            Write-Error "LCA palette glyph build failed and $outRes is missing. Install Lazarus lazres or restore the .res from git."
        }
        Write-Warning 'build-lca-glyphs.bat failed; continuing with existing lca_design_glyphs.res'
    }
}

function Clear-LcaDesignPackageOutput {
    param([string]$DesignLibDir)
    if (-not (Test-Path -LiteralPath $DesignLibDir)) {
        return
    }
    $files = Get-ChildItem -LiteralPath $DesignLibDir -File -ErrorAction SilentlyContinue
    if (-not $files) {
        return
    }
    Write-Host "Clearing stale LcaDesignSystemDesign output in: $DesignLibDir"
    $files | Remove-Item -Force
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
    foreach ($path in @('C:\lazarus\lazbuild.exe', 'C:\Program Files\Lazarus\lazbuild.exe')) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    Write-Error 'lazbuild not found. Add Lazarus to PATH or set LAZBUILD to lazbuild.exe'
}

$LazBuild = Resolve-LazBuild

function Invoke-LazBuild {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if (-not [string]::IsNullOrWhiteSpace($env:LAZARUS_PRIMARY_CONFIG)) {
        if ($WidgetSet) {
            $env:LCL_WIDGETSET = $WidgetSet
        }
        $ciLazbuild = Join-Path $PSScriptRoot 'ci-lazbuild.ps1'
        & $ciLazbuild -VerifyExe:$false @Args
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        return
    }
    if ($WidgetSet) {
        & $LazBuild --widgetset=$WidgetSet @Args
    } else {
        & $LazBuild @Args
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($WidgetSet) {
    Write-Host "Using LCL widgetset: $WidgetSet"
}

if (-not $SkipTerminal) {
    if (-not (Test-Path -LiteralPath $LpkTF)) {
        Write-Error 'Missing vendored terminal: third_party/TerminalEmulator (TerminalFramework.lpk not found)'
    }
    Invoke-LazBuild --add-package-link $LpkTF
    Invoke-LazBuild --add-package-link $LpkView
    Invoke-LazBuild $LpkTF
    Invoke-LazBuild $LpkView
}

Invoke-LazBuild --add-package-link $LpkRuntime
Invoke-LazBuild $LpkRuntime --build-all

if (-not $LinkOnly) {
    Invoke-LcaGlyphBuild
    Clear-LcaDesignPackageOutput -DesignLibDir $LcaDesignLib
    Invoke-LazBuild --add-package $LpkDesign
    Invoke-LazBuild $LpkDesign --build-all
    Write-Host ''
    Write-Host 'Close Lazarus completely before rebuilding the IDE (required for the component palette).'
    Write-Host 'Rebuilding Lazarus IDE with LcaDesignSystemDesign (runtime stays out of lazarus.exe)...'
    Invoke-LazBuild --build-ide
    Write-Host ''
    Write-Host 'IDE rebuild complete. Start Lazarus and open the Component palette page: LCA Design.'
    Write-Host 'Form designer: close and reopen mainunit.pas (F12); nav rail should show light cells with dark symbols.'
    Write-Host 'If Lazarus hangs on startup, run: scripts\recover-lazarus-ide.bat'
} else {
    Write-Host 'Link-only: runtime packages linked for lazbuild (no IDE design install).'
}

if ($WidgetSet) {
    Write-Host "Done. Build the app with: lazbuild --widgetset=$WidgetSet lazycodingagent.lpi"
} else {
    Write-Host 'Done. Open lazycodingagent.lpi in Lazarus or run: lazbuild lazycodingagent.lpi'
}
