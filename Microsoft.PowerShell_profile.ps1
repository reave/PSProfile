#- Set default settings for advanced cmdlets
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Completion
using namespace System.Management.Automation.Host
using namespace System.Management.Automation.Runspaces

#- Set constants
$MaximumHistoryCount = 8192
$PSDefaultParameterValues['Export-Csv:NoTypeInformation'] = $true
$PSDefaultParameterValues['ConvertTo-Csv:NoTypeInformation'] = $true
$PSDefaultParameterValues['*-PSDrive:PSProvider'] = 'FileSystem'
$PSDefaultParameterValues['Get-Help:Detailed'] = $true

#- Set Filters
filter FileSizeBelow($size) { if ($_.length -le $size) { $_ } }
filter FileSizeAbove($size) { if ($_.Length -ge $size) { $_ } }
filter FileSizeBetween($min, $max) { if ($_.Length -ge $min -and $_.Length -le $max) { $_ } }
filter __oh-my-posh_escapeStringWithSpecialChars {
    $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}

#---------------------------------------------------------------
# Windows Section
#---------------------------------------------------------------
if ($IsWindows) {
    #- Dot Source Public Functions
    #- Check if $PSAssetPath environment variable exists and if not  set it
    if (-not (Test-Path -Path Env:PSAssetPath)) {
        # Creates/updates a user-scoped environment variable
        [System.Environment]::SetEnvironmentVariable(
            "PSAssetPath", "$PSScriptRoot\assets", "User"
        )

        # Broadcasts WM_SETTINGCHANGE to update environment in Explorer
        $signature = @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, int Msg, IntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
"@

        Add-Type -MemberDefinition $signature -Name "Win32SendMessageTimeout" -Namespace Win32Functions

        [Win32Functions.Win32SendMessageTimeout]::SendMessageTimeout(
            [IntPtr]0xffff, 0x1A, [IntPtr]0, "Environment",
            0x2, 5000, [ref]([IntPtr]::Zero)
        ) | Out-Null

    }

    #- Dot Source Private Functions
    if ($env:PSAssetPath) {
        $publicFunctionPath = "$env:PSAssetPath\public\windows\*.ps1"
    } else {
        $publicFunctionPath = "$PSScriptRoot\assets\public\windows\*.ps1"
    }
    $functions = Get-ChildItem -Path $publicFunctionPath -ErrorAction SilentlyContinue
    Foreach ($function in $functions) {
        try { . $function.FullName }
        Catch { Write-Error -Message "Failed to import $($function.Name)" }
    }

    #- Dot Source Private Functions
    if ($env:PSAssetPath) {
        $privateFunctionPath = "$env:PSAssetPath\private\windows\*.ps1"
    } else {
        $privateFunctionPath = "$PSScriptRoot\assets\private\windows\*.ps1"
    }

    $functions = Get-ChildItem -Path $privateFunctionPath -ErrorAction SilentlyContinue
    Foreach ($function in $functions) {
        try { . $function.FullName }
        Catch { Write-Error -Message "Failed to import $($function.Name)" }
    }

    #- Set Document Roots as Variables
    Set-Variable -Name MyDocs -Value ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) -Scope Global
    if (Test-Path -Path $env:USERPROFILE\OneDrive -ErrorAction SilentlyContinue) {
        [string]$OneDriveRoot = "$env:USERPROFILE\OneDrive"
    } Else {
        [string]$OneDriveRoot = "OneDrive is not configured"
    }

    # Module Import
    # install ookla speedtest cli
    $command = Get-Command speedtest -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        # speedtest cli is not installed
        Try {
            Install-WinGetPackage -Id ookla.speedtest.cli -Mode Silent -ErrorAction Stop
        } Catch { Write-Error "Unable to install ookla.speedtest.cli" }
    }
	
	# install Terminal-Icons
	if (Get-Module -Name Terminal-Icons -ListAvailable -ErrorAction SilentlyContinue) {
		Try { Import-Module -Name Terminal-Icons -ErrorAction Stop }
		Catch { Write-Error "Unable to import Terminal-Icons module" }
	} Else {
		# install terminal-icons module
		Try {
			Install-Module -Name Terminal-Icons -Force -ErrorAction Stop
			Import-Module -Name Terminal-Icons -ErrorAction Stop
		} Catch { Write-Error "Unable to install Terminal-Icons module" }
	}


    # Module Import
    if ($PSVersionTable.PSVersion.Major -le 5) {
        if (Get-Module -Name TabExpansionPlusPlus -ListAvailable -ErrorAction SilentlyContinue) {
            Import-Module -Name TabExpansionPlusPlus -ErrorAction Stop
        } Else {
            # install TabExpansionPlusPlus module
            Try {
                Install-Module -Name TabExpansionPlusPlus -Force -ErrorAction Stop
                Import-Module -Name TabExpansionPlusPlus -ErrorAction Stop
            } Catch { Write-Error "Unable to install TabExpansionPlusPlus module" }
        }
    }

    # Module Import
    # install winget module
    if (Get-Module -Name Microsoft.WinGet.Client -ListAvailable -ErrorAction SilentlyContinue) {
        Try {            
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
        } Catch { Write-Error "Unable to load Microsoft.WinGet.Client module" }
    } Else {
        # install winget module
        Try {
            Install-Module -Name Microsoft.WinGet.Client -Force -ErrorAction Stop
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
        } Catch { Write-Error "Unable to install Terminal-Icons module" }
    }

    #f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
    if (Get-Module -Name Microsoft.WinGet.CommandNotFound -ListAvailable -ErrorAction SilentlyContinue) {
        Try { Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction Stop }
        Catch { Write-Error "Unable to import Microsoft.WinGet.CommandNotFound" }
    } Else {
        # install CommandNotFound module
        Try {

            Install-Module -Name Microsoft.WinGet.CommandNotFound -Force -ErrorAction Stop
            Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction Stop

        } Catch { Write-Error "Unable to install Microsoft.WinGet.CommandNotFound module" }
    }
    #f45873b3-b655-43a6-b217-97c00aa0db58

    #- Setup the Console
    Set-Console -WindowTitle

    fastfetch

    If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS CONSOLE IS AN ELEVATED CONSOLE.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red

        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null

    }

    # Show PS Version
    Write-Host "PowerShell Version: $($psversiontable.psversion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor yellow

    #- Oh-My-Posh
    #oh-my-posh --init --shell pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/sonicboom_light.omp.json | Invoke-Expression
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\M365Princess.omp.json" | Invoke-Expression

    #- Set Aliases that are needed
    New-Alias -Name edit -Value Edit-File -Description "Edit a file"
}
#---------------------------------------------------------------
# macOS Section
#---------------------------------------------------------------
ElseIf ($IsMacOS) {
    #- Set Document Roots as Variables
    Set-Variable -Name MyDocs -Value ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) -Scope Global
    if (Test-Path -Path "$env:HOME/OneDrive" -ErrorAction SilentlyContinue) {
        [string]$OneDriveRoot = "$env:HOME/OneDrive"
    } Else {
        [string]$OneDriveRoot = "OneDrive is not configured"
    }

    # Module Import
    if (Get-Module -Name Terminal-Icons -ListAvailable) {
        Import-Module -Name Terminal-Icons
    } Else {
        # install terminal-icons module
        Try {
            Install-Module -Name Terminal-Icons -Force
            Import-Module -Name Terminal-Icons
        } Catch { Write-Host "Unable to install Terminal-Icons module" }
    }

    #- Setup the Console
    screenfetch -E

    Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null

    # Show PS Version and date/time
    Write-Host "PowerShell Version: $($psversiontable.psversion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor yellow
}
#---------------------------------------------------------------
# Linux Section
#---------------------------------------------------------------
ElseIf ($IsLinux) {
    # Module Import
    if (Get-Module -Name Terminal-Icons -ListAvailable) {
        Import-Module -Name Terminal-Icons
    } Else {
        # install terminal-icons module
        Try {
            Install-Module -Name Terminal-Icons -Force
            Import-Module -Name Terminal-Icons
        } Catch { Write-Host "Unable to install Terminal-Icons module" }
    }
}

#---------------------------------------------------------------
# All OS Section
#---------------------------------------------------------------
