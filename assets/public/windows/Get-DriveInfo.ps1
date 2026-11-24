function Get-DriveInfo {
    <#
    .SYNOPSIS
        Returns information about the logical drives on one or more computers.

    .DESCRIPTION
        Opens a CIM session to each computer and returns one object per Win32_LogicalDisk drive, with
        its device ID, description, file system, size and free space in GB (as text with three
        decimal places), compression state, drive type code and volume name. If a computer can't be
        reached, one object is returned for it with ComputerStatus set to "Could Not Connect" and the
        other properties empty.

    .PARAMETER ComputerName
        The computers to query. Accepts pipeline input, by value or by property name. The default is
        the local computer. Hostname, cn and Name are aliases for this parameter.

    .EXAMPLE
        Get-DriveInfo

        Returns the drives on the local computer.

    .EXAMPLE
        Get-DriveInfo -ComputerName 'Server01', 'Server02'

        Returns the drives on two remote computers.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .NOTES
        Name: Get-DriveInfo
        Author: reave (https://github.com/reave)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "The. Computer. Name.")]
        [Alias('Hostname', 'cn', 'Name')]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    process {
        foreach ($computer in $ComputerName) {
            Write-Verbose -Message "Processing $computer"

            try {
                if ($computer -eq $env:COMPUTERNAME) {
                    $Session = New-CimSession -ErrorAction Stop
                } else {
                    $Session = New-CimSession -ComputerName $computer -ErrorAction Stop
                }
                $Drives = Get-CimInstance -CimSession $Session -ClassName Win32_LogicalDisk

                foreach ($drive in $Drives) {
                    $properties = @{
                        ComputerName   = $computer
                        ComputerStatus = 'Connected'
                        DeviceID       = $drive.DeviceID
                        Description    = $drive.Description
                        FileSystem     = $drive.FileSystem
                        Size           = ($drive.Size / 1GB).ToString("f3")
                        FreeSpace      = ($drive.FreeSpace / 1GB).ToString("f3")
                        Compressed     = $drive.Compressed
                        DriveType      = $drive.DriveType
                        VolumeName     = $drive.VolumeName
                    }
                    $obj = New-Object -TypeName psobject -Property $properties
                    Write-Output $obj
                }
            } catch {
                $properties = @{
                    ComputerName   = $computer
                    ComputerStatus = 'Could Not Connect'
                    DeviceID       = $Null
                    Description    = $Null
                    FileSystem     = $Null
                    Size           = $Null
                    FreeSpace      = $Null
                    Compressed     = $Null
                    DriveType      = $Null
                    VolumeName     = $Null
                }
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }
        }
    }
}
