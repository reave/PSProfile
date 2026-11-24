function Get-LastBootTime {
    <#
    .SYNOPSIS
        Returns when one or more computers last started.

    .DESCRIPTION
        Queries Win32_OperatingSystem through CIM and returns the computer name and LastBootUpTime.
        If a remote computer can't be queried, it returns an object for it with LastBootUpTime set to
        "Error". If the local query fails, it writes the error instead.

    .PARAMETER ComputerName
        The computers to query. Accepts pipeline input. The default is the local computer.

    .EXAMPLE
        Get-LastBootTime

        Returns when the local computer last started.

    .EXAMPLE
        Get-LastBootTime -ComputerName 'Server01'

        Returns when Server01 last started.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:ComputerName
    )
    process {
        Write-Verbose "Getting uptime for $ComputerName"
        if ($ComputerName -eq $env:ComputerName) {
            try {
                Get-CimInstance -ClassName win32_operatingsystem -ErrorAction Stop | Select-Object @{LABEL = "ComputerName"; EXPRESSION = { $_.csname } }, LastbootUpTime
            } catch {
                Write-Error $_.Exception.Message
            }
        } else {
            try { Get-CimInstance -ClassName win32_operatingsystem -ComputerName $ComputerName -ErrorAction Stop | Select-Object @{LABEL = "ComputerName"; EXPRESSION = { $_.csname } }, LastbootUpTime }
            catch {
                $props = @{
                    ComputerName   = $ComputerName
                    LastbootUpTime = "Error"
                }
                New-Object -TypeName PSObject -Property $props
            }
        }
    }
}
