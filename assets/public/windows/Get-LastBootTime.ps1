function Get-LastBootTime {
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
