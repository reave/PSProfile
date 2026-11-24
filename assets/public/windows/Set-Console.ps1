function Set-Console {
    <#
    .SYNOPSIS
        Configures the PowerShell Console
    .DESCRIPTION
        Configures the PowerShell Console to my specifications.
    .PARAMETER WindowTitle
        Switch - Determines if we update the title of the window to display User FullName
    .NOTES
        Name: Set-Console
        Author: reave (https://github.com/reave)
        DateCreated: 08/19/2015
        LastModified: 07/15/2016
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$WindowTitle
    )

    process {
        if ($WindowTitle) {
            if ($PSVersionTable.PSVersion.Major -ge 4) {
                $UserInfo = Get-CimInstance -ClassName Win32_NetworkLoginProfile | Where-Object { $_.Caption -eq $env:USERNAME }
            } else {
                $UserInfo = Get-WmiObject -Class Win32_NetworkLoginProfile | Where-Object { $_.Caption -eq $env:USERNAME }
            }

            if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                $host.ui.rawui.WindowTitle = "$($host.ui.rawui.WindowTitle) - Welcome $($UserInfo.FullName). Have a great day!"
            } else {
                $host.ui.rawui.WindowTitle = "$($host.ui.rawui.WindowTitle) - Elevated Console for $($UserInfo.FullName)."
            }

        }
    }
    end { Clear-Host }
}
