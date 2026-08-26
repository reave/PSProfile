function Get-DriveSpace {
    <#
    .SYNOPSIS
        Get Drive space
    .DESCRIPTION
        Get Drive space for all available drives
    .PARAMETER Computer
        Devices to get Drive space on
    .NOTES
        Name: Get-DriveSpace
        Author: Joseph Ascanio
    #>
    [cmdletBinding()]
    param(
        [parameter(
            Mandatory = $false,
            ValueFromPipeline = $true
        )]
        [Alias('Name')]
        [string]$Computer = $env:COMPUTERNAME
    )
    Begin { Write-Verbose "Beginning Execution" }
    Process {
        Write-Verbose "Determining Version of PowerShell"
        If ($PSVersionTable.PSVersion.Major -lt 4) {
            Write-Verbose "PowerShell Version is less than 4. Using Get-WMIObject instead of Get-CIMInstance"
            $DriveInfo = Get-WMIObject -Class Win32_LogicalDisk -Filter { DriveType = 3 } -ErrorAction SilentlyContinue
        }
        Else {
            Write-Verbose "PowerShell Version is greater than 4. Using Get-CIMInstance"
            $DriveInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction SilentlyContinue
        }

        $count = ($DriveInfo | Measure-Object).Count
        $i = 1

        if ($count -gt 0) {
            Write-Verbose "Iterating through returned data"
            Foreach ($Drive in $DriveInfo) {
                Write-Verbose "Processing Drive $($i) of $($count)"
                $Properties = @{
                    Drive       = $Drive.DeviceID
                    VolumeName  = $Drive.VolumeName
                    TotalSize   = if ($Drive.Size -gt 0) { [Math]::Round($Drive.Size / 1GB) } else { 0 }
                    FreeSpace   = if ($Drive.FreeSpace -gt 0) { [Math]::Round($Drive.FreeSpace / 1GB) } else { 0 }
                    PercentFree = if ($Drive.Size -gt 0) { [Math]::Round(([double]$Drive.FreeSpace / [double]$Drive.Size) * 100, 2) } else { 0 }
                }

                $OutputObject = New-Object -TypeName psobject -Property $Properties
                Write-Output $OutputObject
            }
        }
        Else {
            Write-Output 'No drives found of type 3.'
        }
    }
    End { }
} #close drivespace