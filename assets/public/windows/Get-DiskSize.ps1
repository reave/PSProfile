function Get-DiskSize {
    <#
    .SYNOPSIS
    Returns disk size, free space, free space %, media type (translated) and device ID / drive letter.

    .DESCRIPTION
    Queries logical disks and attempts to map to physical disk media where possible.
    Outputs objects with properties: Device, SizeBytes, SizeGB, FreeBytes, FreeGB, FreePercent, MediaType.

    .EXAMPLE
    Get-DiskSize | Format-Table -AutoSize
    #>
    [CmdletBinding()]
    param()

    # Helper: translate Win32_LogicalDisk DriveType code
    function Convert-DriveType {
        param([int]$Type)
        switch ($Type) {
            0 { 'Unknown' }
            1 { 'No Root Directory' }
            2 { 'Removable' }
            3 { 'Local Disk' }
            4 { 'Network' }
            5 { 'CD-ROM' }
            6 { 'RAM Disk' }
            default { 'Other' }
        }
    }

    try {
        $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
        Where-Object { $null -ne $_.Size }  # only drives that report size
    }
    catch {
        Write-Error "Failed to enumerate logical disks: $_"
        return
    }

    foreach ($ld in $logicalDisks) {
        $sizeBytes = [int64]$ld.Size
        $freeBytes = if ($ld.FreeSpace) { [int64]$ld.FreeSpace } else { 0 }
        $freePercent = if ($sizeBytes -gt 0) { [math]::Round(($freeBytes / $sizeBytes) * 100, 2) } else { 0 }

        # Try to find an associated physical disk and use its MediaType if available
        $mediaName = $null
        try {
            $partition = Get-CimAssociatedInstance -InputObject $ld -Association Win32_LogicalDiskToPartition -ErrorAction SilentlyContinue |
            Select-Object -First 1
            if ($partition) {
                $diskDrive = Get-CimAssociatedInstance -InputObject $partition -Association Win32_DiskDriveToDiskPartition -ErrorAction SilentlyContinue |
                Select-Object -First 1
                if ($diskDrive -and $diskDrive.MediaType) {
                    $mediaName = $diskDrive.MediaType
                }
                elseif ($diskDrive -and $diskDrive.InterfaceType) {
                    # Fallback: use interface type (e.g., IDE, SCSI, USB) with a hint
                    $mediaName = "$($diskDrive.InterfaceType) (physical)"
                }
            }
        }
        catch {
            # ignore association errors and fall back to DriveType
        }

        if (-not $mediaName) {
            $mediaName = Convert-DriveType -Type ([int]$ld.DriveType)
        }

        [PSCustomObject]@{
            Device      = $ld.DeviceID
            Size        = (& {
                    param($b)
                    if (-not $b -or $b -le 0) { '0 B'; return }
                    $units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'
                    $val = [double]$b
                    $i = 0
                    while ($val -ge 1024 -and $i -lt $units.Count - 1) {
                        $val /= 1024
                        $i++
                    }
                    '{0:N2} {1}' -f $val, $units[$i]
                } $sizeBytes)
            RawSize     = $sizeBytes
            Free        = (& {
                    param($b)
                    if (-not $b -or $b -le 0) { '0 B'; return }
                    $units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'
                    $val = [double]$b
                    $i = 0
                    while ($val -ge 1024 -and $i -lt $units.Count - 1) {
                        $val /= 1024
                        $i++
                    }
                    '{0:N2} {1}' -f $val, $units[$i]
                } $freeBytes)
            RawFree     = $freeBytes
            FreePercent = "$freePercent %"
            MediaType   = $mediaName
        }
    }
}

# Export function for dot-sourcing or module use
Set-Item -Path Function:\Get-DiskSize -Value (Get-Command Get-DiskSize).ScriptBlock -Force