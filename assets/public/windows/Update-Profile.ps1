<#
.SYNOPSIS
    Updates the installed PSProfile from GitHub and reloads it into the current session.
.DESCRIPTION
    Runs `git pull --ff-only` in the PSProfile install directory ($Global:PSProfileRoot,
    set by profile.ps1) and, unless -SkipReload is passed, re-dot-sources
    $PROFILE.CurrentUserAllHosts afterward so the update takes effect immediately.
    The pull never touches assets\config\config.json, because it's gitignored. After the pull,
    Update-ProfileConfig adds any new settings from sample-config.json to config.json and keeps
    your own settings as they are.

    Only works for a git-based install. If PSProfile was installed via the zip fallback
    (no git available at install time), this stops with a pointer to re-run setup.ps1
    instead, since that's the only path that can refresh a non-git install.

    After reloading, also calls Update-Completion to refresh the cached native
    completions (config.json's NativeCompletions) for whichever of those tools are
    installed - see Update-Completion for why that's cached rather than run on every
    normal profile load.
.PARAMETER SkipReload
    Update the repo but don't re-dot-source the profile afterward. Implies -SkipCompletions,
    since Update-Completion needs the reloaded profile's functions to be current.
.PARAMETER SkipCompletions
    Update and reload the profile but don't run Update-Completion afterward.
.PARAMETER SkipConfig
    Update the profile but don't run Update-ProfileConfig on config.json.
.EXAMPLE
    Update-Profile
.EXAMPLE
    Update-Profile -SkipReload
.OUTPUTS
    None
#>
function Update-Profile {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
        Justification = 'profile.ps1 sets PSProfileRoot so functions in other files can find the install.')]
    param(
        [switch]$SkipReload,
        [switch]$SkipCompletions,
        [switch]$SkipConfig
    )

    # Show informational messages unless the caller chose otherwise with -InformationAction.
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { $InformationPreference = 'Continue' }

    $installPath = $Global:PSProfileRoot
    if (-not $installPath -or -not (Test-Path -Path $installPath)) {
        Write-Error 'Could not determine the PSProfile install directory ($Global:PSProfileRoot is unset).'
        return
    }

    if (-not (Test-Path -Path (Join-Path $installPath '.git'))) {
        Write-Warning ("This PSProfile install at $installPath isn't a git checkout, so it can't be updated " +
            "in place. Re-run setup.ps1 to refresh it instead:`n" +
            "irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex")
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

        Write-Information -MessageData 'PSProfile updated.'

        # Load Update-ProfileConfig from the files just pulled, so the newest migration runs, and
        # bring config.json up to date before the profile reloads with it.
        if (-not $SkipConfig) {
            $configUpdater = Join-Path $PSScriptRoot 'Update-ProfileConfig.ps1'
            if (Test-Path -Path $configUpdater) {
                . $configUpdater
                Update-ProfileConfig
            }
        }

        if (-not $SkipReload) {
            $profileTarget = $PROFILE.CurrentUserAllHosts
            if (Test-Path -Path $profileTarget) {
                Write-Verbose 'Reloading profile...'
                . $profileTarget

                if (-not $SkipCompletions) {
                    Update-Completion
                }
            } else {
                Write-Warning "Could not find $profileTarget to reload. Restart your shell to pick up the update."
            }
        }
    }
}
