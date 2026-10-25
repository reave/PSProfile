<#
.SYNOPSIS
    Runs the PSProfile Pester suites, the same way CI does.
.DESCRIPTION
    Requires Pester 5.5+ (Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser).
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

$pester = Get-Module -Name Pester -ListAvailable | Where-Object Version -ge '5.5.0' | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) { throw 'Pester 5.5 or newer is required: Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser' }
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
