Function Get-DriveInfo {
    <#
    .SYNOPSIS
        Returns Drive Information
    .DESCRIPTION
        Returns Drive Information for all drives
    .PARAMETER ComputerName
        Aliases: 'Hostname','cn','Name'
        Parameter Values:   Mandatory=$false,
                            ValueFromPipeline=$True,
                            ValueFromPipelineByPropertyName=$True,
                            HelpMessage="The. Computer. Name."
        Parameter Type: Array of Strings
        Define a device or list of devices by Hostname,CN,or Name
        to get drive information for.
    .OUTPUT
        System.Management.Automation
    .NOTES
        Name: Get-DriveInfo
        Author: Joseph Ascanio
    .ALIASES
        df
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
    Process {
        foreach ($computer in $ComputerName) {
            Write-Verbose -Message "Processing $computer"

            Try {
                if ($computer -eq $env:COMPUTERNAME) {
                    $Session = New-CimSession -ErrorAction Stop
                }
                else {
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
            }
            Catch {
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