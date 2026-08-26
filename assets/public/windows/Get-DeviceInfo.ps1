Function Get-DeviceInfo {
    <#
    .SYNOPSIS
        Get Operating System information
    .DESCRIPTION
        Get Operating System Information from WMI on all devices specified
    .PARAMETER ComputerName
        Accepts a single string or an array of strings containing ComputerNames

        Aliases: Hostname,cn,Name
        Accepts Values from Pipeline
        Accepts Values from Pipeline by Property Name
    .EXAMPLE
        Get-OSInfo -ComputerName TestComputer

        Gets Operating System Information for the TestComputer
    .EXAMPLE
        Get-OSInfo -ComputerName TestComputer,TestComputer2

        Gets Operating System Information for the TestComputer and TestComputer2
    .NOTES
        Author: Joseph Ascanio
        Last Modified Date: 07/26/16
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "The. Computer. Name."
        )
        ]
        [Alias('Hostname', 'cn', 'Name')]
        [string[]]$ComputerName
    )

    foreach ($computer in $ComputerName) {
        Write-Verbose "Verify WSMan Connection to $computer"
        If (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
            Write-Verbose "WSMan is available"
            try {
                Write-Verbose "Creating New CimSession to $computer"
                $session = New-CimSession -ComputerName $computer -ErrorAction Stop

                Write-Verbose "Retrieving computer information for $computer"
                $cs = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem
                $properties = @{
                    ComputerName              = $computer
                    Status                    = 'Connected'
                    Model                     = $cs.Model
                    Manufacturer              = $cs.Manufacturer
                    NumberOfProcessors        = $cs.NumberOfProcessors
                    NumberOfLogicalProcessors = $cs.NumberOfLogicalProcessors
                    PartOfDomain              = $cs.PartOfDomain
                    TotalPhysicalMemory       = "$([math]::round(($cs.TotalPhysicalMemory / 1GB),2)) GB"
                }
            }
            catch {
                Write-Error "An error occured"
                $properties = @{
                    ComputerName              = $computer
                    Status                    = 'Disconnected'
                    Model                     = $Null
                    Manufacturer              = $Null
                    NumberOfProcessors        = $Null
                    NumberOfLogicalProcessors = $Null
                    PartOfDomain              = $Null
                    TotalPhysicalMemory       = $Null
                }
            }
            finally {
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }
        }
        Else {
            Write-Verbose "WSMan is not available"
            try {
                Write-Verbose "Retrieving computer information for $computer"
                $cs = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer -ErrorAction Stop
                $properties = @{
                    ComputerName              = $computer
                    Status                    = 'Connected'
                    Model                     = $cs.Model
                    Manufacturer              = $cs.Manufacturer
                    NumberOfProcessors        = $cs.NumberOfProcessors
                    NumberOfLogicalProcessors = $cs.NumberOfLogicalProcessors
                    PartOfDomain              = $cs.PartOfDomain
                    TotalPhysicalMemory       = "$([math]::round(($cs.TotalPhysicalMemory / 1GB),2)) GB"
                }
            }
            catch {
                Write-Error "An error occured"
                $properties = @{
                    ComputerName              = $computer
                    Status                    = 'Disconnected'
                    Model                     = $Null
                    Manufacturer              = $Null
                    NumberOfProcessors        = $Null
                    NumberOfLogicalProcessors = $Null
                    PartOfDomain              = $Null
                    TotalPhysicalMemory       = $Null
                }
            }
            finally {
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }
        }
    }
}