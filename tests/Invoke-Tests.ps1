<#
.SYNOPSIS
    Runs the PSProfile Pester suites, the same way CI does.
.DESCRIPTION
    Requires Pester 6 (Install-Module Pester -MinimumVersion 6.0 -Scope CurrentUser -SkipPublisherCheck).
    Exits non-zero when any test fails so it can gate CI.
.PARAMETER Path
    Test files or folders to run. Defaults to every *.Tests.ps1 in this folder.
.PARAMETER OutputFile
    Optional NUnit XML results path, for CI test reporting.
.EXAMPLE
    ./tests/Invoke-Tests.ps1
.EXAMPLE
    ./tests/Invoke-Tests.ps1 -Path ./tests/Functions.Tests.ps1
#>
[CmdletBinding()]
param(
    [string[]]$Path = $PSScriptRoot,
    [string]$OutputFile
)

$pester = Get-Module -Name Pester -ListAvailable | Where-Object Version -ge '6.0.0' | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) { throw 'Pester 6 or newer is required: Install-Module Pester -MinimumVersion 6.0 -Scope CurrentUser -SkipPublisherCheck' }
Import-Module $pester -Force

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
if ($OutputFile) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = $OutputFile
}

Invoke-Pester -Configuration $config
