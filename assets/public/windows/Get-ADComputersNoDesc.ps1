Function Get-ADComputersNoDesc {
    <#
    .SYNOPSIS
        Return all computer objects from Active Directory missing a description
    .DESCRIPTION
        Return all computer objects from Active Directory that do not have a description.
        This will filter out servers, and non-Windows devices.
    .PARAMETER SearchBase
        Distinguished name of the OU to search, including its sub-OUs.
        Omit it to search the entire directory.
    .EXAMPLE
        Get-ADComputersNoDesc

        Searches the entire directory for computers with no description
    .EXAMPLE
        Get-ADComputersNoDesc -SearchBase 'OU=Workstations,DC=contoso,DC=com'

        Searches the Workstations OU and all sub-OUs for devices with no description
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SearchBase
    )
    Begin { }
    Process {
        If ($SearchBase) {
            Get-ADComputer -SearchBase $SearchBase -Filter { OperatingSystem -NotLike "*server*" -and OperatingSystem -Like "*Windows*" -and Description -NotLike "*" } -Properties OperatingSystem, Description
        }
        Else {
            Get-ADComputer -Filter { OperatingSystem -NotLike "*server*" -and OperatingSystem -Like "*Windows*" -and Description -NotLike "*" } -Properties OperatingSystem, Description
        }
    }
    End { }
}