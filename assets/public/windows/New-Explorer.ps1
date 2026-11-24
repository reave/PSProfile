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
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Username
    )

    taskkill /f /IM Explorer.exe
    runas /noprofile /netonly /user:$UserName explorer

}