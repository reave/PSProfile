#- Set default settings for advanced cmdlets
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Completion
using namespace System.Management.Automation.Host
using namespace System.Management.Automation.Runspaces

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

#---------------------------------------------------------------
# Functions
#---------------------------------------------------------------
# Exposed so functions dot-sourced from assets\public\* (whose own $PSScriptRoot
# points at their own file, not this one) can still find the install root - e.g.
# Update-Profile's git pull.
Set-Variable -Name PSProfileRoot -Value $PSScriptRoot -Scope Global

$OSFolder = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' }

#- Dot Source Public Functions (assets\public\<windows|macos|linux>\*.ps1)
$functions = Get-ChildItem -Path "$PSScriptRoot\assets\public\$OSFolder\*.ps1" -ErrorAction SilentlyContinue
Foreach ($function in $functions) {
    try { . $function.FullName }
    Catch { Write-Error -Message "Failed to import $($function.Name)" }
}

#- Dot Source Private Functions (assets\private\<windows|macos|linux>\*.ps1)
$functions = Get-ChildItem -Path "$PSScriptRoot\assets\private\$OSFolder\*.ps1" -ErrorAction SilentlyContinue
Foreach ($function in $functions) {
    try { . $function.FullName }
    Catch { Write-Error -Message "Failed to import $($function.Name)" }
}

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

#---------------------------------------------------------------
# Modules
#---------------------------------------------------------------
# Terminal-Icons re-exports its theme cache on every import with a non-atomic Export-Clixml,
# so two shells starting at once can read a half-written file ("Root element is missing").
# A named mutex makes concurrent profile loads take turns importing.
$moduleImportMutex = [System.Threading.Mutex]::new($false, 'PSProfile-ModuleImport')
$PSProfileMissingModules = [System.Collections.Generic.List[string]]::new()
foreach ($module in $PSProfileConfig.Modules) {
    if (-not (Test-PSProfileOSMatch -OSField $module.OS)) { continue }
    if ($module.PSVersionMajor -and $PSVersionTable.PSVersion.Major -lt [int]$module.PSVersionMajor) { continue }
    if ($module.PSVersionMajorMax -and $PSVersionTable.PSVersion.Major -gt [int]$module.PSVersionMajorMax) { continue }

    if (Get-Module -Name $module.Name -ListAvailable -ErrorAction SilentlyContinue) {
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

#---------------------------------------------------------------
# PSReadLine
#---------------------------------------------------------------
$readlineConfig = $PSProfileSettings.PSReadLine
if ($IsInteractiveShell -and $readlineConfig -and (Get-Module -Name PSReadLine -ListAvailable -ErrorAction SilentlyContinue)) {
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

#---------------------------------------------------------------
# Windows Section
#---------------------------------------------------------------
if ($IsWindows -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Windows
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction SilentlyContinue)) {
            Invoke-Expression $splashCommand
        }
    }

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

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction SilentlyContinue)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
}
#---------------------------------------------------------------
# macOS Section
#---------------------------------------------------------------
ElseIf ($IsMacOS -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.MacOS
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction SilentlyContinue)) {
            Invoke-Expression $splashCommand
        }
    }

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

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction SilentlyContinue)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
}
#---------------------------------------------------------------
# Linux Section
#---------------------------------------------------------------
ElseIf ($IsLinux -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Linux
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction SilentlyContinue)) {
            Invoke-Expression $splashCommand
        }
    }

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

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction SilentlyContinue)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
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
