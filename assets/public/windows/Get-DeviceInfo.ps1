function Get-DeviceInfo {
    <#
    .SYNOPSIS
        Get Operating System information
    .DESCRIPTION
        Get computer information through CIM on all devices specified, over WSMan or, when WSMan is not available, DCOM
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
        Author: reave (https://github.com/reave)
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
    process {

        foreach ($computer in $ComputerName) {
            Write-Verbose "Verify WSMan Connection to $computer"
            if (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
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
                } catch {
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
                } finally {
                    if ($session) { Remove-CimSession -CimSession $session; $session = $null }
                    $obj = New-Object -TypeName psobject -Property $properties
                    Write-Output $obj
                }
            } else {
                Write-Verbose "WSMan is not available"
                try {
                    Write-Verbose "Retrieving computer information for $computer"
                    $cimSessionParams = @{
                        ComputerName = $computer
                        SessionOption = (New-CimSessionOption -Protocol Dcom)
                        ErrorAction = 'Stop'
                    }
                    $session = New-CimSession @cimSessionParams
                    $cs = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem -ErrorAction Stop
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
                } catch {
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
                } finally {
                    if ($session) { Remove-CimSession -CimSession $session; $session = $null }
                    $obj = New-Object -TypeName psobject -Property $properties
                    Write-Output $obj
                }
            }
        }
    }
}
