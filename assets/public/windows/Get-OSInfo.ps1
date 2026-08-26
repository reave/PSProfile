Function Get-OSInfo {
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
        Get-OSInfo.ps1 -ComputerName TestComputer

        Gets Operating System Information for the TestComputer
    .EXAMPLE
        Get-OSInfo.ps1 -ComputerName TestComputer,TestComputer2

        Gets Operating System Information for the TestComputer and TestComputer2
    .NOTES
        Author: Joseph Ascanio
        Last Modified Date: 07/26/16
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "The. Computer. Name.")]
        [Alias('Hostname', 'cn', 'Name')]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )

    foreach ($computer in $ComputerName) {
        Write-Verbose "Verify WSMan Connection to $computer"
        if ($computer = $env:COMPUTERNAME) {
            try {
                Write-Verbose "Retrieving Operating System information from $computer"
                $os = Get-CimInstance -ClassName Win32_OperatingSystem
                $properties = @{
                    ComputerName     = $computer
                    Status           = 'Connected'
                    OSName           = $os.Caption
                    SPVersion        = $os.ServicePackMajorVersion
                    OSVersion        = $os.Version
                    OSArchitecture   = $os.OSArchitecture
                    LastBootUpTime   = $os.LastBootUpTime
                    InstallDirectory = $os.WindowsDirectory
                }
            }
            catch {
                Write-Error "An error occured"
                $properties = @{
                    ComputerName     = $computer
                    Status           = 'Disconnected'
                    OSName           = $Null
                    SPVersion        = $Null
                    OSVersion        = $Null
                    OSArchitecture   = $Null
                    LastBootUpTime   = $Null
                    InstallDirectory = $Null
                }
            }
            finally {
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }
        }
        elseif (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
            Write-Verbose "WSMan is available"
            try {
                Write-Verbose "Creating New CimSession to $computer"
                $session = New-CimSession -ComputerName $computer -ErrorAction Stop

                Write-Verbose "Retrieving Operating System information from $computer"
                $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem
                $properties = @{
                    ComputerName     = $computer
                    Status           = 'Connected'
                    OSName           = $os.Caption
                    SPVersion        = $os.ServicePackMajorVersion
                    OSVersion        = $os.Version
                    OSArchitecture   = $os.OSArchitecture
                    LastBootUpTime   = $os.LastBootUpTime
                    InstallDirectory = $os.WindowsDirectory
                }
            }
            catch {
                Write-Error "An error occured"
                $properties = @{
                    ComputerName     = $computer
                    Status           = 'Disconnected'
                    OSName           = $Null
                    SPVersion        = $Null
                    OSVersion        = $Null
                    OSArchitecture   = $Null
                    LastBootUpTime   = $Null
                    InstallDirectory = $Null
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
                Write-Verbose "Retrieving Opearting System Information information for $computer"
                $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computer -ErrorAction Stop
                $properties = @{
                    ComputerName     = $computer
                    Status           = 'Connected'
                    OSName           = $os.Caption
                    SPVersion        = $os.ServicePackMajorVersion
                    OSVersion        = $os.Version
                    OSArchitecture   = $os.OSArchitecture
                    LastBootUpTime   = $os.ConvertToDateTime($os.LastBootUpTime)
                    InstallDirectory = $os.WindowsDirectory
                }
            }
            catch {
                Write-Error "An error occured"
                $properties = @{
                    ComputerName     = $computer
                    Status           = 'Disconnected'
                    OSName           = $Null
                    SPVersion        = $Null
                    OSVersion        = $Null
                    OSArchitecture   = $Null
                    LastBootUpTime   = $Null
                    InstallDirectory = $Null
                }
            }
            finally {
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }
        }
    }
}