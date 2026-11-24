function New-Explorer {
    <#
.SYNOPSIS
    Restart explorer
.DESCRIPTION
    Restart explorer as a different user
.PARAMETER Username
    Name of the user to launch explorer as
.NOTES
    Name: New-Explorer
    Author: Unknown
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Username
    )

    if ($PSCmdlet.ShouldProcess('Explorer.exe', "Close and restart as $UserName")) {
        taskkill /f /IM Explorer.exe
        runas /noprofile /netonly /user:$UserName explorer
    }

}
