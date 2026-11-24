function Invoke-IvantiInventoryScan {
    <#
    .SYNOPSIS
    Start an Ivanti UEM Inventory Scan

    .DESCRIPTION
    Start an Ivanti UEM Inventory Scan on a computer or group of computers

    .PARAMETER ComputerName
    The computer, list of computers to scan.

    Default: $env:computername
    .EXAMPLE
    Invoke-IvantiInventoryScan -ComputerName DeviceName

    .NOTES
    ToDo: Right now this initiates a full sync scan. I would like to
    add a parameter for type of scan. This way we can handle
    delta scans, full sync scans, hardware scans, software scans,
    scans to file, etc...

    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "The. Computer. Name.")]
        [Alias('Hostname', 'cn', 'Name')]
        [string[]]$ComputerName
    )
    process {
        $LDInventoryScannerPost = "\LANDesk\LDClient\LDISCN32.EXE"

        foreach ($computer in $ComputerName) {
            Write-Verbose "Verify WSMan Connection to $computer"
            if (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
                Write-Verbose "WSMan is available"
                try {
                    Write-Verbose "Creating New CimSession to $computer"
                    $session = New-CimSession -ComputerName $computer -ErrorAction Stop

                    Write-Verbose "Retrieving Operating System Information for $computer"
                    $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem

                    if ($os.OSArchitecture -eq '64-bit') {
                        $LDInventoryScanner = Join-Path -Path "C:\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                        $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                        if (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                            Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                        } else {
                            throw "Cannot find Ivanti inventory scan binary"
                        }
                    } else {
                        $LDInventoryScanner = Join-Path -Path "C:\Program Files" -ChildPath $LDInventoryScannerPost
                        $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files" -ChildPath $LDInventoryScannerPost
                        if (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                            Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                        } else {
                            throw "Cannot find Ivanti inventory scan binary"
                        }
                    }

                    $LDInventoryArguments = "/F /SYNC /V /NOUI"
                    Write-Verbose "Defining Inventory Scanner commandline as $LDInventoryArguments"

                    Write-Verbose "Checking if a scan is running already on $computer."
                    $iProcess = Get-CimInstance -CimSession $session -ClassName Win32_Process -Filter "Name='ldiscn32.exe'" -ErrorAction SilentlyContinue
                    $vProcess = Get-CimInstance -CimSession $session -ClassName Win32_Process -Filter "Name='vulscan.exe'" -ErrorAction SilentlyContinue

                    if ($iProcess) {
                        Write-Verbose "A previous inventory scan is already running on $computer."
                        Write-Warning "A previous inventory scan is running. Please wait for this scan to finish before initiating another one. $computer."
                        continue
                    }

                    if ($vProcess) {
                        Write-Verbose "A vulnerability scan is running on $computer. We cannot initiate an inventory scan while a vulnerability scan is running."
                        Write-Warning "A vulnerability scan is running on $computer. Please wait for this scan to finish before initiating an inventory scan."
                        continue
                    }

                    Write-Verbose "Creating New PSSession to $computer"
                    $pssession = New-PSSession -ComputerName $computer -ErrorAction Stop

                    Write-Verbose "Invoking Inventory Scanner"
                    $Process = Invoke-Command -Session $pssession -ScriptBlock {
                        $startParams = @{
                            FilePath = $using:LDInventoryScanner
                            ArgumentList = $using:LDInventoryArguments
                            PassThru = $true
                            WindowStyle = 'Hidden'
                        }
                        Start-Process @startParams
                    }
                    if ($Process) {
                        Write-Verbose "Inventory scan has begun. Outputting Process object."
                        Write-Output $Process
                    } else {
                        Write-Verbose "Did not find the inventory scanner running on $computer. Something may have gone wrong."
                        Write-Error -Category ResourceUnavailable -Message "Failed to start scan on $computer"
                    }
                } catch {
                    throw "An error occured"
                } finally {
                    if ($pssession) { Remove-PSSession -Session $pssession; $pssession = $null }
                    if ($session) { Remove-CimSession -CimSession $session; $session = $null }
                }
            } else {
                Write-Verbose "WSMan is not available"
                Write-Verbose "Retrieving Operating System Information for $computer"
                $session = New-CimSession -ComputerName $computer -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop
                try {
                    $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem -ErrorAction Stop

                    if ($os.OSArchitecture -eq '64-bit') {
                        $LDInventoryScanner = Join-Path -Path "C:\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                        $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                        if (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                            Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                        } else {
                            throw "Cannot find Ivanti inventory scan binary"
                        }
                    } else {
                        $LDInventoryScanner = Join-Path -Path "C:\Program Files" -ChildPath $LDInventoryScannerPost
                        $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files" -ChildPath $LDInventoryScannerPost
                        if (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                            Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                        } else {
                            throw "Cannot find Ivanti inventory scan binary"
                        }
                    }

                    $LDInventoryArguments = "/F /SYNC /V /NOUI"
                    Write-Verbose "Defining Inventory Scanner commandline as $LDInventoryArguments"

                    Write-Verbose "Checking if a scan is running already on $computer."
                    $iProcess = Get-CimInstance -CimSession $session -ClassName Win32_Process -Filter "Name='ldiscn32.exe'" -ErrorAction SilentlyContinue
                    $vProcess = Get-CimInstance -CimSession $session -ClassName Win32_Process -Filter "Name='vulscan.exe'" -ErrorAction SilentlyContinue

                    if ($iProcess) {
                        Write-Verbose "A previous inventory scan is already running on $computer."
                        Write-Warning "A previous inventory scan is running. Please wait for this scan to finish before initiating another one. $computer."
                        continue
                    }

                    if ($vProcess) {
                        Write-Verbose "A vulnerability scan is running on $computer. We cannot initiate an inventory scan while a vulnerability scan is running."
                        Write-Warning "A vulnerability scan is running on $computer. Please wait for this scan to finish before initiating an inventory scan."
                        continue
                    }

                    $Result = Start-Process psexec -ArgumentList "\\$($computer) -s ""$($LDInventoryScanner)"" $LDInventoryArguments" -PassThru -WindowStyle Hidden

                    if ($Result) {
                        Write-Debug "Sleeping 2 seconds to allow the process to start up."
                        Start-Sleep -Seconds 2

                        Write-Verbose "The PsExec process has started. Checking for the existence of ldiscn32 on $computer"
                        $Process = Get-CimInstance -CimSession $session -ClassName Win32_Process -Filter "Name='ldiscn32.exe'" -ErrorAction SilentlyContinue

                        if ($Process) {
                            Write-Verbose "Inventory scan has begun. Outputting Process object."
                            Write-Output $Process
                        } else {
                            Write-Verbose "Did not find the inventory scanner running on $computer. Something may have gone wrong."
                            Write-Error -Category ResourceUnavailable -Message "Failed to start scan on $computer"
                        }
                    }
                } finally {
                    Remove-CimSession -CimSession $session
                }
            }
        }
    }
}
