<#
.SYNOPSIS
    Sets the console window title to the running PowerShell version, flagging elevation.
.DESCRIPTION
    Cross-platform replacement for the window-title portion of Set-Console -WindowTitle
    (which relies on WMI's Win32_NetworkLoginProfile and only runs on Windows). Uses
    $Host.UI.RawUI.WindowTitle directly, which every supported host respects, and reads
    $IsElevated (set earlier by profile2.0.ps1) to append an [ADMIN] or [ROOT] suffix.
.EXAMPLE
    Set-ProfileWindowTitle
.OUTPUTS
    None
#>
function Set-ProfileWindowTitle {
    [CmdletBinding()]
    param()

    try {
        $suffix = if ($IsElevated) { if ($IsWindows -or $null -eq $IsWindows) { ' [ADMIN]' } else { ' [ROOT]' } } else { '' }
        $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$suffix"
    }
    catch {
        Write-Verbose "Unable to set console title: $_"
    }
}
