function Get-LastBootTime {
    <#
    .SYNOPSIS
        Returns when a computer last booted.
    .DESCRIPTION
        On Windows, reads Win32_OperatingSystem over CIM, locally or for remote
        computers. On Linux, reads the btime line from /proc/stat. On macOS,
        reads sysctl kern.boottime. Remote computers are only supported on
        Windows; on macOS and Linux use Invoke-Command over SSH instead.
    .PARAMETER ComputerName
        One or more computers. Defaults to the local computer. Accepts pipeline input.
    .EXAMPLE
        Get-LastBootTime
    .EXAMPLE
        'srv01', 'srv02' | Get-LastBootTime
    .OUTPUTS
        PSCustomObject with ComputerName and LastBootUpTime. LastBootUpTime is
        "Error" when a remote computer can't be reached.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string[]]$ComputerName = [Environment]::MachineName
    )
    process {
        foreach ($computer in $ComputerName) {
            Write-Verbose "Getting last boot time for $computer"
            $isLocal = $computer -in @([Environment]::MachineName, 'localhost', '.', '127.0.0.1')

            if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
                $cim = @{ ClassName = 'Win32_OperatingSystem'; ErrorAction = 'Stop' }
                if (-not $isLocal) { $cim.ComputerName = $computer }
                try {
                    Get-CimInstance @cim | Select-Object @{ Name = 'ComputerName'; Expression = { $_.CSName } }, LastBootUpTime
                }
                catch {
                    if ($isLocal) {
                        Write-Error $_.Exception.Message
                    }
                    else {
                        [PSCustomObject]@{ ComputerName = $computer; LastBootUpTime = 'Error' }
                    }
                }
                continue
            }

            if (-not $isLocal) {
                Write-Error "Remote computers are only supported on Windows. Try: Invoke-Command -HostName $computer { Get-LastBootTime }"
                continue
            }

            $boot = $null
            if ($IsLinux) {
                $btime = Select-String -Path '/proc/stat' -Pattern '^btime\s+(\d+)' -ErrorAction SilentlyContinue
                if ($btime) {
                    $boot = [DateTimeOffset]::FromUnixTimeSeconds([int64]$btime.Matches[0].Groups[1].Value).LocalDateTime
                }
            }
            elseif ($IsMacOS) {
                $kern = & sysctl -n kern.boottime 2>$null
                if ($kern -match 'sec = (\d+)') {
                    $boot = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Matches[1]).LocalDateTime
                }
            }

            if (-not $boot) {
                Write-Error 'Unable to determine last boot time on this platform.'
                continue
            }

            [PSCustomObject]@{
                ComputerName   = [Environment]::MachineName
                LastBootUpTime = $boot
            }
        }
    }
}
