# Resolve directory containing lazycodingagent.exe after lazbuild (CI and local Windows).
$Script:LazyCodingAgentExeName = 'lazycodingagent.exe'

function Find-FpcCommand {
    $onPath = Get-Command fpc -ErrorAction SilentlyContinue
    if ($onPath) {
        return $onPath.Source
    }
    $fixed = @(
        'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe',
        'C:\Program Files\Lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe'
    )
    foreach ($p in $fixed) {
        if (Test-Path -LiteralPath $p) {
            return $p
        }
    }
    $globs = @()
    if ($env:LAZARUS_DIR) {
        $globs += Join-Path $env:LAZARUS_DIR 'fpc\*\bin\x86_64-win64\fpc.exe'
    }
    $globs += 'C:\lazarus\fpc\*\bin\x86_64-win64\fpc.exe'
    foreach ($pattern in $globs) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName } -Descending |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    return $null
}

function Test-LazyCodingAgentExeInDir {
    param([string]$Dir)
    if (-not $Dir) { return $false }
    $exe = Join-Path $Dir $Script:LazyCodingAgentExeName
    return Test-Path -LiteralPath $exe
}

function Get-LazyCodingAgentOutputDir {
    param(
        [string]$ProjectRoot,
        [string]$Explicit = '',
        [string]$Context = 'resolve-output'
    )

    $projectRootFull = [System.IO.Path]::GetFullPath($ProjectRoot)
    $searched = [System.Collections.Generic.List[string]]::new()

    if ($Explicit -ne '') {
        $explicitFull = [System.IO.Path]::GetFullPath($Explicit)
        $searched.Add($explicitFull)
        if (Test-LazyCodingAgentExeInDir -Dir $explicitFull) {
            return $explicitFull
        }
        $exePath = Join-Path $explicitFull $Script:LazyCodingAgentExeName
        throw "${Context}: missing $exePath (run lazbuild first, or pass a -TargetDir that contains the executable)"
    }

    $candidates = [System.Collections.Generic.List[string]]::new()

    $fpcExe = Find-FpcCommand
    if ($fpcExe) {
        $cpu = & $fpcExe -iTP 2>$null
        $os = & $fpcExe -iTO 2>$null
        if ($cpu -and $os) {
            $candidates.Add((Join-Path $projectRootFull "lib\$cpu-$os"))
        }
    }

    $candidates.Add((Join-Path $projectRootFull 'lib\x86_64-win64'))
    $candidates.Add($projectRootFull)

    foreach ($dir in $candidates) {
        if ($searched.Contains($dir)) { continue }
        $searched.Add($dir)
        if (Test-LazyCodingAgentExeInDir -Dir $dir) {
            return $dir
        }
    }

    $list = ($searched | ForEach-Object { "  $_\$($Script:LazyCodingAgentExeName)" }) -join [Environment]::NewLine
    throw @"
${Context}: $($Script:LazyCodingAgentExeName) not found. Run lazbuild on lazycodingagent.lpi first.
Searched:
$list
"@
}
