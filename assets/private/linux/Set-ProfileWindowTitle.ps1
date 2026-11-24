<#
.SYNOPSIS
    Sets the console window title to the running PowerShell version, flagging elevation.
.DESCRIPTION
    Cross-platform replacement for the window-title portion of Set-Console -WindowTitle
    (which relies on WMI's Win32_NetworkLoginProfile and only runs on Windows). Uses
    $Host.UI.RawUI.WindowTitle directly, which every supported host respects, and reads
    $IsElevated (set earlier by profile.ps1) to append an [ADMIN] or [ROOT] suffix.
.EXAMPLE
    Set-ProfileWindowTitle
.OUTPUTS
    None
#>
function Set-ProfileWindowTitle {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Only sets the title of the current console window.')]
    param()

    try {
        # $IsWindows doesn't exist in Windows PowerShell 5.1; check the edition first.
        $onWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows
        $suffix = if ($IsElevated) { if ($onWindows) { ' [ADMIN]' } else { ' [ROOT]' } } else { '' }
        $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$suffix"
    } catch {
        Write-Verbose "Unable to set console title: $_"
    }
}
