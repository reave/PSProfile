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
foreach ($module in $PSProfileConfig.Modules) {
    if (-not (Test-PSProfileOSMatch -OSField $module.OS)) { continue }
    if ($module.PSVersionMajor -and $PSVersionTable.PSVersion.Major -lt [int]$module.PSVersionMajor) { continue }
    if ($module.PSVersionMajorMax -and $PSVersionTable.PSVersion.Major -gt [int]$module.PSVersionMajorMax) { continue }

    if (Get-Module -Name $module.Name -ListAvailable -ErrorAction SilentlyContinue) {
        try { Import-Module -Name $module.Name -ErrorAction Stop }
        catch { Write-Error "Unable to import $($module.Name) module" }
    }
    else {
        try {
            Install-Module -Name $module.Name -Force -ErrorAction Stop
            Import-Module -Name $module.Name -ErrorAction Stop
        }
        catch { Write-Error "Unable to install $($module.Name) module" }
    }
}

$IsElevated = if ($IsWindows) {
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
else {
    try { (id -u) -eq '0' } catch { $false }
}

#---------------------------------------------------------------
# Packages
#---------------------------------------------------------------
# Supported Source values: winget (Windows), brew (macOS/Linuxbrew), apt, yum, pacman (Linux).
# Each entry only acts if its package manager's command is actually present, so a config can
# safely list entries for every OS/manager and the ones that don't apply are silently skipped.
# apt/yum/pacman require root and are skipped (with a warning) when not elevated, rather than
# invoking sudo interactively and risking a password prompt hanging profile load.
foreach ($package in $PSProfileConfig.Packages) {
    if (Get-Command -Name $package.Name -ErrorAction SilentlyContinue) { continue }

    switch ($package.Source) {
        'winget' {
            if (-not (Get-Command -Name winget -ErrorAction SilentlyContinue)) { continue }
            try {
                # Imported here rather than eagerly in the Modules loop above: once every
                # configured package is already installed (the common case after first
                # setup), this branch never runs, so the module's import cost is skipped too.
                if (-not (Get-Command -Name Install-WinGetPackage -ErrorAction SilentlyContinue)) {
                    Import-Module -Name Microsoft.WinGet.Client -ErrorAction Stop
                }
                Install-WinGetPackage -Id $package.Id -Mode Silent -ErrorAction Stop
            }
            catch { Write-Error "Unable to install $($package.Id) via winget" }
        }
        'brew' {
            if (-not (Get-Command -Name brew -ErrorAction SilentlyContinue)) { continue }
            try { & brew install $package.Id }
            catch { Write-Error "Unable to install $($package.Id) via brew" }
        }
        'apt' {
            $aptCmd = Get-Command -Name apt-get -ErrorAction SilentlyContinue
            if (-not $aptCmd) { continue }
            if (-not $IsElevated) { Write-Warning "Skipping apt install of $($package.Id): not running as root."; continue }
            try { & apt-get install -y $package.Id }
            catch { Write-Error "Unable to install $($package.Id) via apt" }
        }
        'yum' {
            $yumCmd = Get-Command -Name dnf -ErrorAction SilentlyContinue
            if (-not $yumCmd) { $yumCmd = Get-Command -Name yum -ErrorAction SilentlyContinue }
            if (-not $yumCmd) { continue }
            if (-not $IsElevated) { Write-Warning "Skipping $($yumCmd.Name) install of $($package.Id): not running as root."; continue }
            try { & $yumCmd.Name install -y $package.Id }
            catch { Write-Error "Unable to install $($package.Id) via $($yumCmd.Name)" }
        }
        'pacman' {
            if (-not (Get-Command -Name pacman -ErrorAction SilentlyContinue)) { continue }
            if (-not $IsElevated) { Write-Warning "Skipping pacman install of $($package.Id): not running as root."; continue }
            try { & pacman -S --noconfirm $package.Id }
            catch { Write-Error "Unable to install $($package.Id) via pacman" }
        }
    }
}

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
