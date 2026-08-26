<#
.SYNOPSIS
    Installs or updates this PowerShell profile on the current machine.
.DESCRIPTION
    Downloads the reave/PSProfile repository (via `git clone`/`git pull` when
    git is available, falling back to a zip download otherwise) into a local
    install directory, creates a personal assets\config\config.json from
    sample-config.json if one doesn't already exist, and points
    $PROFILE.CurrentUserAllHosts at the installed profile2.0.ps1.

    Safe to re-run: updates the install in place without touching an existing
    config.json, and backs up any pre-existing $PROFILE content (preserving
    it, appended below the new stub) instead of discarding it.

    Everything else - oh-my-posh, Terminal-Icons, winget/brew/apt/yum/pacman
    packages - installs itself from config.json the first time the profile
    loads (see profile2.0.ps1's Modules/Packages sections); this script only
    needs to get the repo and the profile link in place.
.PARAMETER InstallPath
    Where to install the profile repo. Default: a "PSProfile" folder under
    ~/.config/powershell (created if missing).
.PARAMETER Branch
    Git branch / archive ref to install. Default: main.
.PARAMETER SkipProfileLink
    Download/update the repo but don't touch $PROFILE. Useful if you'd rather
    dot-source profile2.0.ps1 yourself from an existing profile.
.EXAMPLE
    irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex
.EXAMPLE
    &([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -InstallPath 'C:\PSProfile' -Branch 'develop'
#>
[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $HOME '.config/powershell/PSProfile'),
    [string]$Branch = 'main',
    [switch]$SkipProfileLink
)

$ErrorActionPreference = 'Stop'
# git writes routine progress info to stderr; PS7.3+'s native-command error
# preference would otherwise turn that into a terminating error under Stop.
$PSNativeCommandUseErrorActionPreference = $false

$RepoUrl = 'https://github.com/reave/PSProfile'

function Write-SetupStep {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Install-ViaZip {
    param(
        [Parameter(Mandatory)][string]$InstallPath,
        [Parameter(Mandatory)][string]$Branch
    )

    Write-SetupStep "Downloading $Branch as a zip archive"
    $zipUrl = "$RepoUrl/archive/refs/heads/$Branch.zip"
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "psprofile-$([guid]::NewGuid()).zip"
    $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) "psprofile-$([guid]::NewGuid())"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $extractedRoot = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        if (-not $extractedRoot) {
            throw "Downloaded archive didn't contain the expected folder."
        }

        if (-not (Test-Path -Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        }

        Write-SetupStep "Installing to $InstallPath"
        Copy-Item -Path (Join-Path $extractedRoot.FullName '*') -Destination $InstallPath -Recurse -Force
    }
    finally {
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    $InstallPath = [System.IO.Path]::GetFullPath($InstallPath)
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
        # No git, or the install directory already has non-git content in it
        # (e.g. a prior zip-based install) - overlay is always safe to re-run.
        Install-ViaZip -InstallPath $InstallPath -Branch $Branch
    }

    $profileScript = Join-Path $InstallPath 'profile2.0.ps1'
    if (-not (Test-Path -Path $profileScript -PathType Leaf)) {
        throw "profile2.0.ps1 not found at $profileScript after install - something went wrong."
    }

    $configDir = Join-Path $InstallPath 'assets/config'
    $configPath = Join-Path $configDir 'config.json'
    $samplePath = Join-Path $configDir 'sample-config.json'
    if (-not (Test-Path -Path $configPath) -and (Test-Path -Path $samplePath)) {
        Write-SetupStep "Creating personal config at $configPath from sample-config.json"
        Copy-Item -Path $samplePath -Destination $configPath
    }

    if (-not $SkipProfileLink) {
        $profileTarget = $PROFILE.CurrentUserAllHosts
        $marker = '# Managed by PSProfile'

        $profileDir = Split-Path -Path $profileTarget -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        $existingContent = if (Test-Path -Path $profileTarget) { Get-Content -Path $profileTarget -Raw } else { $null }

        if ($existingContent -and $existingContent.Contains($marker)) {
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
$marker (https://github.com/reave/PSProfile) - edit assets/config/config.json in
# the install directory for personal customization instead of editing this file.
. "$profileScript"
"@ | Set-Content -Path $profileTarget

            if ($existingContent) {
                Add-Content -Path $profileTarget -Value "`n# --- Original profile content (preserved below) ---`n$existingContent"
            }
        }
    }

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
