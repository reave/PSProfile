<#
.SYNOPSIS
    CI only: installs the newest patch of a PowerShell release line next to the runner's own
    pwsh and puts it first on PATH for the job's later steps.
.DESCRIPTION
    Hosted runners ship one pwsh, whichever release the image maintainers picked. This pins a
    job to a release line (7.4, 7.6) instead. It downloads the portable archive rather than the
    MSI/pkg so it never replaces the runner's install, and resolves the newest patch at run
    time so CI tracks the servicing releases users get.
.PARAMETER Version
    Release line as major.minor, e.g. 7.6.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$headers = @{ 'User-Agent' = 'PSProfile-CI' }
if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
$releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=100' -Headers $headers
$linePattern = '^v' + [regex]::Escape($Version) + '\.\d+$'
$latest = $releases | Where-Object { -not $_.prerelease -and -not $_.draft -and $_.tag_name -match $linePattern } |
    ForEach-Object { [version]($_.tag_name.TrimStart('v')) } |
    Sort-Object -Descending | Select-Object -First 1
if (-not $latest) { throw "No stable PowerShell $Version release found." }

$arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }
$asset = if ($IsWindows) { "PowerShell-$latest-win-$arch.zip" }
elseif ($IsMacOS) { "powershell-$latest-osx-$arch.tar.gz" }
else { "powershell-$latest-linux-$arch.tar.gz" }

$root = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$archive = Join-Path $root $asset
$target = Join-Path $root "pwsh-$latest"
Write-Host "Installing PowerShell $latest ($asset) to $target"
Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$latest/$asset" -OutFile $archive -Headers $headers

$null = New-Item -Path $target -ItemType Directory -Force
if ($IsWindows) {
    Expand-Archive -Path $archive -DestinationPath $target -Force
}
else {
    tar -xzf $archive -C $target
    if ($LASTEXITCODE -ne 0) { throw "tar exited with $LASTEXITCODE" }
    chmod +x (Join-Path $target 'pwsh')
}

$exeName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
$installed = & (Join-Path $target $exeName) -NoProfile -NoLogo -Command '$PSVersionTable.PSVersion.ToString()'
if ("$installed".Trim() -ne "$latest") { throw "Expected PowerShell $latest, the extracted pwsh reports '$installed'." }

if ($env:GITHUB_PATH) { Add-Content -Path $env:GITHUB_PATH -Value $target }
