Function Start-Elevated {
    <#
.SYNOPSIS
    Start a process as admin
.DESCRIPTION
    Start a process as an elevated user
.PARAMETER FilePath
    Path of the application or file to open as elevated
.PARAMETER ArgumentList
    Arguments to pass to the elevated procss
.NOTES
    Name: Start-Elevated
    Author: Unknown
#>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)] [String]$FilePath,
        [parameter(Mandatory = $false, ValueFromRemainingArguments = $true, Position = 1)] [String[]]$ArgumentList
    )
    Process {
        Start-Process -Verb RunAs @PSBoundParameters
    }
}