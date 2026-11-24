function Start-PSElevated {
    <#
    .SYNOPSIS
        Execute a command or start an elevated PS Prompt
    .DESCRIPTION
        Executes a provided scriptblock or opens an elevated powershell prompt
    .EXAMPLE
        PS C:\> Start-PSElevated -ScriptBlock 'Get-Service'

        Runs the scriptblock 'get-service' in an elevated context
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ScriptBlock,
        [Parameter(Mandatory = $false)]
        [switch]$NoExit
    )

    $sh = New-Object -com 'Shell.Application'

    if ($ScriptBlock -eq '') {
        $sh.ShellExecute('powershell', '-NoLogo', '', 'runas')
    } else {
        if ($NoExit) {
            $sh.ShellExecute('powershell', "-NoExit -Command $scriptblock", '', 'runas')
        } else {
            $sh.ShellExecute('powershell', "-Command $scriptblock", '', 'runas')
        }
    }
}
