function Get-ADComputersNoDesc {
    <#
    .SYNOPSIS
        Return all computer objects from Active Directory missing a description
    .DESCRIPTION
        Return all computer objects from Active Directory that do not have a description.
        This will filter out servers, and non-Windows devices.
    .PARAMETER SearchBase
        To search entire directory pass SearchBase parameter with an empty value
    .EXAMPLE
        Get-ADComputersNoDesc -SearchBase ''
        Searches the entire directory for computers with no description
    .EXAMPLE
        Get-ADComputersNoDesc
        Searches the entire directory for devices without a description
    .EXAMPLE
        Get-ADComputersNoDesc -SearchBase 'OU=TechLab,DC=contoso,DC=com'
        Searches the OU TechLab and all sub-OUs for devices with no description
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SearchBase
    )
    begin { }
    process {
        if ($SearchBase) {
            Get-ADComputer -SearchBase $SearchBase -Filter { OperatingSystem -NotLike "*server*" -and OperatingSystem -Like "*Windows*" -and Description -NotLike "*" } -Properties OperatingSystem, Description
        } else {
            Get-ADComputer -Filter { OperatingSystem -NotLike "*server*" -and OperatingSystem -Like "*Windows*" -and Description -NotLike "*" } -Properties OperatingSystem, Description
        }
    }
    end { }
}
