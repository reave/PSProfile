<#
    PSProfile install/update lifecycle helpers.

    One OS-agnostic copy, deliberately outside assets/public and assets/private so a normal
    shell start never dot-sources it. Loaded on demand by:
      - setup.ps1 (install, reinstall)
      - Update-Profile (update, -CheckOnly, -Rollback)
      - the background update check started by profile2.0.ps1 (runs in its own runspace)

    Works on Windows PowerShell 5.1 and PowerShell 7+ on Windows/macOS/Linux.

    State lives outside the install directory, so a zip update that swaps the whole install
    directory can't lose it:
      Windows: $env:LOCALAPPDATA\PSProfile\update-state.json
      Unix:    $XDG_CACHE_HOME/PSProfile/update-state.json (or ~/.cache/PSProfile/...)
    The same base directory holds the profile's other caches (see Update-PSProfileCache).
#>

$script:PSProfileDefaultRepository = 'reave/PSProfile'
# Written into zip installs only (a git install already knows its own commit/branch/remote).
$script:PSProfileInstallInfoFile = '.psprofile-install.json'

function Test-PSProfileIsWindows {
    # $IsWindows doesn't exist on Windows PowerShell 5.1, which only runs on Windows.
    return ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop')
}

function Get-PSProfileStateDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param([switch]$Create)

    $base = if (Test-PSProfileIsWindows) { $env:LOCALAPPDATA }
    elseif ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME }
    else { Join-Path $HOME '.cache' }

    $path = Join-Path $base 'PSProfile'
    if ($Create -and -not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Get-PSProfileState {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-PSProfileStateDirectory) 'update-state.json'
    if (Test-Path -Path $path) {
        try { return Get-Content -Path $path -Raw | ConvertFrom-Json }
        catch { Write-Verbose "Ignoring unreadable state file ${path}: $_" }
    }
    return [PSCustomObject]@{}
}

function Set-PSProfileState {
    <#
        Merges $Values into the state file. Written to a temp file and moved into place so a
        shell starting at the same moment never reads a half-written file.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Values)

    $dir = Get-PSProfileStateDirectory -Create
    $path = Join-Path $dir 'update-state.json'

    $state = [ordered]@{}
    $current = Get-PSProfileState
    foreach ($property in $current.PSObject.Properties) { $state[$property.Name] = $property.Value }
    foreach ($key in $Values.Keys) { $state[$key] = $Values[$key] }

    $temp = Join-Path $dir "update-state.$([guid]::NewGuid().ToString('N')).tmp"
    [PSCustomObject]$state | ConvertTo-Json -Depth 5 | Set-Content -Path $temp -Encoding UTF8
    Move-Item -Path $temp -Destination $path -Force

    Update-PSProfileNotice -State ([PSCustomObject]$state)
}

function Update-PSProfileNotice {
    <#
        Writes the line profile2.0.ps1 prints at startup (update-notice.txt), or deletes it when
        there's nothing to say. Precomputed here so shell start reads one line of text instead
        of parsing JSON. Missing modules aren't included: startup already knows those for free
        from its own import loop.
    #>
    param([Parameter(Mandatory)]$State)

    $parts = [System.Collections.Generic.List[string]]::new()
    if ($State.UpdateAvailable -and -not ($State.RemoteCommit -and $State.RemoteCommit -eq $State.SkippedCommit)) {
        $parts.Add($(if ($State.CommitsBehind) { "$($State.CommitsBehind) new commit(s) available" } else { 'an update is available' }))
    }
    $packages = @($State.MissingPackages | Where-Object { $_ })
    if ($packages.Count) { $parts.Add("missing package(s) $($packages -join ', ')") }

    $path = Join-Path (Get-PSProfileStateDirectory -Create) 'update-notice.txt'
    if ($parts.Count) { Set-Content -Path $path -Value ($parts -join '; ') -Encoding UTF8 }
    elseif (Test-Path -Path $path) { Remove-Item -Path $path -Force }
}

function Get-PSProfileConfigFromPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstallPath)

    $configPath = Join-Path $InstallPath 'assets/config/config.json'
    $samplePath = Join-Path $InstallPath 'assets/config/sample-config.json'
    $path = if (Test-Path -Path $configPath) { $configPath } else { $samplePath }
    if (-not (Test-Path -Path $path)) { return $null }
    try { return Get-Content -Path $path -Raw | ConvertFrom-Json }
    catch { Write-Warning "Could not parse ${path}: $_"; return $null }
}

#---------------------------------------------------------------
# Install info / update detection
#---------------------------------------------------------------

function Get-PSProfileInstallInfo {
    <#
        Describes an install: Type (git|zip|unknown), Commit, Branch, Repository.
        Commit is $null for a zip install made before install info was recorded, or when the
        GitHub API couldn't be reached at install time.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstallPath)

    $info = [ordered]@{
        Type       = 'unknown'
        Path       = $InstallPath
        Commit     = $null
        Branch     = 'main'
        Repository = $script:PSProfileDefaultRepository
    }

    if (Test-Path -Path (Join-Path $InstallPath '.git')) {
        $info.Type = 'git'
        if (Get-Command -Name git -ErrorAction SilentlyContinue) {
            $info.Commit = (git -C $InstallPath rev-parse HEAD 2>$null)
            $branch = (git -C $InstallPath rev-parse --abbrev-ref HEAD 2>$null)
            if ($branch -and $branch -ne 'HEAD') { $info.Branch = $branch }
        }
        return [PSCustomObject]$info
    }

    if (Test-Path -Path (Join-Path $InstallPath 'profile2.0.ps1')) { $info.Type = 'zip' }
    $infoFile = Join-Path $InstallPath $script:PSProfileInstallInfoFile
    if (Test-Path -Path $infoFile) {
        try {
            $recorded = Get-Content -Path $infoFile -Raw | ConvertFrom-Json
            if ($recorded.Commit) { $info.Commit = $recorded.Commit }
            if ($recorded.Branch) { $info.Branch = $recorded.Branch }
            if ($recorded.Repository) { $info.Repository = $recorded.Repository }
        }
        catch { Write-Verbose "Ignoring unreadable ${infoFile}: $_" }
    }
    return [PSCustomObject]$info
}

function Get-PSProfileRemoteCommit {
    <# Latest commit SHA of a branch via the GitHub REST API (unauthenticated: 60 requests/hour). #>
    [CmdletBinding()]
    param(
        [string]$Repository = $script:PSProfileDefaultRepository,
        [string]$Branch = 'main'
    )

    $uri = "https://api.github.com/repos/$Repository/commits/$Branch"
    $headers = @{ Accept = 'application/vnd.github.sha'; 'User-Agent' = 'PSProfile' }
    $response = Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    # This media type isn't text/*, so PowerShell 7 hands back the body as bytes.
    $body = if ($response.Content -is [byte[]]) { [System.Text.Encoding]::ASCII.GetString($response.Content) } else { "$($response.Content)" }
    $sha = $body.Trim()
    if ($sha -notmatch '^[0-9a-f]{40}$') { throw "Unexpected response from ${uri}: $sha" }
    return $sha
}

function Invoke-PSProfileGitFetch {
    <#
        `git fetch` with credential prompts disabled and a hard timeout, so the background check
        can never hang or pop a prompt. The variable is set on the child process only: setting
        $env:GIT_TERMINAL_PROMPT here would leak into the user's interactive session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallPath,
        [Parameter(Mandatory)][string]$Branch,
        [int]$TimeoutSeconds = 30
    )

    $git = (Get-Command -Name git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($git)
    $startInfo.Arguments = "-C `"$InstallPath`" fetch --quiet origin $Branch"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $startInfo.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill() } catch { }
        throw "git fetch timed out after $TimeoutSeconds seconds"
    }
    if ($process.ExitCode -ne 0) { throw "git fetch failed ($($process.ExitCode)): $($stderr.Result.Trim())" }
}

function Test-PSProfileUpdate {
    <#
        Checks whether a newer commit exists for the install and records the answer, plus any
        missing configured modules/packages, in the state file. Runs in the background
        runspace started by profile2.0.ps1, and on demand via Update-Profile -CheckOnly.
        Never throws: a failed check (offline, rate limited) is recorded as LastCheckError.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstallPath)

    $result = @{
        LastCheck       = (Get-Date).ToUniversalTime().ToString('o')
        LastCheckError  = $null
        UpdateAvailable = $false
        CommitsBehind   = $null
        LocalCommit     = $null
        RemoteCommit    = $null
    }

    try {
        $info = Get-PSProfileInstallInfo -InstallPath $InstallPath
        $result.InstallType = $info.Type
        $result.LocalCommit = $info.Commit

        if ($info.Type -eq 'git') {
            if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) { throw 'git not found on PATH' }
            Invoke-PSProfileGitFetch -InstallPath $InstallPath -Branch $info.Branch
            $remote = (git -C $InstallPath rev-parse "origin/$($info.Branch)" 2>$null)
            $behind = [int](git -C $InstallPath rev-list --count "HEAD..origin/$($info.Branch)" 2>$null)
            $result.RemoteCommit = $remote
            $result.CommitsBehind = $behind
            $result.UpdateAvailable = $behind -gt 0
        }
        else {
            $remote = Get-PSProfileRemoteCommit -Repository $info.Repository -Branch $info.Branch
            $result.RemoteCommit = $remote
            # An install with no recorded commit can't be compared, so treat it as out of date:
            # Update-Profile will record the commit and the next check becomes exact.
            $result.UpdateAvailable = (-not $info.Commit) -or ($info.Commit -ne $remote)
        }
    }
    catch {
        $result.LastCheckError = "$_"
    }

    try {
        $missing = Get-PSProfileMissingDependency -Config (Get-PSProfileConfigFromPath -InstallPath $InstallPath)
        $result.MissingModules = @($missing.Modules)
        $result.MissingPackages = @($missing.Packages)
    }
    catch { Write-Verbose "Dependency check failed: $_" }

    Set-PSProfileState -Values $result
    return [PSCustomObject]$result
}

#---------------------------------------------------------------
# Dependencies (config.json Modules / Packages)
#---------------------------------------------------------------

function Test-PSProfileModuleApplies {
    param($Module)

    $isWin = Test-PSProfileIsWindows
    $field = "$($Module.OS)"
    $osMatch = if ([string]::IsNullOrWhiteSpace($field) -or $field -eq 'All') { $true }
    else {
        $osList = $field -split '\s*,\s*'
        ($isWin -and $osList -contains 'Windows') -or ($IsMacOS -and $osList -contains 'MacOS') -or ($IsLinux -and $osList -contains 'Linux')
    }
    if (-not $osMatch) { return $false }
    if ($Module.PSVersionMajor -and $PSVersionTable.PSVersion.Major -lt [int]$Module.PSVersionMajor) { return $false }
    if ($Module.PSVersionMajorMax -and $PSVersionTable.PSVersion.Major -gt [int]$Module.PSVersionMajorMax) { return $false }
    return $true
}

function Get-PSProfilePackageManager {
    <# The command that would install $Package on this machine, or $null if its Source doesn't apply here. #>
    param($Package)

    switch ($Package.Source) {
        'winget' { if (Get-Command -Name winget -ErrorAction SilentlyContinue) { return 'winget' } }
        'brew' { if (Get-Command -Name brew -ErrorAction SilentlyContinue) { return 'brew' } }
        'apt' { if (Get-Command -Name apt-get -ErrorAction SilentlyContinue) { return 'apt-get' } }
        'yum' {
            if (Get-Command -Name dnf -ErrorAction SilentlyContinue) { return 'dnf' }
            if (Get-Command -Name yum -ErrorAction SilentlyContinue) { return 'yum' }
        }
        'pacman' { if (Get-Command -Name pacman -ErrorAction SilentlyContinue) { return 'pacman' } }
    }
    return $null
}

function Get-PSProfileMissingDependency {
    <#
        Configured modules and packages that apply to this machine but aren't installed.
        A package only counts as missing if its package manager is present here, matching how
        the config lets one Packages array list an entry per manager.
    #>
    [CmdletBinding()]
    param($Config)

    $modules = [System.Collections.Generic.List[string]]::new()
    $packages = [System.Collections.Generic.List[string]]::new()

    foreach ($module in $Config.Modules) {
        if (-not (Test-PSProfileModuleApplies -Module $module)) { continue }
        if (-not (Get-Module -Name $module.Name -ListAvailable -ErrorAction SilentlyContinue)) { $modules.Add($module.Name) }
    }

    $installedNames = @{}
    foreach ($package in $Config.Packages) {
        if (-not (Get-PSProfilePackageManager -Package $package)) { continue }
        if (-not $installedNames.ContainsKey($package.Name)) {
            $installedNames[$package.Name] = [bool](Get-Command -Name $package.Name -ErrorAction SilentlyContinue)
        }
        if (-not $installedNames[$package.Name] -and -not $packages.Contains($package.Name)) { $packages.Add($package.Name) }
    }

    return [PSCustomObject]@{ Modules = $modules.ToArray(); Packages = $packages.ToArray() }
}

function Install-PSProfileDependency {
    <#
        Installs the configured modules and packages that are missing. Replaces the install
        logic that used to run on every profile load; startup now only warns.
        apt/dnf/yum/pacman go through sudo when not already root (this runs from setup.ps1 or
        Update-Profile, where a password prompt is expected, never at shell start).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$InstallPath)

    $config = Get-PSProfileConfigFromPath -InstallPath $InstallPath
    if (-not $config) { Write-Warning 'No config.json or sample-config.json found - skipping dependencies.'; return }

    $missing = Get-PSProfileMissingDependency -Config $config
    if (-not $missing.Modules.Count -and -not $missing.Packages.Count) {
        Write-Verbose 'All configured modules and packages are installed.'
        Set-PSProfileState -Values @{ MissingModules = @(); MissingPackages = @() }
        return
    }

    $isRoot = if (Test-PSProfileIsWindows) { $true } else { try { (id -u) -eq '0' } catch { $false } }

    foreach ($name in $missing.Modules) {
        if (-not $PSCmdlet.ShouldProcess($name, 'Install-Module -Scope CurrentUser')) { continue }
        try {
            Install-Module -Name $name -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            Write-Host "Installed module $name" -ForegroundColor Green
        }
        catch { Write-Warning "Unable to install module ${name}: $($_.Exception.Message)" }
    }

    foreach ($name in $missing.Packages) {
        # First entry for this command whose package manager exists here wins.
        $package = $config.Packages | Where-Object { $_.Name -eq $name -and (Get-PSProfilePackageManager -Package $_) } | Select-Object -First 1
        $manager = Get-PSProfilePackageManager -Package $package
        if (-not $PSCmdlet.ShouldProcess("$($package.Id) via $manager", 'Install package')) { continue }

        $sudo = if (-not $isRoot -and $manager -in 'apt-get', 'dnf', 'yum', 'pacman') {
            if (Get-Command -Name sudo -ErrorAction SilentlyContinue) { 'sudo' }
            else { Write-Warning "Skipping $($package.Id): $manager needs root and sudo isn't available."; continue }
        }

        try {
            switch ($manager) {
                'winget' { & winget install --id $package.Id --exact --silent --accept-package-agreements --accept-source-agreements }
                'brew' { & brew install $package.Id }
                'apt-get' { if ($sudo) { & sudo apt-get install -y $package.Id } else { & apt-get install -y $package.Id } }
                { $_ -in 'dnf', 'yum' } { if ($sudo) { & sudo $manager install -y $package.Id } else { & $manager install -y $package.Id } }
                'pacman' { if ($sudo) { & sudo pacman -S --noconfirm $package.Id } else { & pacman -S --noconfirm $package.Id } }
            }
            if ($LASTEXITCODE -ne 0) { throw "$manager exited with code $LASTEXITCODE" }
            Write-Host "Installed package $($package.Id) via $manager" -ForegroundColor Green
        }
        catch { Write-Warning "Unable to install $($package.Id) via ${manager}: $_" }
    }

    $after = Get-PSProfileMissingDependency -Config $config
    Set-PSProfileState -Values @{ MissingModules = @($after.Modules); MissingPackages = @($after.Packages) }
}

#---------------------------------------------------------------
# Validation
#---------------------------------------------------------------

function Test-PSProfileTree {
    <#
        Cheap static check of an install tree before it goes live: profile2.0.ps1 exists and
        every .ps1 parses. Returns a list of problems (empty = OK).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $problems = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -Path (Join-Path $Path 'profile2.0.ps1') -PathType Leaf)) {
        $problems.Add('profile2.0.ps1 is missing')
        return $problems.ToArray()
    }

    foreach ($file in Get-ChildItem -Path $Path -Filter '*.ps1' -Recurse -File -ErrorAction SilentlyContinue) {
        if ($file.FullName -match '[\\/]\.git[\\/]') { continue }
        $tokens = $null; $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        foreach ($parseError in $errors) {
            $problems.Add("$($file.FullName):$($parseError.Extent.StartLineNumber): $($parseError.Message)")
        }
    }
    return $problems.ToArray()
}

function Invoke-PSProfileSmokeTest {
    <#
        Loads $Path/profile2.0.ps1 in a separate, profile-less PowerShell process (the same
        executable as this session) and runs post-update maintenance there with the new code:
        Update-PSProfileCache (if the profile defines it) and Update-Completions.
        Returns $true only if the profile loaded without a terminating error.

        A child process is used because dot-sourcing from inside a function can't redefine the
        caller's global functions, so the current session can't reliably host the new code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipMaintenance
    )

    $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $profileScript = (Join-Path $Path 'profile2.0.ps1').Replace("'", "''")
    $maintenance = if ($SkipMaintenance) { '' } else {
        @'
foreach ($cmd in 'Update-PSProfileCache', 'Update-Completions') {
    if (Get-Command -Name $cmd -ErrorAction SilentlyContinue) {
        try { & $cmd } catch { Write-Warning "$cmd failed: $_" }
    }
}
'@
    }
    $command = @"
`$env:PSPROFILE_NO_UPDATE_CHECK = '1'
`$ErrorActionPreference = 'Continue'
try { . '$profileScript' } catch { [Console]::Error.WriteLine("Profile failed to load: `$_"); exit 1 }
$maintenance
exit 0
"@
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    & $exe -NoProfile -NonInteractive -NoLogo -OutputFormat Text -EncodedCommand $encoded | Out-Host
    return ($LASTEXITCODE -eq 0)
}

#---------------------------------------------------------------
# Zip installs (staged swap)
#---------------------------------------------------------------

function Get-PSProfileSidePath {
    <# A sibling of the install dir (same volume, so swaps are renames, never cross-volume copies). #>
    param([Parameter(Mandatory)][string]$InstallPath, [Parameter(Mandatory)][string]$Suffix)
    $parent = Split-Path -Path $InstallPath -Parent
    $leaf = Split-Path -Path $InstallPath -Leaf
    return Join-Path $parent ".$leaf.$Suffix"
}

function Save-PSProfileArchive {
    <#
        Downloads and extracts a commit (or branch, if the commit can't be resolved) of the repo
        into a fresh staging directory next to the install dir, and records the install info
        in it. Returns the staging path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallPath,
        [string]$Repository = $script:PSProfileDefaultRepository,
        [string]$Branch = 'main'
    )

    $commit = $null
    try { $commit = Get-PSProfileRemoteCommit -Repository $Repository -Branch $Branch }
    catch { Write-Warning "Couldn't resolve the latest commit ($_). Downloading the branch tip without recording its commit." }

    $ref = if ($commit) { $commit } else { "refs/heads/$Branch" }
    $zipUrl = "https://github.com/$Repository/archive/$ref.zip"
    $parent = Split-Path -Path $InstallPath -Parent
    if (-not (Test-Path -Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "psprofile-$([guid]::NewGuid().ToString('N')).zip"
    $extract = Get-PSProfileSidePath -InstallPath $InstallPath -Suffix "download-$([guid]::NewGuid().ToString('N'))"
    $staging = Get-PSProfileSidePath -InstallPath $InstallPath -Suffix 'staging'

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $tempZip -DestinationPath $extract -Force
        $root = Get-ChildItem -Path $extract -Directory | Select-Object -First 1
        if (-not $root) { throw "The archive from $zipUrl didn't contain the expected folder." }

        if (Test-Path -Path $staging) { Remove-Item -Path $staging -Recurse -Force }
        Move-Item -Path $root.FullName -Destination $staging

        [PSCustomObject]@{
            Repository  = $Repository
            Branch      = $Branch
            Commit      = $commit
            InstalledAt = (Get-Date).ToUniversalTime().ToString('o')
        } | ConvertTo-Json | Set-Content -Path (Join-Path $staging $script:PSProfileInstallInfoFile) -Encoding UTF8
    }
    finally {
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extract -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $staging
}

function Copy-PSProfileLocalFile {
    <#
        Carries machine-local, gitignored files from the live install into a new tree:
        config.json and any cached native completions.
    #>
    param([Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To)

    if (-not (Test-Path -Path $From)) { return }

    $config = Join-Path $From 'assets/config/config.json'
    if (Test-Path -Path $config) {
        $dest = Join-Path $To 'assets/config'
        if (-not (Test-Path -Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        Copy-Item -Path $config -Destination $dest -Force
    }

    $fromFull = (Resolve-Path -Path $From).Path.TrimEnd('\', '/')
    foreach ($dir in Get-ChildItem -Path (Join-Path $From 'assets') -Directory -Recurse -Filter 'native' -ErrorAction SilentlyContinue) {
        if ((Split-Path -Path $dir.Parent.FullName -Leaf) -ne 'completions') { continue }
        $relative = $dir.FullName.Substring($fromFull.Length).TrimStart('\', '/')
        $dest = Join-Path $To $relative
        if (-not (Test-Path -Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        Copy-Item -Path (Join-Path $dir.FullName '*') -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-PSProfileStaged {
    <#
        Validates a staged tree, carries local files over, then swaps it in:
          install -> .<name>.previous   (kept for Update-Profile -Rollback)
          staging -> install
        If the swap fails part-way (e.g. a shell has its working directory inside the install
        on Windows), the previous tree is put back. Replaces the old overlay copy, which never
        deleted files removed upstream - so a renamed function used to keep loading forever.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StagingPath,
        [Parameter(Mandatory)][string]$InstallPath,
        [switch]$SkipSmokeTest
    )

    Copy-PSProfileLocalFile -From $InstallPath -To $StagingPath

    $problems = Test-PSProfileTree -Path $StagingPath
    if ($problems.Count) {
        Remove-Item -Path $StagingPath -Recurse -Force -ErrorAction SilentlyContinue
        throw "The downloaded profile failed validation, nothing was changed:`n  $($problems -join "`n  ")"
    }

    if (-not $SkipSmokeTest -and -not (Invoke-PSProfileSmokeTest -Path $StagingPath -SkipMaintenance)) {
        Remove-Item -Path $StagingPath -Recurse -Force -ErrorAction SilentlyContinue
        throw 'The downloaded profile threw an error while loading, nothing was changed.'
    }

    $previous = Get-PSProfileSidePath -InstallPath $InstallPath -Suffix 'previous'
    $hadInstall = Test-Path -Path $InstallPath
    if ($hadInstall) {
        if (Test-Path -Path $previous) { Remove-Item -Path $previous -Recurse -Force }
        Move-Item -Path $InstallPath -Destination $previous -ErrorAction Stop
    }
    try {
        Move-Item -Path $StagingPath -Destination $InstallPath -ErrorAction Stop
    }
    catch {
        if ($hadInstall) { Move-Item -Path $previous -Destination $InstallPath -ErrorAction SilentlyContinue }
        throw "Couldn't swap in the new version ($_). The existing install was left in place. If a shell's current directory is inside $InstallPath, cd out of it and retry."
    }

    if ($hadInstall) { Set-PSProfileState -Values @{ PreviousInstallPath = $previous; PreviousCommit = $null } }
}

#---------------------------------------------------------------
# Update / rollback (used by Update-Profile)
#---------------------------------------------------------------

function Invoke-PSProfileUpdate {
    <#
        Updates the install in place, validates it, and rolls back automatically if the new
        version doesn't parse or throws while loading. Returns $true if something changed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$InstallPath,
        [switch]$SkipSmokeTest
    )

    $info = Get-PSProfileInstallInfo -InstallPath $InstallPath

    if ($info.Type -eq 'git') {
        if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) { throw 'git is required to update a git-based install.' }
        $before = $info.Commit
        if (-not $PSCmdlet.ShouldProcess($InstallPath, 'git pull --ff-only')) { return $false }

        git -C $InstallPath pull --ff-only | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "git pull failed with exit code $LASTEXITCODE. Local commits or edits in $InstallPath may be blocking a fast-forward." }
        $after = (git -C $InstallPath rev-parse HEAD)
        if ($after -eq $before) {
            Write-Host 'PSProfile is already up to date.' -ForegroundColor Green
            Set-PSProfileState -Values @{ UpdateAvailable = $false; CommitsBehind = 0; LocalCommit = $after }
            return $false
        }

        $problems = Test-PSProfileTree -Path $InstallPath
        $loaded = if ($problems.Count) { $false } elseif ($SkipSmokeTest) { $true } else { Invoke-PSProfileSmokeTest -Path $InstallPath }
        if (-not $loaded) {
            # --keep (not --hard): refuses rather than discarding any local edits in the install.
            git -C $InstallPath reset --keep $before | Out-Host
            $detail = if ($problems.Count) { "`n  $($problems -join "`n  ")" } else { ' (it threw while loading)' }
            throw "The update to $($after.Substring(0, 7)) failed validation and was rolled back to $($before.Substring(0, 7))$detail"
        }

        Set-PSProfileState -Values @{ PreviousCommit = $before; PreviousInstallPath = $null; UpdateAvailable = $false; CommitsBehind = 0; LocalCommit = $after; SkippedCommit = $null }
        Write-Host "PSProfile updated $($before.Substring(0, 7)) -> $($after.Substring(0, 7))." -ForegroundColor Green
        return $true
    }

    if ($info.Type -eq 'zip') {
        if ($info.Commit) {
            try {
                $remote = Get-PSProfileRemoteCommit -Repository $info.Repository -Branch $info.Branch
                if ($remote -eq $info.Commit) {
                    Write-Host 'PSProfile is already up to date.' -ForegroundColor Green
                    Set-PSProfileState -Values @{ UpdateAvailable = $false; LocalCommit = $remote; RemoteCommit = $remote }
                    return $false
                }
            }
            catch { Write-Verbose "Couldn't compare commits ($_); downloading anyway." }
        }
        if (-not $PSCmdlet.ShouldProcess($InstallPath, "Download $($info.Repository)@$($info.Branch) and swap it in")) { return $false }

        $staging = Save-PSProfileArchive -InstallPath $InstallPath -Repository $info.Repository -Branch $info.Branch
        Install-PSProfileStaged -StagingPath $staging -InstallPath $InstallPath -SkipSmokeTest:$SkipSmokeTest
        $new = Get-PSProfileInstallInfo -InstallPath $InstallPath
        Set-PSProfileState -Values @{ UpdateAvailable = $false; LocalCommit = $new.Commit; SkippedCommit = $null }
        if (-not $SkipSmokeTest) { $null = Invoke-PSProfileSmokeTest -Path $InstallPath }
        Write-Host 'PSProfile updated.' -ForegroundColor Green
        return $true
    }

    throw "$InstallPath doesn't look like a PSProfile install (no .git and no profile2.0.ps1)."
}

function Undo-PSProfileUpdate {
    <#
        Returns the install to the version before the last Update-Profile, and remembers the
        version rolled away from so the "update available" notice stays quiet until a newer
        commit than that one lands.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$InstallPath)

    $state = Get-PSProfileState
    $info = Get-PSProfileInstallInfo -InstallPath $InstallPath

    if ($info.Type -eq 'git') {
        if (-not $state.PreviousCommit) { throw 'No previous version recorded. Rollback is only available after an Update-Profile.' }
        if (-not $PSCmdlet.ShouldProcess($InstallPath, "git reset --keep $($state.PreviousCommit.Substring(0, 7))")) { return }
        git -C $InstallPath reset --keep $state.PreviousCommit | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "git reset failed with exit code $LASTEXITCODE." }
        Set-PSProfileState -Values @{ PreviousCommit = $null; SkippedCommit = $info.Commit; LocalCommit = $state.PreviousCommit }
    }
    else {
        $previous = Get-PSProfileSidePath -InstallPath $InstallPath -Suffix 'previous'
        if (-not (Test-Path -Path $previous)) { throw 'No previous version found. Rollback is only available after an Update-Profile.' }
        if (-not $PSCmdlet.ShouldProcess($InstallPath, "Restore $previous")) { return }
        # Keep any config edits made since the update.
        Copy-PSProfileLocalFile -From $InstallPath -To $previous
        $failed = Get-PSProfileSidePath -InstallPath $InstallPath -Suffix 'rolledback'
        if (Test-Path -Path $failed) { Remove-Item -Path $failed -Recurse -Force }
        Move-Item -Path $InstallPath -Destination $failed -ErrorAction Stop
        try { Move-Item -Path $previous -Destination $InstallPath -ErrorAction Stop }
        catch {
            Move-Item -Path $failed -Destination $InstallPath -ErrorAction SilentlyContinue
            throw "Couldn't restore the previous version ($_). If a shell's current directory is inside $InstallPath, cd out of it and retry."
        }
        Remove-Item -Path $failed -Recurse -Force -ErrorAction SilentlyContinue
        $restored = Get-PSProfileInstallInfo -InstallPath $InstallPath
        Set-PSProfileState -Values @{ PreviousInstallPath = $null; SkippedCommit = $info.Commit; LocalCommit = $restored.Commit }
    }

    Write-Host 'Rolled back to the previous PSProfile version. Open a new shell to load it.' -ForegroundColor Green
}
