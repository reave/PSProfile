Function Get-ADComputersNoDesc {
    <#
    .SYNOPSIS
        Return all computer objects from Active Directory missing a description
    .DESCRIPTION
        Return all computer objects from Active Directory that do not have a description.
        This will filter out servers, and non-Windows devices.
    .PARAMETER SearchBase
        Default SearchBase is OU=Facilities,DC=pbso,DC=org

        To search entire directory pass SearchBase parameter with an empty value
    .EXAMPLE
        Get-ADComputersNoDesc -SearchBase ''

        Searches the entire directory for computers with no description
    .EXAMPLE
        Get-ADComputersNoDesc

        Searches OU=Facilities and all sub-OUs for devices without a description
    .EXAMPLE
        Get-ADComputersNoDesc -SearchBase 'OU=zTechLab,DC=pbso,DC=org'

        Searches the OU zTechlab and all sub-OUs for devices with no description
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SearchBase = "OU=Facilities,DC=pbso,DC=org"
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