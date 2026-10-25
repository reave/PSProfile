<#
.SYNOPSIS
    Updates the installed PSProfile (git or zip install), validates it, and installs missing
    dependencies. Can also just check for an update, or roll back the last one.
.DESCRIPTION
    Works for both install types setup.ps1 can produce:
      - git install: `git pull --ff-only` in the install directory.
      - zip install: downloads the latest commit, validates it in a staging folder next to
        the install, then swaps it in. The old tree is kept as .<name>.previous.

    Before an update goes live it's validated: every .ps1 must parse, and profile2.0.ps1 is
    loaded in a separate profile-less PowerShell process, which must not throw. A git update
    that fails validation is reset back to the previous commit automatically; a zip update
    that fails is never swapped in. The same child process then refreshes the profile's caches
    with the new code (Update-PSProfileCache, if defined, and Update-Completions).

    Afterward, any configured Modules/Packages from config.json that are missing get
    installed (startup only warns about them). Never touches assets\config\config.json.

    The new version takes effect in new shells. Run `. $PROFILE` to load it into this one.
.PARAMETER CheckOnly
    Only check whether an update is available (and which configured dependencies are
    missing). Same check the profile runs in the background once a day.
.PARAMETER Rollback
    Return to the version that was installed before the last Update-Profile. The update
    notice then stays quiet until a commit newer than the rolled-back one is published.
.PARAMETER SkipDependencies
    Don't install missing configured modules/packages after updating.
.PARAMETER SkipValidation
    Skip loading the new profile in a child process before accepting the update (the parse
    check still runs). Also skips the cache/completion refresh that runs in that process.
.EXAMPLE
    Update-Profile
.EXAMPLE
    Update-Profile -CheckOnly
.EXAMPLE
    Update-Profile -Rollback
.OUTPUTS
    None
#>
function Update-Profile {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Update')]
    param(
        [Parameter(ParameterSetName = 'Check')]
        [switch]$CheckOnly,

        [Parameter(ParameterSetName = 'Rollback')]
        [switch]$Rollback,

        [Parameter(ParameterSetName = 'Update')]
        [switch]$SkipDependencies,

        [Parameter(ParameterSetName = 'Update')]
        [switch]$SkipValidation
    )

    $installPath = $Global:PSProfileRoot
    if (-not $installPath -or -not (Test-Path -Path $installPath)) {
        Write-Error 'Could not determine the PSProfile install directory ($Global:PSProfileRoot is unset).'
        return
    }

    $lifecycle = Join-Path $installPath 'assets/lib/PSProfile.Lifecycle.ps1'
    if (-not (Test-Path -Path $lifecycle)) {
        Write-Error "Missing $lifecycle. Re-run setup.ps1 to repair the install:`nirm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex"
        return
    }
    . $lifecycle

    try {
        if ($CheckOnly) {
            $result = Test-PSProfileUpdate -InstallPath $installPath
            if ($result.LastCheckError) { Write-Warning "Update check failed: $($result.LastCheckError)" }
            elseif ($result.UpdateAvailable) {
                $detail = if ($result.CommitsBehind) { "$($result.CommitsBehind) new commit(s)" } else { 'a newer version' }
                Write-Host "PSProfile update available: $detail. Run Update-Profile to install it." -ForegroundColor Yellow
            }
            else { Write-Host 'PSProfile is up to date.' -ForegroundColor Green }

            $missing = @($result.MissingModules) + @($result.MissingPackages) | Where-Object { $_ }
            if ($missing) { Write-Host "Missing dependencies: $($missing -join ', '). Run Update-Profile to install them." -ForegroundColor Yellow }
            return
        }

        if ($Rollback) {
            Undo-PSProfileUpdate -InstallPath $installPath
            return
        }

        $updated = Invoke-PSProfileUpdate -InstallPath $installPath -SkipSmokeTest:$SkipValidation

        if (-not $SkipDependencies) {
            Install-PSProfileDependency -InstallPath $installPath
        }

        if ($updated) {
            Write-Host 'Open a new shell, or run `. $PROFILE`, to load the new version. Undo with Update-Profile -Rollback.' -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "Update-Profile failed: $_"
    }
}
