Function Invoke-IvantiInventoryScan {
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
    $LDInventoryScannerPost = "\LANDesk\LDClient\LDISCN32.EXE"

    Foreach ($computer in $ComputerName) {
        Write-Verbose "Verify WSMan Connection to $computer"
        If (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
            Write-Verbose "WSMan is available"
            try {
                Write-Verbose "Creating New CimSession to $computer"
                $session = New-CimSession -ComputerName $computer -ErrorAction Stop

                Write-Verbose "Retrieving Operating System Information for $computer"
                $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem

                If ($os.OSArchitecture -eq '64-bit') {
                    $LDInventoryScanner = Join-Path -Path "C:\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                    $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                    If (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                        Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                    }
                    else {
                        Throw "Cannot find Ivanti inventory scan binary"
                    }
                }
                Else {
                    $LDInventoryScanner = Join-Path -Path "C:\Program Files" -ChildPath $LDInventoryScannerPost
                    $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files" -ChildPath $LDInventoryScannerPost
                    If (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                        Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                    }
                    else {
                        Throw "Cannot find Ivanti inventory scan binary"
                    }
                }

                $LDInventoryArguments = "/F /SYNC /V /NOUI"
                Write-Verbose "Defining Inventory Scanner commandline as $LDInventoryArguments"

                Write-Verbose "Checking if a scan is running already on $computer."
                $iProcess = Get-Process -ComputerName $computer -Name ldiscn32 -ErrorAction SilentlyContinue
                $vProcess = Get-Process -ComputerName $computer -Name vulscan -ErrorAction SilentlyContinue

                If ($iProcess) {
                    Write-Verbose "A previous inventory scan is already running on $computer."
                    Write-Warning "A previous inventory scan is running. Please wait for this scan to finish before initiating another one. $computer."
                    Continue
                }

                If ($vProcess) {
                    Write-Verbose "A vulnerability scan is running on $computer. We cannot initiate an inventory scan while a vulnerability scan is running."
                    Write-Warning "A vulnerability scan is running on $computer. Please wait for this scan to finish before initiating an inventory scan."
                    Continue
                }

                Write-Verbose "Creating New PSSession to $computer"
                $pssession = New-PSSession -ComputerName $computer -ErrorAction Stop

                Write-Verbose "Invoking Inventory Scanner"
                $Process = Invoke-Command -Session $pssession -ScriptBlock { param ($FilePath, $MyArgs) Start-Process -FilePath "$($FilePath)" -ArgumentList $($MyArgs) -Passthru -WindowStyle Hidden } -ArgumentList $LDInventoryScanner, $LDInventoryArguments
                If ($Process) {
                    Write-Verbose "Inventory scan has begun. Outputting Process object."
                    Write-Output $Process
                }
                Else {
                    Write-Verbose "Did not find the inventory scanner running on $computer. Something may have gone wrong."
                    Write-Error -Category ResourceUnavailable -Message "Failed to start scan on $computer"
                }
            }
            Catch {
                Throw "An error occured"
            }
        }
        else {
            Write-Verbose "WSMan is not available"
            Write-Verbose "Retrieving Operating System Information for $computer"
            $os = Get-WMIObject -Class Win32_OperatingSystem -ComputerName $computer -ErrorAction Stop

            If ($os.OSArchitecture -eq '64-bit') {
                $LDInventoryScanner = Join-Path -Path "C:\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files (x86)" -ChildPath $LDInventoryScannerPost
                If (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                    Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                }
                else {
                    Throw "Cannot find Ivanti inventory scan binary"
                }
            }
            Else {
                $LDInventoryScanner = Join-Path -Path "C:\Program Files" -ChildPath $LDInventoryScannerPost
                $RemotePathTest = Join-Path -Path "\\$($computer)\c$\Program Files" -ChildPath $LDInventoryScannerPost
                If (Test-Path -Path $RemotePathTest -ErrorAction SilentlyContinue) {
                    Write-Verbose "Detected inventory scan binary at $RemotePathTest"
                }
                else {
                    Throw "Cannot find Ivanti inventory scan binary"
                }
            }

            $LDInventoryArguments = "/F /SYNC /V /NOUI"
            Write-Verbose "Defining Inventory Scanner commandline as $LDInventoryArguments"

            Write-Verbose "Checking if a scan is running already on $computer."
            $iProcess = Get-Process -ComputerName $computer -Name ldiscn32 -ErrorAction SilentlyContinue
            $vProcess = Get-Process -ComputerName $computer -Name vulscan -ErrorAction SilentlyContinue

            If ($iProcess) {
                Write-Verbose "A previous inventory scan is already running on $computer."
                Write-Warning "A previous inventory scan is running. Please wait for this scan to finish before initiating another one. $computer."
                Continue
            }

            If ($vProcess) {
                Write-Verbose "A vulnerability scan is running on $computer. We cannot initiate an inventory scan while a vulnerability scan is running."
                Write-Warning "A vulnerability scan is running on $computer. Please wait for this scan to finish before initiating an inventory scan."
                Continue
            }

            $Result = Start-Process psexec -ArgumentList "\\$($computer) -s ""$($LDInventoryScanner)"" $LDInventoryArguments" -PassThru -WindowStyle Hidden

            If ($Result) {
                Write-Debug "Sleeping 2 seconds to allow the process to start up."
                Start-Sleep -Seconds 2

                Write-Verbose "The PsExec process has started. Checking for the existence of ldiscn32 on $computer"
                $Process = Get-Process -ComputerName $computer -Name 'ldiscn32' -ErrorAction SilentlyContinue

                If ($Process) {
                    Write-Verbose "Inventory scan has begun. Outputting Process object."
                    Write-Output $Process
                }
                Else {
                    Write-Verbose "Did not find the inventory scanner running on $computer. Something may have gone wrong."
                    Write-Error -Category ResourceUnavailable -Message "Failed to start scan on $computer"
                }
            }
        }
    }
}