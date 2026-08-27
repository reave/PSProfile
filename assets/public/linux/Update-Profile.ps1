<#
.SYNOPSIS
    Updates the installed PSProfile from GitHub and reloads it into the current session.
.DESCRIPTION
    Runs `git pull --ff-only` in the PSProfile install directory ($Global:PSProfileRoot,
    set by profile2.0.ps1) and, unless -SkipReload is passed, re-dot-sources
    $PROFILE.CurrentUserAllHosts afterward so the update takes effect immediately.
    Never touches assets\config\config.json - it's gitignored, so a pull can't overwrite it.

    Only works for a git-based install. If PSProfile was installed via the zip fallback
    (no git available at install time), this stops with a pointer to re-run setup.ps1
    instead, since that's the only path that can refresh a non-git install.
.PARAMETER SkipReload
    Update the repo but don't re-dot-source the profile afterward.
.EXAMPLE
    Update-Profile
.EXAMPLE
    Update-Profile -SkipReload
.OUTPUTS
    None
#>
function Update-Profile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipReload
    )

    $installPath = $Global:PSProfileRoot
    if (-not $installPath -or -not (Test-Path -Path $installPath)) {
        Write-Error 'Could not determine the PSProfile install directory ($Global:PSProfileRoot is unset).'
        return
    }

    if (-not (Test-Path -Path (Join-Path $installPath '.git'))) {
        Write-Warning "This PSProfile install at $installPath isn't a git checkout, so it can't be updated in place. Re-run setup.ps1 to refresh it instead:`nirm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex"
        return
    }

    if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
        Write-Error 'git is required to update PSProfile in place.'
        return
    }

    if ($PSCmdlet.ShouldProcess($installPath, 'git pull --ff-only')) {
        git -C $installPath pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git pull failed with exit code $LASTEXITCODE."
            return
        }

        Write-Host 'PSProfile updated.' -ForegroundColor Green

        if (-not $SkipReload) {
            $profileTarget = $PROFILE.CurrentUserAllHosts
            if (Test-Path -Path $profileTarget) {
                Write-Host 'Reloading profile...' -ForegroundColor Cyan
                . $profileTarget
            }
            else {
                Write-Warning "Could not find $profileTarget to reload. Restart your shell to pick up the update."
            }
        }
    }
}
