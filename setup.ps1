<#
.SYNOPSIS
    Installs or updates this PowerShell profile on the current machine.
.DESCRIPTION
    Downloads the reave/PSProfile repository (via `git clone`/`git pull` when
    git is available, falling back to a zip download otherwise) into a local
    install directory, creates a personal assets\config\config.json from
    sample-config.json if one doesn't already exist, and points
    $PROFILE.CurrentUserAllHosts at the installed profile.ps1.

    Safe to re-run: updates the install in place without touching an existing
    config.json, and backs up any pre-existing $PROFILE content (preserving
    it, appended below the new stub) instead of discarding it.

    Everything else - oh-my-posh, Terminal-Icons, winget/brew/apt/yum/pacman
    packages - installs itself from config.json the first time the profile
    loads (see profile.ps1's Modules/Packages sections); this script only
    needs to get the repo and the profile link in place.
.PARAMETER InstallPath
    Where to install the profile repo. Default: a "PSProfile" folder under
    ~/.config/powershell (created if missing).
.PARAMETER Branch
    Git branch / archive ref to install. Default: main.
.PARAMETER SkipProfileLink
    Download/update the repo but don't touch $PROFILE. Useful if you'd rather
    dot-source profile.ps1 yourself from an existing profile.
.EXAMPLE
    irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex
.EXAMPLE
    &([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -InstallPath 'C:\PSProfile' -Branch 'develop'
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The installer reports its steps and next steps on the console, which is its interface.')]
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification = 'Sets PSProfileRoot so Update-Completion can find the new install.')]
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
    <#
    .SYNOPSIS
        Writes a setup progress message to the console.

    .PARAMETER Message
        The message to write. It's shown in cyan after ==>.

    .EXAMPLE
        Write-SetupStep -Message 'Cloning the repository'

        Writes "==> Cloning the repository".
    #>
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Install-ViaZip {
    <#
    .SYNOPSIS
        Installs PSProfile from a zip download of the repository.

    .DESCRIPTION
        Downloads a branch of the repository from GitHub as a zip file, extracts it to a temporary
        folder, and copies its contents into InstallPath, creating the folder if needed and
        overwriting existing files. The temporary files are removed afterwards, even if a step fails.

    .PARAMETER InstallPath
        The folder to install into.

    .PARAMETER Branch
        The branch to download, such as main.

    .EXAMPLE
        Install-ViaZip -InstallPath "$HOME\.config\powershell\PSProfile" -Branch 'main'

        Installs the main branch into the default install folder.
    #>
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
    } finally {
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Update-LegacyProfileReference {
    <#
    .SYNOPSIS
        Rewrites dot-source lines that load profile2.0.ps1 so they load profile.ps1.
    .DESCRIPTION
        Only dot-source lines naming profile2.0.ps1 are changed; everything else in the file is
        preserved byte for byte, in its original encoding. The file is backed up first.
    .OUTPUTS
        System.Boolean - $true if the file was migrated, $false if nothing needed changing.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$ProfilePath)

    if (-not (Test-Path -Path $ProfilePath -PathType Leaf)) { return $false }

    # The search and replacement are ASCII, so decode with a byte-transparent encoding (Latin-1)
    # unless the file is UTF-16. Every byte outside the replaced text is written back unchanged,
    # including any BOM.
    $bytes = [System.IO.File]::ReadAllBytes($ProfilePath)
    $preambleLength = 0
    $encoding = [System.Text.Encoding]::GetEncoding(28591)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $encoding = [System.Text.Encoding]::Unicode; $preambleLength = 2 }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $encoding = [System.Text.Encoding]::BigEndianUnicode; $preambleLength = 2 }

    $text = $encoding.GetString($bytes, $preambleLength, $bytes.Length - $preambleLength)
    $pattern = '(?m)^(\s*\.\s+.*?)profile2\.0\.ps1'
    if ($text -notmatch $pattern) { return $false }
    if (-not $PSCmdlet.ShouldProcess($ProfilePath, 'Replace profile2.0.ps1 with profile.ps1')) { return $false }

    $backupPath = "$ProfilePath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-SetupStep "Migrating $ProfilePath from profile2.0.ps1 to profile.ps1 (backup: $backupPath)"
    Copy-Item -Path $ProfilePath -Destination $backupPath -Force

    $body = $encoding.GetBytes([regex]::Replace($text, $pattern, '${1}profile.ps1'))
    $stream = [System.IO.File]::Create($ProfilePath)
    try {
        $stream.Write($bytes, 0, $preambleLength)
        $stream.Write($body, 0, $body.Length)
    } finally { $stream.Dispose() }
    return $true
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
    } elseif ($hasGit -and $installDirIsEmpty) {
        Write-SetupStep "Cloning $RepoUrl to $InstallPath"
        git clone --branch $Branch $RepoUrl $InstallPath
        if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }
    } else {
        # No git, or the install directory already has non-git content in it
        # (e.g. a prior zip-based install) - overlay is always safe to re-run.
        Install-ViaZip -InstallPath $InstallPath -Branch $Branch
    }

    $profileScript = Join-Path $InstallPath 'profile.ps1'
    if (-not (Test-Path -Path $profileScript -PathType Leaf)) {
        throw "profile.ps1 not found at $profileScript after install - something went wrong."
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

        # A rewritten profile already loads PSProfile, so it's never relinked (that would load it twice).
        $migrated = Update-LegacyProfileReference -ProfilePath $profileTarget

        $existingContent = if (Test-Path -Path $profileTarget) { Get-Content -Path $profileTarget -Raw } else { $null }

        # A profile counts as linked if it has the marker, or (manual install) dot-sources this install's
        # profile.ps1 directly, written as a literal path or relative to $HOME / ~.
        $alreadyLoads = $false
        if ($existingContent) {
            foreach ($m in [regex]::Matches($existingContent, '(?m)^\s*\.\s+["'']?([^"''\r\n]+?)["'']?\s*$')) {
                $candidate = $m.Groups[1].Value -replace '^(\$HOME|\$env:USERPROFILE|~)(?=[\\/])', $HOME
                try { if ([System.IO.Path]::GetFullPath($candidate) -eq $profileScript) { $alreadyLoads = $true; break } }
                catch { Write-Verbose "Skipping '$candidate' in the profile: it isn't a valid path." }
            }
        }

        if ($migrated) {
            Write-SetupStep "Profile at $profileTarget now loads profile.ps1"
        } elseif ($existingContent -and ($existingContent.Contains($marker) -or $alreadyLoads)) {
            Write-SetupStep "Profile at $profileTarget already links to PSProfile - leaving it alone"
        } else {
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

    # Populate cached native completions (config.json's NativeCompletions - e.g. docker,
    # kubectl, gh, helm) for whichever of those tools are already installed, so they work
    # from the very first shell restart. Everything else config-driven (Modules, Packages)
    # runs itself the first time profile.ps1 loads; NativeCompletions is deliberately not
    # auto-run on every load (shelling out to each tool - e.g. docker - on every profile load
    # would be slow), so it needs this explicit populate step instead. Non-fatal: setup still
    # succeeds even if this fails, same as everything else below "Cloning/Installing" above.
    try {
        # $IsWindows/$IsMacOS don't exist in Windows PowerShell 5.1; check the edition first.
        $onWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows
        $osFolder = if ($onWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
        $updateCompletionsScript = Join-Path $InstallPath "assets\public\$osFolder\Update-Completion.ps1"
        if (Test-Path -Path $updateCompletionsScript) {
            Write-SetupStep 'Populating native completions for installed tools'
            $Global:PSProfileRoot = $InstallPath
            function Get-PSProfileConfig {
                <#
                .SYNOPSIS
                    Loads the installed profile's configuration.

                .DESCRIPTION
                    A minimal stand-in for the function of the same name in profile.ps1, so Update-Completion
                    can run during setup. Reads assets\config\config.json from the install folder, or
                    sample-config.json when there's no config.json. Returns $null if neither file exists.

                .EXAMPLE
                    Get-PSProfileConfig

                    Returns the configuration that Update-Completion reads.
                #>
                $configPath = Join-Path $InstallPath 'assets\config\config.json'
                $samplePath = Join-Path $InstallPath 'assets\config\sample-config.json'
                $path = if (Test-Path -Path $configPath) { $configPath } else { $samplePath }
                if (-not (Test-Path -Path $path)) { return $null }
                Get-Content -Path $path -Raw | ConvertFrom-Json
            }
            . $updateCompletionsScript
            Update-Completion
        }
    } catch {
        Write-Warning "Could not populate native completions: $_"
    }

    Write-Host ''
    Write-Host "PSProfile installed at $InstallPath" -ForegroundColor Green
    if (-not $SkipProfileLink) {
        Write-Host 'Restart your shell (or run ". $PROFILE") to load it.' -ForegroundColor Green
    }
    Write-Host "Edit $configPath to customize modules, packages, theme, and aliases." -ForegroundColor Green
} catch {
    Write-Error "PSProfile setup failed: $_"
    throw
}
