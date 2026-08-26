Function Set-Console {
    <#
    .SYNOPSIS
        Configures the PowerShell Console
    .DESCRIPTION
        Configures the PowerShell Console to my specifications.
    .PARAMETER WindowTitle
        Switch - Determines if we update the title of the window to display User FullName
    .NOTES
        Name: Set-Console
        Author: Joseph Ascaino
        DateCreated: 08/19/2015
        LastModified: 07/15/2016
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$WindowTitle
    )

    Process {
        If ($WindowTitle) {
            If ($PSVersionTable.PSVersion.Major -ge 4) {
                $UserInfo = Get-CimInstance -ClassName Win32_NetworkLoginProfile | Where-Object { $_.Caption -eq $env:USERNAME }
            } Else {
                $UserInfo = Get-WMIObject -Class Win32_NetworkLoginProfile | Where-Object { $_.Caption -eq $env:USERNAME }
            }

            If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                $host.ui.rawui.WindowTitle = "$($host.ui.rawui.WindowTitle) - Welcome $($UserInfo.FullName). Have a great day!"
            } Else {
                $host.ui.rawui.WindowTitle = "$($host.ui.rawui.WindowTitle) - Elevated Console for $($UserInfo.FullName)."
            }

        }
    }
    End { Clear-Host }
}