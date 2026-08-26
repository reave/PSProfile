<#
.SYNOPSIS
	Returns the local computer uptime.

.DESCRIPTION
	Get-Uptime returns the last boot time and the uptime as a TimeSpan and common total values.
	Works on Windows (WMI/CIM) and Unix-like systems (procfs or sysctl).

.PARAMETER AsTimespan
	Return only the TimeSpan representing uptime.

.PARAMETER AsObject
	Return a PSCustomObject with properties: ComputerName, LastBootUpTime, Uptime, TotalDays, TotalHours, TotalMinutes, TotalSeconds.

.EXAMPLE
	Get-Uptime

.EXAMPLE
	Get-Uptime -AsTimespan

.OUTPUTS
	System.TimeSpan
	PSCustomObject

.NOTES


#>
function Get-Uptime {
	[CmdletBinding()]
	param(
		[switch]$AsTimespan,
		[switch]$AsObject
	)

	try {
		if ($IsWindows) {
			$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
			$boot = $os.LastBootUpTime
			$computer = $env:COMPUTERNAME
		}
		else {
			$computer = (hostname)
			if (Test-Path -Path '/proc/uptime') {
				$upt = (Get-Content -Path '/proc/uptime' -Raw).Split()[0]
				$timespan = [timespan]::FromSeconds([double]$upt)
				$boot = (Get-Date).AddSeconds(-$timespan.TotalSeconds)
			}
			else {
				$kern = & sysctl -n kern.boottime 2>$null
				if ($kern -and ($kern -match 'sec = (\d+)')) {
					$sec = [int64]$matches[1]
					$boot = (Get-Date 1970-01-01).AddSeconds($sec)
				}
				else {
					throw 'Unable to determine last boot time on this platform.'
				}
			}
		}

		$now = Get-Date
		$uptime = $now - $boot

		$result = [PSCustomObject]@{
			ComputerName   = $computer
			LastBootUpTime = $boot
			Uptime         = $uptime
			UptimeHuman    = "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
			TotalDays      = [math]::Round($uptime.TotalDays, 6)
			TotalHours     = [math]::Round($uptime.TotalHours, 6)
			TotalMinutes   = [math]::Round($uptime.TotalMinutes, 4)
			TotalSeconds   = [math]::Round($uptime.TotalSeconds, 2)
		}

		if ($AsTimespan) { return $uptime }
		elseif ($AsObject) { return $result }
		else { return $result }
	}
	catch {
		Write-Error "Get-Uptime failed: $($_.Exception.Message)"
	}
}