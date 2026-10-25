#- Set default settings for advanced cmdlets
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Completion
using namespace System.Management.Automation.Host
using namespace System.Management.Automation.Runspaces

#- Windows PowerShell 5.1 predates $IsWindows/$IsMacOS/$IsLinux, so every OS check below
#- would read $null and no functions would load. 5.1 only runs on Windows; define them there.
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $IsWindows = $true
    $IsMacOS = $false
    $IsLinux = $false
}

#---------------------------------------------------------------
# Load timing (opt-in)
#---------------------------------------------------------------
# Set $env:PSPROFILE_TRACE = 1 before starting a shell to print how long each section of this
# profile took. Rows stay in $Global:PSProfileTrace afterward, including work deferred until the
# first idle prompt (Phase 'Deferred'), which lands there a moment after the prompt appears.
$Global:PSProfileTrace = $null
if ($env:PSPROFILE_TRACE) {
    $Global:PSProfileTrace = [System.Collections.Generic.List[PSCustomObject]]::new()
    $Global:PSProfileTraceClock = [System.Diagnostics.Stopwatch]::StartNew()
    $Global:PSProfileTraceLastMark = 0
}

<#
.SYNOPSIS
    Records a timing row for a profile section when PSPROFILE_TRACE is set.
.DESCRIPTION
    Without -Milliseconds, the row's time is everything since the previous mark, so calling
    this at the end of each section times that section. Pass -Milliseconds to record a
    duration measured separately (e.g. deferred work). A no-op when tracing is off.
.PARAMETER Section
    Name of the section being recorded.
.PARAMETER Phase
    'Load' for work done before the prompt appears, 'Deferred' for work done after.
.PARAMETER Milliseconds
    An explicit duration to record instead of the time since the previous mark.
.EXAMPLE
    Add-PSProfileTrace -Section 'Modules'
.OUTPUTS
    None
#>
function Add-PSProfileTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Section,
        [string]$Phase = 'Load',
        [double]$Milliseconds = -1
    )

    if ($null -eq $Global:PSProfileTrace) { return }
    $now = $Global:PSProfileTraceClock.Elapsed.TotalMilliseconds
    if ($Milliseconds -lt 0) {
        $Milliseconds = $now - $Global:PSProfileTraceLastMark
        $Global:PSProfileTraceLastMark = $now
    }
    $Global:PSProfileTrace.Add([PSCustomObject]@{ Phase = $Phase; Section = $Section; Ms = [math]::Round($Milliseconds, 1) })
}

#- Set Filters

<#
.SYNOPSIS
    Filters pipeline input to items with a Length at or below a given size.
.DESCRIPTION
    Intended for use after Get-ChildItem to filter files by size.
.PARAMETER size
    The maximum size, in bytes, an item's Length may be to pass the filter.
.EXAMPLE
    Get-ChildItem | FileSizeBelow 1MB
.OUTPUTS
    System.IO.FileSystemInfo
#>
filter FileSizeBelow($size) { if ($_.length -le $size) { $_ } }

<#
.SYNOPSIS
    Filters pipeline input to items with a Length at or above a given size.
.DESCRIPTION
    Intended for use after Get-ChildItem to filter files by size.
.PARAMETER size
    The minimum size, in bytes, an item's Length must be to pass the filter.
.EXAMPLE
    Get-ChildItem | FileSizeAbove 1MB
.OUTPUTS
    System.IO.FileSystemInfo
#>
filter FileSizeAbove($size) { if ($_.Length -ge $size) { $_ } }

<#
.SYNOPSIS
    Filters pipeline input to items with a Length within a given range.
.DESCRIPTION
    Intended for use after Get-ChildItem to filter files by size.
.PARAMETER min
    The minimum size, in bytes, an item's Length must be to pass the filter.
.PARAMETER max
    The maximum size, in bytes, an item's Length may be to pass the filter.
.EXAMPLE
    Get-ChildItem | FileSizeBetween 1MB 10MB
.OUTPUTS
    System.IO.FileSystemInfo
#>
filter FileSizeBetween($min, $max) { if ($_.Length -ge $min -and $_.Length -le $max) { $_ } }

<#
.SYNOPSIS
    Escapes PowerShell special characters in a string.
.DESCRIPTION
    Backtick-escapes whitespace and characters PowerShell treats specially
    (#, @, $, ;, comma, quotes, braces, parens, backtick, pipe, angle brackets, &)
    so a value can be safely embedded in a command line, e.g. an oh-my-posh segment
    value passed through Invoke-Expression.
.EXAMPLE
    "some value" | __oh-my-posh_escapeStringWithSpecialChars
.OUTPUTS
    System.String
#>
filter __oh-my-posh_escapeStringWithSpecialChars {
    $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}

#---------------------------------------------------------------
# Configuration
#---------------------------------------------------------------

<#
.SYNOPSIS
    Loads the PSProfile JSON configuration.
.DESCRIPTION
    Looks for a personal config at assets\config\config.json, relative to this
    profile script's directory. If it isn't present, falls back to the checked-in
    assets\config\sample-config.json template and emits a warning. Returns $null
    if neither file exists or the JSON fails to parse, so callers should treat
    every setting as optional and supply a default.
.EXAMPLE
    $config = Get-PSProfileConfig
    $config.settings.MaximumHistoryCount
.OUTPUTS
    System.Management.Automation.PSCustomObject, or $null if no config could be loaded.
.NOTES
    Copy sample-config.json to config.json and edit it to customize this profile.
    config.json is gitignored so personal paths never get committed.
#>
function Get-PSProfileConfig {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $configPath = Join-Path $PSScriptRoot 'assets\config\config.json'
    $samplePath = Join-Path $PSScriptRoot 'assets\config\sample-config.json'

    $path = if (Test-Path -Path $configPath) { $configPath } else { $samplePath }
    if ($path -eq $samplePath -and (Test-Path -Path $samplePath)) {
        Write-Warning "assets\config\config.json not found - falling back to sample-config.json. Copy sample-config.json to config.json and adjust it for your machine."
    }

    if (-not (Test-Path -Path $path)) {
        Write-Warning "No profile config found at $path - continuing with built-in defaults."
        return $null
    }

    try {
        return Get-Content -Path $path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to load profile config from $path`: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Tests whether the current OS matches a config entry's OS field.
.DESCRIPTION
    Compares the running platform ($IsWindows/$IsMacOS/$IsLinux) against a
    comma-separated list of OS names from profile config, e.g. "Windows,MacOS".
    A blank value or the literal "All" matches every OS.
.PARAMETER OSField
    The OS field from a config entry (e.g. a Modules[] item), such as "Windows",
    "MacOS,Linux", or "All".
.EXAMPLE
    Test-PSProfileOSMatch -OSField 'Windows,MacOS'
.OUTPUTS
    System.Boolean
#>
function Test-PSProfileOSMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$OSField
    )

    if ([string]::IsNullOrWhiteSpace($OSField) -or $OSField -eq 'All') { return $true }
    $osList = $OSField -split '\s*,\s*'
    if ($IsWindows -and $osList -contains 'Windows') { return $true }
    if ($IsMacOS -and $osList -contains 'MacOS') { return $true }
    if ($IsLinux -and $osList -contains 'Linux') { return $true }
    return $false
}

$PSProfileConfig = Get-PSProfileConfig
$PSProfileSettings = $PSProfileConfig.settings

#- Set constants
$MaximumHistoryCount = if ($PSProfileSettings.MaximumHistoryCount) { $PSProfileSettings.MaximumHistoryCount } else { 8192 }

if ($PSProfileSettings.DefaultParameterValues) {
    foreach ($property in $PSProfileSettings.DefaultParameterValues.PSObject.Properties) {
        $PSDefaultParameterValues[$property.Name] = $property.Value
    }
}
Add-PSProfileTrace -Section 'Config'

#---------------------------------------------------------------
# Functions
#---------------------------------------------------------------
# Exposed so functions dot-sourced from assets\public\* (whose own $PSScriptRoot
# points at their own file, not this one) can still find the install root - e.g.
# Update-Profile's git pull.
Set-Variable -Name PSProfileRoot -Value $PSScriptRoot -Scope Global

$OSFolder = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' }

#- Dot Source Public Functions (assets\public\shared\*.ps1, then assets\public\<windows|macos|linux>\*.ps1)
#- The OS folder loads second so an OS-specific file wins over a shared one of the same name.
$functions = @(
    Get-ChildItem -Path "$PSScriptRoot\assets\public\shared\*.ps1" -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$PSScriptRoot\assets\public\$OSFolder\*.ps1" -ErrorAction SilentlyContinue
)
Foreach ($function in $functions) {
    try { . $function.FullName }
    Catch { Write-Error -Message "Failed to import $($function.Name)" }
}
Add-PSProfileTrace -Section 'Public functions'

#- Dot Source Private Functions (assets\private\<windows|macos|linux>\*.ps1)
# history.ps1 is PSReadLine key-handler setup, not functions - it's loaded in the PSReadLine
# section below, only for interactive shells.
$functions = Get-ChildItem -Path "$PSScriptRoot\assets\private\$OSFolder\*.ps1" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'history.ps1' }
Foreach ($function in $functions) {
    try { . $function.FullName }
    Catch { Write-Error -Message "Failed to import $($function.Name)" }
}
Add-PSProfileTrace -Section 'Private functions'

Enable-Tls12
Initialize-HomebrewPath
$IsInteractiveShell = Test-InteractiveShell

#---------------------------------------------------------------
# Document Roots
#---------------------------------------------------------------
Set-Variable -Name MyDocs -Value ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) -Scope Global

$configuredOneDrivePath = $PSProfileSettings.OneDrivePath
if ($configuredOneDrivePath -and (Test-Path -Path $configuredOneDrivePath -ErrorAction SilentlyContinue)) {
    [string]$OneDriveRoot = $configuredOneDrivePath
}
elseif ($IsWindows -and (Test-Path -Path $env:USERPROFILE\OneDrive -ErrorAction SilentlyContinue)) {
    [string]$OneDriveRoot = "$env:USERPROFILE\OneDrive"
}
elseif (-not $IsWindows -and (Test-Path -Path "$env:HOME/OneDrive" -ErrorAction SilentlyContinue)) {
    [string]$OneDriveRoot = "$env:HOME/OneDrive"
}
else {
    [string]$OneDriveRoot = "OneDrive is not configured"
}
Add-PSProfileTrace -Section 'Environment and document roots'

#---------------------------------------------------------------
# Modules
#---------------------------------------------------------------
<#
.SYNOPSIS
    Tests whether a module is installed, without a full Get-Module -ListAvailable scan.
.DESCRIPTION
    Get-Module -ListAvailable reads the manifest of every module on $env:PSModulePath
    (15-30 ms per call here). A module that's imported, or has a folder of its name directly
    under a PSModulePath entry (how Install-Module lays modules out), is found with a few
    directory checks; only a miss falls back to the full scan, which also catches unusual
    layouts and folder-name case differences on case-sensitive filesystems.
.PARAMETER Name
    Module name.
.EXAMPLE
    Test-PSProfileModuleAvailable -Name Terminal-Icons
.OUTPUTS
    System.Boolean
#>
function Test-PSProfileModuleAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (Get-Module -Name $Name) { return $true }
    foreach ($modulePath in $env:PSModulePath -split [System.IO.Path]::PathSeparator) {
        if ($modulePath -and [System.IO.Directory]::Exists([System.IO.Path]::Combine($modulePath, $Name))) { return $true }
    }
    return [bool](Get-Module -Name $Name -ListAvailable -ErrorAction Ignore)
}

# Terminal-Icons re-exports its theme cache on every import with a non-atomic Export-Clixml,
# so two shells starting at once can read a half-written file ("Root element is missing").
# A named mutex makes concurrent profile loads take turns importing.
$moduleImportMutex = [System.Threading.Mutex]::new($false, 'PSProfile-ModuleImport')
$PSProfileMissingModules = [System.Collections.Generic.List[string]]::new()
foreach ($module in $PSProfileConfig.Modules) {
    if (-not (Test-PSProfileOSMatch -OSField $module.OS)) { continue }
    if ($module.PSVersionMajor -and $PSVersionTable.PSVersion.Major -lt [int]$module.PSVersionMajor) { continue }
    if ($module.PSVersionMajorMax -and $PSVersionTable.PSVersion.Major -gt [int]$module.PSVersionMajorMax) { continue }

    if (Test-PSProfileModuleAvailable -Name $module.Name) {
        $hasImportMutex = $false
        try {
            # A shell that died mid-import abandons the mutex; ownership still passes to us.
            try { $hasImportMutex = $moduleImportMutex.WaitOne(10000) }
            catch [System.Threading.AbandonedMutexException] { $hasImportMutex = $true }
            try { Import-Module -Name $module.Name -ErrorAction Stop }
            catch {
                if ($module.Name -ne 'Terminal-Icons') { throw }
                # A shell closed mid-write still leaves a truncated theme file, and the module stops
                # before rewriting it, so every later load fails too. Drop unreadable files and retry
                # once; the module regenerates its built-in themes on import.
                $themeCacheBase = if ($IsLinux -or $IsMacOS) {
                    if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { [IO.Path]::Combine($HOME, '.local', 'share') }
                }
                else { $env:APPDATA }
                $themeCachePath = [IO.Path]::Combine($themeCacheBase, 'powershell', 'Community', 'Terminal-Icons')
                foreach ($themeFile in Get-ChildItem -Path $themeCachePath -Filter '*.xml' -ErrorAction SilentlyContinue) {
                    try { $null = Import-Clixml -Path $themeFile.FullName -ErrorAction Stop }
                    catch { Remove-Item -LiteralPath $themeFile.FullName -Force }
                }
                Import-Module -Name $module.Name -ErrorAction Stop
            }
        }
        catch { Write-Error "Unable to import $($module.Name) module: $($_.Exception.Message)" }
        finally { if ($hasImportMutex) { $moduleImportMutex.ReleaseMutex() } }
    }
    else {
        # Installing is setup.ps1's / Update-Profile's job; startup only reports it (see the
        # update notice at the end of this file).
        $PSProfileMissingModules.Add($module.Name)
    }
}
$moduleImportMutex.Dispose()
Add-PSProfileTrace -Section 'Modules'

$IsElevated = if ($IsWindows) {
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
else {
    try { (id -u) -eq '0' } catch { $false }
}

#---------------------------------------------------------------
# Packages
#---------------------------------------------------------------
# config.json Packages are installed by setup.ps1 and Update-Profile, never at startup: probing
# each one with Get-Command on every load cost time, and package managers can prompt or hang.
# The background update check below detects missing packages instead.

#---------------------------------------------------------------
# Aliases
#---------------------------------------------------------------
foreach ($alias in $PSProfileConfig.Aliases) {
    New-Alias -Name $alias.Name -Value $alias.Value -Description $alias.Description -Force
}
Add-PSProfileTrace -Section 'Elevation check, packages and aliases'

#---------------------------------------------------------------
# PSReadLine
#---------------------------------------------------------------
$hasPSReadLine = $IsInteractiveShell -and (Test-PSProfileModuleAvailable -Name PSReadLine)

# Key handlers. Loaded only here, not with the other private files: every Set-PSReadLine* call
# in it imports PSReadLine (~150 ms), which scripts, CI runners and editor hosts that dot-source
# this profile never use. Loaded before the config-driven options below so config.json wins.
if ($hasPSReadLine) {
    try { . "$PSScriptRoot\assets\private\$OSFolder\history.ps1" }
    catch { Write-Error -Message "Failed to import history.ps1: $_" }
}

$readlineConfig = $PSProfileSettings.PSReadLine
if ($hasPSReadLine -and $readlineConfig) {
    # Wrapped in try/catch: PredictionSource/PredictionViewStyle throw when the host
    # doesn't support virtual terminal processing (redirected output, some remote/CI shells).
    try {
        if ($readlineConfig.PredictionSource) { Set-PSReadLineOption -PredictionSource $readlineConfig.PredictionSource -ErrorAction Stop }
        if ($readlineConfig.PredictionViewStyle) { Set-PSReadLineOption -PredictionViewStyle $readlineConfig.PredictionViewStyle -ErrorAction Stop }
        if ($readlineConfig.EditMode) { Set-PSReadLineOption -EditMode $readlineConfig.EditMode -ErrorAction Stop }
        if ($readlineConfig.HistorySearchArrowKeys) {
            Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction Stop
            Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction Stop
        }
        if ($readlineConfig.FilterSecretsFromHistory) {
            # Keeps lines that look like they contain a secret out of PSReadLine's
            # plaintext on-disk history file. Doesn't stop the command from running.
            Set-PSReadLineOption -AddToHistoryHandler {
                param([string]$line)
                $line -notmatch '(?i)(password|secret|token|apikey|connectionstring)'
            } -ErrorAction Stop
        }
        if ($readlineConfig.Colors) {
            $colorTable = @{}
            foreach ($colorProperty in $readlineConfig.Colors.PSObject.Properties) { $colorTable[$colorProperty.Name] = $colorProperty.Value }
            Set-PSReadLineOption -Colors $colorTable -ErrorAction Stop
        }
    }
    catch { Write-Verbose "Skipping PSReadLine configuration: $_" }
}
Add-PSProfileTrace -Section 'PSReadLine'

#---------------------------------------------------------------
# Windows Section
#---------------------------------------------------------------
if ($IsWindows -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }
    Add-PSProfileTrace -Section 'Window title'

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Windows
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction Ignore)) {
            Invoke-Expression $splashCommand
        }
    }
    Add-PSProfileTrace -Section 'Splash screen'

    if ($PSProfileSettings.ShowElevatedWarning -and $IsElevated) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS CONSOLE IS AN ELEVATED CONSOLE.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated -and $IsElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
    Add-PSProfileTrace -Section 'Banners'

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
    Add-PSProfileTrace -Section 'oh-my-posh'
}
#---------------------------------------------------------------
# macOS Section
#---------------------------------------------------------------
ElseIf ($IsMacOS -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }
    Add-PSProfileTrace -Section 'Window title'

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.MacOS
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction Ignore)) {
            Invoke-Expression $splashCommand
        }
    }
    Add-PSProfileTrace -Section 'Splash screen'

    if ($PSProfileSettings.ShowElevatedWarning -and $IsElevated) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS SHELL IS RUNNING AS ROOT.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated -and $IsElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
    Add-PSProfileTrace -Section 'Banners'

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
    Add-PSProfileTrace -Section 'oh-my-posh'
}
#---------------------------------------------------------------
# Linux Section
#---------------------------------------------------------------
ElseIf ($IsLinux -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }
    Add-PSProfileTrace -Section 'Window title'

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Linux
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction Ignore)) {
            Invoke-Expression $splashCommand
        }
    }
    Add-PSProfileTrace -Section 'Splash screen'

    if ($PSProfileSettings.ShowElevatedWarning -and $IsElevated) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS SHELL IS RUNNING AS ROOT.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated -and $IsElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
    Add-PSProfileTrace -Section 'Banners'

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
    Add-PSProfileTrace -Section 'oh-my-posh'
}

if ($Global:PSProfileTrace) {
    Add-PSProfileTrace -Section 'Total (load)' -Milliseconds $Global:PSProfileTraceClock.Elapsed.TotalMilliseconds
    $Global:PSProfileTrace | Format-Table -AutoSize | Out-Host
}

#---------------------------------------------------------------
# Update notice and background update check
#---------------------------------------------------------------
# Prints one line if the last background check found a newer version or missing dependencies.
# If that check is older than UpdateCheckIntervalHours (default 24, 0 turns it off), a new one
# starts in a background runspace: it never blocks the prompt, and its result shows on the next
# shell start. The check writes its verdict as a ready-to-print line (update-notice.txt), so this
# block parses nothing; the check itself lives in assets/lib/PSProfile.Lifecycle.ps1 and is only
# loaded inside that runspace. State lives outside the install dir, next to the other caches.
$updateCheckHours = if ($null -ne $PSProfileSettings.UpdateCheckIntervalHours) { [double]$PSProfileSettings.UpdateCheckIntervalHours } else { 24 }
if ($IsInteractiveShell -and -not $env:PSPROFILE_NO_UPDATE_CHECK) {
    # PSEdition Desktop = Windows PowerShell 5.1, which has no $IsWindows.
    $stateBase = if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { $env:LOCALAPPDATA } elseif ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
    $stateDir = [System.IO.Path]::Combine($stateBase, 'PSProfile')

    $updateNotices = [System.Collections.Generic.List[string]]::new()
    $noticePath = [System.IO.Path]::Combine($stateDir, 'update-notice.txt')
    if ($updateCheckHours -gt 0 -and [System.IO.File]::Exists($noticePath)) {
        $updateNotices.Add([System.IO.File]::ReadAllText($noticePath).Trim())
    }
    if ($PSProfileMissingModules.Count) { $updateNotices.Add("missing module(s) $($PSProfileMissingModules -join ', ')") }
    if ($updateNotices.Count) { Write-Host "PSProfile: $($updateNotices -join '; '). Run Update-Profile." -ForegroundColor Yellow }

    # A missing file reports 1601-01-01, so the first shell after install runs a check.
    $lastUpdateCheck = [System.IO.File]::GetLastWriteTimeUtc([System.IO.Path]::Combine($stateDir, 'update-state.json'))
    if ($updateCheckHours -gt 0 -and ([datetime]::UtcNow - $lastUpdateCheck).TotalHours -ge $updateCheckHours) {
        $updateCheck = [powershell]::Create()
        [void]$updateCheck.AddScript({
                param($Lifecycle, $InstallPath)
                . $Lifecycle
                $null = Test-PSProfileUpdate -InstallPath $InstallPath
            }).AddArgument([System.IO.Path]::Combine($PSScriptRoot, 'assets', 'lib', 'PSProfile.Lifecycle.ps1')).AddArgument($PSScriptRoot)
        $null = $updateCheck.BeginInvoke()
    }
}
