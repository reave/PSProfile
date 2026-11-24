function Get-DriveSpace {
    <#
    .SYNOPSIS
        Get Drive space
    .DESCRIPTION
        Get Drive space for all available drives
    .PARAMETER Computer
        The computer to get drive space on. Accepts pipeline input. The default is the local
        computer. A remote computer is reached over WSMan, or DCOM if WinRM isn't available.
    .EXAMPLE
        Get-DriveSpace

        Gets the space on the local computer's fixed drives.
    .EXAMPLE
        'Server01', 'Server02' | Get-DriveSpace

        Gets the space on the fixed drives of two remote computers.
    .NOTES
        Name: Get-DriveSpace
        Author: reave (https://github.com/reave)
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
    begin { Write-Verbose "Beginning Execution" }
    process {
        $cimParams = @{ ClassName = 'Win32_LogicalDisk'; Filter = 'DriveType = 3'; ErrorAction = 'SilentlyContinue' }
        $session = $null
        if ($Computer -notin $env:COMPUTERNAME, 'localhost', '.') {
            # WSMan first, then DCOM for computers without WinRM.
            try { $session = New-CimSession -ComputerName $Computer -ErrorAction Stop }
            catch {
                $dcomSessionParams = @{
                    ComputerName = $Computer
                    SessionOption = (New-CimSessionOption -Protocol Dcom)
                    ErrorAction = 'SilentlyContinue'
                }
                $session = New-CimSession @dcomSessionParams
            }
            if (-not $session) {
                Write-Error -Message "Can't connect to $Computer."
                return
            }
            $cimParams.CimSession = $session
        }
        $DriveInfo = Get-CimInstance @cimParams
        if ($session) { Remove-CimSession -CimSession $session }

        $count = ($DriveInfo | Measure-Object).Count
        $i = 1

        if ($count -gt 0) {
            Write-Verbose "Iterating through returned data"
            foreach ($Drive in $DriveInfo) {
                Write-Verbose "Processing Drive $($i) of $($count)"
                $Properties = @{
                    Computer    = $Computer
                    Drive       = $Drive.DeviceID
                    VolumeName  = $Drive.VolumeName
                    TotalSize   = if ($Drive.Size -gt 0) { [Math]::Round($Drive.Size / 1GB) } else { 0 }
                    FreeSpace   = if ($Drive.FreeSpace -gt 0) { [Math]::Round($Drive.FreeSpace / 1GB) } else { 0 }
                    PercentFree = if ($Drive.Size -gt 0) {
                        [Math]::Round(([double]$Drive.FreeSpace / [double]$Drive.Size) * 100, 2)
                    } else { 0 }
                }

                $OutputObject = New-Object -TypeName psobject -Property $Properties
                Write-Output $OutputObject
            }
        } else {
            Write-Output 'No drives found of type 3.'
        }
    }
    end { }
} #close drivespace
