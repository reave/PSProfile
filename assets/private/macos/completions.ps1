##- Registering Auto-Completion for Windows Terminal
#
# Each tool's completer lives in its own file under .\completions\ and is only
# dot-sourced (and therefore only parsed) when that tool is actually present.
# This used to be one ~1100-line file always parsed in full on every profile
# load regardless of which of these CLIs were installed - dot-sourcing forces
# a full parse of whatever file you point it at, so gating had to happen at
# the file-selection level, not with an `if` inside a single big file.
if (Get-Command -Name winget -ErrorAction SilentlyContinue) { . "$PSScriptRoot\completions\winget.ps1" }
if (Get-Command -Name dotnet -ErrorAction SilentlyContinue) { . "$PSScriptRoot\completions\dotnet.ps1" }
if (Get-Command -Name op -ErrorAction SilentlyContinue) { . "$PSScriptRoot\completions\op.ps1" }
if (Get-Command -Name oh-my-posh -ErrorAction SilentlyContinue) { . "$PSScriptRoot\completions\oh-my-posh.ps1" }

# config.json's NativeCompletions: tools with their own `completion powershell`-style generator.
# The generated script is cached under .\completions\native\<name>.ps1 by Update-Completions
# (called from Update-Profile/setup.ps1) rather than run here - shelling out to each tool on
# every profile load would be slow (especially anything backed by a daemon, e.g. docker) and
# would defeat the whole point of caching. A tool with no cache yet just gets skipped until
# Update-Completions has run once.
foreach ($__nc in $PSProfileConfig.NativeCompletions) {
    if (-not (Get-Command -Name $__nc.Name -ErrorAction SilentlyContinue)) { continue }
    $__ncCache = Join-Path $PSScriptRoot "completions\native\$($__nc.Name).ps1"
    if (Test-Path -Path $__ncCache) { . $__ncCache }
}
Remove-Variable -Name __nc, __ncCache -ErrorAction SilentlyContinue
