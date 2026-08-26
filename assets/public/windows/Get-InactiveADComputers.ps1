Function Get-InactiveADComputers {
    <#
    .SYNOPSIS
    Retrieve all Inactive AD Computers

    .DESCRIPTION
    Get all computers that have not updated their lastlogontimestamp in X days.

    .PARAMETER DaysInactive
    Number of days to consider a device inactive

    Default: 30 days
    .EXAMPLE
    Get-InactiveComputers -DaysInactive 90

    .EXAMPLE
    Get-InactiveComputers
    #>
    [CmdletBinding()]
    Param(
        [int]$DaysInactive = 30
    )
    Process {
        Get-ADComputer -Filter { LastLogonTimeStamp -lt $DaysInactive -and OperatingSystem -NotLike "*server*" -and OperatingSystem -Like "*Windows*" -or OperatingSystem -Like "*Mac*" } -Properties LastLogonTimeStamp, DNSHostName, OperatingSystem
    }
}