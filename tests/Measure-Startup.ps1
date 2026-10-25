<#
.SYNOPSIS
    Measures how much the profile adds to PowerShell startup and fails when it regresses
    against tests/startup-baseline.json.
.DESCRIPTION
    Copies the repo to a temp folder with the same minimal config the Pester suites use, then
    times child processes of the running PowerShell: one warm-up of each (it also builds the
    profile's caches), then -Runs interleaved pairs of a bare start and a start that loads the
    profile. Interleaving keeps runner drift from landing on one side only.

    The gated number is the overhead ratio: (median profile start - median bare start) /
    median bare start. A ratio holds up better than raw milliseconds across hosted runners of
    different speeds.

    A job fails when its ratio is above baseline * (1 + tolerance) AND its overhead grew by more
    than minimumRegressionMs. The second condition keeps a tiny overhead from failing on noise.
    A job with no baseline entry only reports, so the gate can ship before the baseline exists.

    Scope: CI starts are non-interactive, so this covers the load path every shell pays for
    (function stubs, config, aliases, caches), not the splash screen, oh-my-posh, or PSReadLine
    setup, which only run in an interactive console. Use PSPROFILE_TRACE=1 for those.
.PARAMETER Key
    Baseline entry for this OS and PowerShell version, e.g. windows-7.6. CI passes the matrix key.
.PARAMETER Runs
    Timed pairs after the warm-up. Default 7.
.PARAMETER BaselinePath
    Baseline file. Default: startup-baseline.json next to this script.
.PARAMETER OutputFile
    Optional path to write this run's measurement as JSON, in the shape a baseline entry takes.
.EXAMPLE
    ./tests/Measure-Startup.ps1 -Key linux-7.6
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Key,

    [ValidateRange(3, 50)]
    [int]$Runs = 7,

    [string]$BaselinePath = (Join-Path $PSScriptRoot 'startup-baseline.json'),

    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

function Get-Median([double[]]$Values) {
    $sorted = $Values | Sort-Object
    $mid = [int][math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2) { return $sorted[$mid] }
    return ($sorted[$mid - 1] + $sorted[$mid]) / 2
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psprofile-startup-$([guid]::NewGuid().ToString('N'))"
$profileScript = Join-Path (New-PSProfileTestInstall -Destination $scratch) 'profile2.0.ps1'
$cacheRoot = Join-Path $scratch 'cache'
$null = New-Item -Path $cacheRoot -ItemType Directory -Force

$exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$bareArgs = @('-NoLogo', '-NoProfile', '-NonInteractive', '-Command', 'exit 0')
$profileArgs = @('-NoLogo', '-NoProfile', '-NonInteractive', '-Command', ". '$($profileScript.Replace("'", "''"))'; exit 0")

$envOverrides = @{
    LOCALAPPDATA              = $cacheRoot
    XDG_CACHE_HOME            = $cacheRoot
    PSPROFILE_NO_UPDATE_CHECK = '1'
}
$savedEnv = @{}
foreach ($name in $envOverrides.Keys) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
    [Environment]::SetEnvironmentVariable($name, $envOverrides[$name])
}

function Measure-Launch([string[]]$Arguments) {
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = & $exe @Arguments 2>&1 | Out-String
    $watch.Stop()
    if ($LASTEXITCODE -ne 0) { throw "$exe $($Arguments -join ' ') exited with $LASTEXITCODE`n$output" }
    $watch.Elapsed.TotalMilliseconds
}

try {
    $null = Measure-Launch $bareArgs
    $null = Measure-Launch $profileArgs
    $bare = [System.Collections.Generic.List[double]]::new()
    $loaded = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt $Runs; $i++) {
        $bare.Add((Measure-Launch $bareArgs))
        $loaded.Add((Measure-Launch $profileArgs))
    }
}
finally {
    foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name]) }
    Remove-Item -Path $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

$bareMs = Get-Median $bare
$loadedMs = Get-Median $loaded
$overheadMs = $loadedMs - $bareMs
$measured = [ordered]@{
    ratio      = [math]::Round($overheadMs / $bareMs, 3)
    overheadMs = [math]::Round($overheadMs)
    bareMs     = [math]::Round($bareMs)
    profileMs  = [math]::Round($loadedMs)
    runs       = $Runs
    version    = "$($PSVersionTable.PSVersion)"
}

$baseline = Get-Content -Path $BaselinePath -Raw | ConvertFrom-Json
$entry = $baseline.jobs.$Key
$tolerance = [double]$baseline.tolerance
$minimumMs = [double]$baseline.minimumRegressionMs

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("### Startup budget: $Key")
$lines.Add('')
$lines.Add("Bare start $($measured.bareMs) ms, with profile $($measured.profileMs) ms: overhead $($measured.overheadMs) ms, ratio $($measured.ratio) (median of $Runs).")

$failed = $false
if ($entry) {
    $limit = [math]::Round([double]$entry.ratio * (1 + $tolerance), 3)
    $growthMs = $measured.overheadMs - [double]$entry.overheadMs
    $failed = $measured.ratio -gt $limit -and $growthMs -gt $minimumMs
    $verdict = if ($failed) { 'FAIL' } else { 'pass' }
    $lines.Add("Baseline ratio $($entry.ratio), limit $limit; overhead change $([math]::Round($growthMs)) ms (allowed $minimumMs ms). **$verdict**")
}
else {
    $lines.Add("No baseline for $Key yet, so this run only reports. Baseline entry:")
    $lines.Add('')
    $lines.Add('```json')
    $lines.Add("`"$Key`": $($measured | ConvertTo-Json -Compress)")
    $lines.Add('```')
}

$lines | ForEach-Object { Write-Host $_ }
if ($env:GITHUB_STEP_SUMMARY) { $lines | Add-Content -Path $env:GITHUB_STEP_SUMMARY -Encoding UTF8 }
if ($OutputFile) { [ordered]@{ $Key = $measured } | ConvertTo-Json | Set-Content -Path $OutputFile -Encoding UTF8 }

if ($failed) {
    throw "Profile startup overhead for $Key regressed: ratio $($measured.ratio) is over the $limit limit."
}
