<#
.SYNOPSIS
    Checks for the latest PowerShell release and upgrades via winget if newer.
.DESCRIPTION
    Queries the PowerShell GitHub repo's latest release tag, compares it against
    $PSVersionTable.PSVersion, and if a newer release exists, upgrades using
    `winget upgrade --id Microsoft.PowerShell`. Requires winget.
.EXAMPLE
    Update-PowerShell
.OUTPUTS
    None
#>
function Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
        Write-Warning 'winget is required to update PowerShell automatically.'
        return
    }

    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -ErrorAction Stop
        $currentVersion = [version]$PSVersionTable.PSVersion
        $latestVersion = [version]($release.tag_name -replace '^v', '')

        if ($currentVersion -ge $latestVersion) {
            Write-Host "PowerShell $currentVersion is up to date." -ForegroundColor Green
            return
        }

        if ($PSCmdlet.ShouldProcess("PowerShell $currentVersion", "Upgrade to $latestVersion")) {
            winget upgrade --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Error "winget failed to update PowerShell. Exit code: $LASTEXITCODE"
                return
            }
            Write-Host 'PowerShell has been updated. Restart your shell to use the new version.' -ForegroundColor Magenta
        }
    }
    catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
