function Get-InactiveADComputers {
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
    param(
        [int]$DaysInactive = 30
    )
    process {
        # LastLogonTimeStamp is a FileTime, so the cutoff has to be one too.
        $cutoff = (Get-Date).AddDays(-$DaysInactive).ToFileTime()
        # Inactive, and either a Windows client or a Mac.
        $filter = "LastLogonTimeStamp -lt $cutoff -and ((OperatingSystem -like '*Windows*' -and OperatingSystem -notlike '*server*') -or OperatingSystem -like '*Mac*')"
        Write-Verbose "AD filter: $filter"
        Get-ADComputer -Filter $filter -Properties LastLogonTimeStamp, DNSHostName, OperatingSystem
    }
}
