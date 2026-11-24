Function Get-DiskInfo {
    <#
    .SYNOPSIS
    Get Disk Information

    .DESCRIPTION
    Get Disk Information and space utilization

    .PARAMETER ComputerName
    The ComputerName to retrieve data from

    Default: $env:ComputerName
    .EXAMPLE
    Get-DiskInfo -ComputerName $Name
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "The. Computer. Name."
        )
        ]
        [Alias('Hostname', 'cn', 'Name')]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    Process {
        foreach ($computer in $ComputerName) {
            Write-Verbose "Verify WSMan Connection to $computer"
            If (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
                Write-Verbose "WSMan is available"
                try {
                    Write-Verbose "Creating New CimSession to $computer"
                    $session = New-CimSession -ComputerName $computer -ErrorAction Stop

                    Write-Verbose "Retrieving disk information for $computer"
                    $Drives = Get-CimInstance -CimSession $Session -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop

                    foreach ($drive in $Drives) {
                        $properties = @{
                            ComputerName   = $computer
                            ComputerStatus = 'Connected'
                            DeviceID       = $drive.DeviceID
                            Description    = $drive.Description
                            FileSystem     = $drive.FileSystem
                            Size           = "$(($drive.Size / 1GB).ToString("f3")) GB"
                            FreeSpace      = "$(($drive.FreeSpace / 1GB).ToString("f3")) GB"
                            Compressed     = $drive.Compressed
                            DriveType      = $drive.DriveType
                            VolumeName     = $drive.VolumeName
                        }
                        $obj = New-Object -TypeName psobject -Property $properties
                        Write-Output $obj
                    }
                }
                catch {
                    Write-Error "An error occured"
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
            Else {
                Write-Verbose "WSMan is not available"
                try {
                    Write-Verbose "Retrieving disk information for $computer"
                    $Drives = Get-WMIObject -ClassName Win32_LogicalDisk -ComputerName $computer -ErrorAction Stop -Filter 'DriveType=3'

                    foreach ($drive in $Drives) {
                        $properties = @{
                            ComputerName   = $computer
                            ComputerStatus = 'Connected'
                            DeviceID       = $drive.DeviceID
                            Description    = $drive.Description
                            FileSystem     = $drive.FileSystem
                            Size           = "$(($drive.Size / 1GB).ToString("f3")) GB"
                            FreeSpace      = "$(($drive.FreeSpace / 1GB).ToString("f3")) GB"
                            Compressed     = $drive.Compressed
                            DriveType      = $drive.DriveType
                            VolumeName     = $drive.VolumeName
                        }
                        $obj = New-Object -TypeName psobject -Property $properties
                        Write-Output $obj
                    }
                }
                catch {
                    Write-Error "An error occured"
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
}