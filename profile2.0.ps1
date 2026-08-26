#- Set default settings for advanced cmdlets
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Completion
using namespace System.Management.Automation.Host
using namespace System.Management.Automation.Runspaces

#- Set Filters
filter FileSizeBelow($size) { if ($_.length -le $size) { $_ } }
filter FileSizeAbove($size) { if ($_.Length -ge $size) { $_ } }
filter FileSizeBetween($min, $max) { if ($_.Length -ge $min -and $_.Length -le $max) { $_ } }
filter __oh-my-posh_escapeStringWithSpecialChars {
    $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}

#---------------------------------------------------------------
# Configuration
#---------------------------------------------------------------
function Get-PSProfileConfig {
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

function Test-PSProfileOSMatch {
    param([string]$OSField)
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
#- Dot Source Functions
$functions = Get-ChildItem -Path $PSScriptRoot\assets\public\*.ps1 -ErrorAction SilentlyContinue
Foreach ($function in $functions) {
    try { . $function.FullName }
    Catch { Write-Error -Message "Failed to import $($function.Name)" }
}

if ($IsWindows) {
    #- Dot Source Private Functions
    $functions = Get-ChildItem -Path $PSScriptRoot\assets\private\windows\*.ps1 -ErrorAction SilentlyContinue
    Foreach ($function in $functions) {
        try { . $function.FullName }
        Catch { Write-Error -Message "Failed to import $($function.Name)" }
    }
}

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

#---------------------------------------------------------------
# Packages
#---------------------------------------------------------------
if ($IsWindows) {
    foreach ($package in $PSProfileConfig.Packages) {
        if ($package.Source -ne 'winget') { continue }
        if (Get-Command -Name $package.Name -ErrorAction SilentlyContinue) { continue }
        try { Install-WinGetPackage -Id $package.Id -Mode Silent -ErrorAction Stop }
        catch { Write-Error "Unable to install $($package.Id)" }
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
if ($readlineConfig -and (Get-Module -Name PSReadLine -ListAvailable -ErrorAction SilentlyContinue)) {
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
    }
    catch { Write-Verbose "Skipping PSReadLine configuration: $_" }
}

#---------------------------------------------------------------
# Windows Section
#---------------------------------------------------------------
if ($IsWindows) {
    if ($PSProfileSettings.EnableChocolateyIntegration) {
        # Import the Chocolatey Profile that contains the necessary code to enable
        # tab-completions to function for `choco`. See https://ch0.co/tab-completion
        $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        if (Test-Path($ChocolateyProfile)) {
            Import-Module "$ChocolateyProfile"
        }
    }

    if ($PSProfileSettings.ShowWindowTitle -and (Get-Command -Name Set-Console -ErrorAction SilentlyContinue)) {
        Set-Console -WindowTitle
    }

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Windows
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction SilentlyContinue)) {
            Invoke-Expression $splashCommand
        }
    }

    if ($PSProfileSettings.ShowElevatedWarning -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS CONSOLE IS AN ELEVATED CONSOLE.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red

        if ($PSProfileSettings.RunUpdateHelpOnElevated) {
            Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
        }
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction SilentlyContinue)) {
        oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\$($PSProfileSettings.PoshTheme).omp.json" | Invoke-Expression
    }
}
#---------------------------------------------------------------
# macOS Section
#---------------------------------------------------------------
ElseIf ($IsMacOS) {
    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.MacOS
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction SilentlyContinue)) {
            Invoke-Expression $splashCommand
        }
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
}
#---------------------------------------------------------------
# Linux Section
#---------------------------------------------------------------
ElseIf ($IsLinux) {
    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Linux
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction SilentlyContinue)) {
            Invoke-Expression $splashCommand
        }
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
}
