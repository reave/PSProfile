<#
.SYNOPSIS
    Installs, updates, or uninstalls this PowerShell profile on the current machine.
.DESCRIPTION
    Downloads the reave/PSProfile repository (via `git clone`/`git pull` when git is
    available, falling back to a zip download otherwise) into a local install directory,
    creates a personal assets\config\config.json from sample-config.json if one doesn't
    already exist, installs the modules and packages config.json lists, and points
    $PROFILE.CurrentUserAllHosts at the installed profile2.0.ps1.

    Safe to re-run: updates the install in place without touching an existing config.json,
    and backs up any pre-existing $PROFILE content (preserving it, appended below the new
    stub) instead of discarding it.

    A zip install is downloaded and validated in a staging folder next to the install
    directory, then swapped in whole, so files removed upstream don't linger. The previous
    tree is kept for Update-Profile -Rollback.

    Before finishing, the installed profile is loaded once in a separate PowerShell process,
    which checks it loads cleanly and builds its caches (cached native completions for
    config.json's NativeCompletions, and anything else Update-PSProfileCache maintains).
.PARAMETER InstallPath
    Where to install the profile repo. Default: a "PSProfile" folder under
    ~/.config/powershell (created if missing).
.PARAMETER Branch
    Git branch / archive ref to install. Default: main.
.PARAMETER SkipProfileLink
    Download/update the repo but don't touch $PROFILE. Useful if you'd rather
    dot-source profile2.0.ps1 yourself from an existing profile.
.PARAMETER SkipDependencies
    Don't install the Modules and Packages listed in config.json. The profile warns at
    startup about any that are missing; Update-Profile installs them later.
.PARAMETER Uninstall
    Remove PSProfile: restore $PROFILE.CurrentUserAllHosts to what it was before setup.ps1
    linked it (or delete it if setup.ps1 created it), then delete the install directory and
    PSProfile's cache/state folder. config.json is backed up next to $PROFILE first.
    Installed modules and packages are left alone.
.PARAMETER Force
    With -Uninstall, don't ask for confirmation.
.EXAMPLE
    irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex
.EXAMPLE
    &([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -InstallPath 'C:\PSProfile' -Branch 'develop'
.EXAMPLE
    &([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -Uninstall
#>
[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $HOME '.config/powershell/PSProfile'),
    [string]$Branch = 'main',
    [switch]$SkipProfileLink,
    [switch]$SkipDependencies,
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
# git writes routine progress info to stderr; PS7.3+'s native-command error
# preference would otherwise turn that into a terminating error under Stop.
$PSNativeCommandUseErrorActionPreference = $false

$Repository = 'reave/PSProfile'
$RepoUrl = "https://github.com/$Repository"
$ProfileMarker = '# Managed by PSProfile'
$PreservedHeader = '# --- Original profile content (preserved below) ---'

function Write-SetupStep {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-SetupStateDirectory {
    # Same location as Get-PSProfileStateDirectory in assets/lib/PSProfile.Lifecycle.ps1. Kept
    # inline so -Uninstall still works when the install directory is already gone or broken.
    $isWin = $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'
    $base = if ($isWin) { $env:LOCALAPPDATA } elseif ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
    return Join-Path $base 'PSProfile'
}

function Uninstall-PSProfile {
    param([string]$InstallPath, [switch]$Force)

    $profileTarget = $PROFILE.CurrentUserAllHosts
    $parent = Split-Path -Path $InstallPath -Parent
    $leaf = Split-Path -Path $InstallPath -Leaf
    $sideDirs = @('previous', 'staging', 'rolledback', 'swap') | ForEach-Object { Join-Path $parent ".$leaf.$_" }
    $stateDir = Get-SetupStateDirectory

    Write-Host 'This will:' -ForegroundColor Yellow
    Write-Host "  - restore $profileTarget to its pre-PSProfile content (or remove it if setup.ps1 created it)"
    Write-Host "  - delete $InstallPath (config.json is backed up first)"
    Write-Host "  - delete $stateDir (update state and caches)"
    Write-Host '  Installed modules and packages are left alone.'
    if (-not $Force) {
        $answer = Read-Host 'Continue? [y/N]'
        if ($answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled.'; return }
    }

    $configPath = Join-Path $InstallPath 'assets/config/config.json'
    if (Test-Path -Path $configPath) {
        $profileDir = Split-Path -Path $profileTarget -Parent
        if (-not (Test-Path -Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        $configBackup = Join-Path $profileDir "PSProfile-config.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        Copy-Item -Path $configPath -Destination $configBackup
        Write-SetupStep "Backed up config.json to $configBackup"
    }

    if (Test-Path -Path $profileTarget) {
        $content = Get-Content -Path $profileTarget -Raw
        if ($content -and $content.Contains($ProfileMarker)) {
            $index = $content.IndexOf($PreservedHeader)
            if ($index -ge 0) {
                $original = $content.Substring($index + $PreservedHeader.Length).TrimStart("`r", "`n")
                Set-Content -Path $profileTarget -Value $original -NoNewline
                Write-SetupStep "Restored the original content of $profileTarget"
            }
            else {
                Remove-Item -Path $profileTarget -Force
                Write-SetupStep "Removed $profileTarget"
            }
        }
        else {
            Write-Warning "$profileTarget doesn't contain the PSProfile link - left it alone."
        }
    }

    foreach ($dir in @($InstallPath) + $sideDirs + @($stateDir)) {
        if (Test-Path -Path $dir) {
            Remove-Item -Path $dir -Recurse -Force
            Write-SetupStep "Deleted $dir"
        }
    }

    Write-Host ''
    Write-Host 'PSProfile uninstalled. Restart your shell.' -ForegroundColor Green
}

try {
    $InstallPath = [System.IO.Path]::GetFullPath($InstallPath)

    if ($Uninstall) {
        Uninstall-PSProfile -InstallPath $InstallPath -Force:$Force
        return
    }

    $isGitRepo = Test-Path -Path (Join-Path $InstallPath '.git')
    $hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
    $installDirIsEmpty = -not (Test-Path -Path $InstallPath) -or
    ((Get-ChildItem -Path $InstallPath -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)

    if ($isGitRepo) {
        Write-SetupStep "Updating existing install at $InstallPath (git pull)"
        git -C $InstallPath pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull failed with exit code $LASTEXITCODE" }
    }
    elseif ($hasGit -and $installDirIsEmpty) {
        Write-SetupStep "Cloning $RepoUrl to $InstallPath"
        git clone --branch $Branch $RepoUrl $InstallPath
        if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }
    }
    else {
        # No git, or the install directory already holds a zip install. The download/stage/swap
        # logic lives in the lifecycle helper, fetched from the same branch being installed.
        Write-SetupStep "Downloading $Repository@$Branch as a zip archive"
        $lifecycleUrl = "https://raw.githubusercontent.com/$Repository/$Branch/assets/lib/PSProfile.Lifecycle.ps1"
        $lifecycleSource = (Invoke-WebRequest -Uri $lifecycleUrl -UseBasicParsing).Content
        . ([ScriptBlock]::Create($lifecycleSource))

        $staging = Save-PSProfileArchive -InstallPath $InstallPath -Repository $Repository -Branch $Branch
        Write-SetupStep "Validating and installing to $InstallPath"
        Install-PSProfileStaged -StagingPath $staging -InstallPath $InstallPath
    }

    $profileScript = Join-Path $InstallPath 'profile2.0.ps1'
    if (-not (Test-Path -Path $profileScript -PathType Leaf)) {
        throw "profile2.0.ps1 not found at $profileScript after install - something went wrong."
    }

    # From here on, use the helper from the version just installed.
    . (Join-Path $InstallPath 'assets/lib/PSProfile.Lifecycle.ps1')

    $configDir = Join-Path $InstallPath 'assets/config'
    $configPath = Join-Path $configDir 'config.json'
    $samplePath = Join-Path $configDir 'sample-config.json'
    if (-not (Test-Path -Path $configPath) -and (Test-Path -Path $samplePath)) {
        Write-SetupStep "Creating personal config at $configPath from sample-config.json"
        Copy-Item -Path $samplePath -Destination $configPath
    }

    if (-not $SkipProfileLink) {
        $profileTarget = $PROFILE.CurrentUserAllHosts

        $profileDir = Split-Path -Path $profileTarget -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        $existingContent = if (Test-Path -Path $profileTarget) { Get-Content -Path $profileTarget -Raw } else { $null }

        if ($existingContent -and $existingContent.Contains($ProfileMarker)) {
            Write-SetupStep "Profile at $profileTarget already links to PSProfile - leaving it alone"
        }
        else {
            if ($existingContent) {
                $backupPath = "$profileTarget.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Write-SetupStep "Backing up existing profile to $backupPath"
                Copy-Item -Path $profileTarget -Destination $backupPath -Force
            }

            Write-SetupStep "Linking $profileTarget to $profileScript"
            @"
$ProfileMarker (https://github.com/reave/PSProfile) - edit assets/config/config.json in
# the install directory for personal customization instead of editing this file.
. "$profileScript"
"@ | Set-Content -Path $profileTarget

            if ($existingContent) {
                Add-Content -Path $profileTarget -Value "`n$PreservedHeader`n$existingContent"
            }
        }
    }

    # Windows PowerShell 5.1 defaults to Restricted on client SKUs, which blocks $PROFILE from
    # loading at all. pwsh 7 defaults to RemoteSigned, so this only ever fires on 5.1 or where
    # someone set Restricted by hand. AllSigned and Group Policy settings are left alone.
    if (-not $SkipProfileLink -and ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') -and (Get-ExecutionPolicy) -eq 'Restricted') {
        try {
            Write-SetupStep 'Execution policy is Restricted, which blocks profiles - setting RemoteSigned for the current user'
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        }
        catch { Write-Warning "Could not set the execution policy, so the profile may not load: $_" }
    }

    # Non-fatal from here on: the profile is installed and linked even if these fail.
    if (-not $SkipDependencies) {
        try {
            Write-SetupStep 'Installing configured modules and packages that are missing'
            Install-PSProfileDependency -InstallPath $InstallPath
        }
        catch { Write-Warning "Could not install dependencies: $_" }
    }

    try {
        Write-SetupStep 'Loading the profile once to check it and build its caches'
        if (-not (Invoke-PSProfileSmokeTest -Path $InstallPath)) {
            Write-Warning 'The profile threw an error while loading. Open a new shell to see it, or run Update-Profile -Rollback after an update.'
        }
    }
    catch { Write-Warning "Could not test-load the profile: $_" }

    Write-Host ''
    Write-Host "PSProfile installed at $InstallPath" -ForegroundColor Green
    if (-not $SkipProfileLink) {
        Write-Host 'Restart your shell (or run ". $PROFILE") to load it.' -ForegroundColor Green
    }
    Write-Host "Edit $configPath to customize modules, packages, theme, and aliases." -ForegroundColor Green
}
catch {
    Write-Error "PSProfile setup failed: $_"
    throw
}
