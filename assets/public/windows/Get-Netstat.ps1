function Get-NetStat {
    <#
.SYNOPSIS
	This function will get the output of netstat -n and parse the output
.DESCRIPTION
	This function will get the output of netstat -n and parse the output
.LINK
	http://www.lazywinadmin.com/2014/08/powershell-parse-this-netstatexe.html
.NOTES
	Francois-Xavier Cat
	www.lazywinadmin.com
	@LazyWinAdm
#>
    PROCESS {
        # Get the output of netstat
        $data = netstat -anob

        # Keep only the line with the data (we remove the first lines)
        $data = $data | Select-Object -Skip 4

        # Each line needs to be split and unnecessary spaces removed
        foreach ($line in $data) {
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            # Get rid of the first whitespaces, at the beginning of the line
            $trimmed = $line -replace '^\s+', ''

            # Split each property on whitespace
            $tokens = $trimmed -split '\s+'

            # Need at least Protocol, Local and Foreign address tokens
            if ($tokens.Count -lt 3) { continue }

            # Split address:port on the last colon to handle IPv6 addresses like [::]:80
            $localParts = $tokens[1] -split ':(?=[^:]*$)'
            $foreignParts = $tokens[2] -split ':(?=[^:]*$)'

            # State is optional (e.g., UDP entries); default to empty string if missing
            $state = if ($tokens.Count -gt 3) { $tokens[3] } else { '' }

            # Determine PID (last token is usually the PID when using -o)
            $possiblePid = $tokens | Select-Object -Last 1
            $tpid = if ($possiblePid -and ($possiblePid -as [int])) { $possiblePid } else { '' }

            # Try to resolve process name from the PID; if that fails, try to read the next line's [exe] entry
            $processName = ''
            if ($tpid) {
                $proc = Get-Process -Id $tpid -ErrorAction SilentlyContinue
                if ($proc) {
                    $processName = $proc.ProcessName
                }
                else {
                    $index = [array]::IndexOf($data, $line)
                    if ($index -ge 0 -and ($index + 1) -lt $data.Count) {
                        $nextLine = $data[$index + 1] -replace '^\s+', ''
                        if ($nextLine -match '^\[(.+?)\]') { $processName = $Matches[1] }
                    }
                }
            }

            # Define the properties
            $properties = @{
                Protocole          = $tokens[0]
                LocalAddressIP     = $localParts[0]
                LocalAddressPort   = if ($localParts.Count -gt 1) { $localParts[1] } else { '' }
                ForeignAddressIP   = $foreignParts[0]
                ForeignAddressPort = if ($foreignParts.Count -gt 1) { $foreignParts[1] } else { '' }
                State              = $state
                ProcessId          = $pid
                ProcessName        = $processName
            }

            # Output the current line
            New-Object -TypeName PSObject -Property $properties
        }
    }
}