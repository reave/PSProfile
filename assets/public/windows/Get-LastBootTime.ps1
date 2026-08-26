function Get-LastBootTime {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:ComputerName
    )
    Process {
        Write-Verbose "Getting uptime for $ComputerName"
        if ($ComputerName -eq $env:ComputerName) {
            Try {
                Get-CimInstance -ClassName win32_operatingsystem -ErrorAction Stop | Select-Object @{LABEL = "ComputerName"; EXPRESSION = { $_.csname } }, LastbootUpTime
            }
            Catch {
                Write-Error $_.Exception.Message
            }
        }
        else {
            Try { Get-CimInstance -ClassName win32_operatingsystem -ComputerName $ComputerName -ErrorAction Stop | Select-Object @{LABEL = "ComputerName"; EXPRESSION = { $_.csname } }, LastbootUpTime }
            Catch {
                $props = @{
                    ComputerName   = $ComputerName
                    LastbootUpTime = "Error"
                }
                New-Object -TypeName PSObject -Property $props
            }
        }
    }
}