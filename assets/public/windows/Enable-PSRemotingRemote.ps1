function Enable-PSRemotingRemote {
    <#
    .SYNOPSIS
        Enable PSRemoting on a remote device
    .DESCRIPTION
        Enable PSRemoting on a remote computer. Connects over DCOM, since WinRM isn't running there
        yet, and starts an elevated PowerShell that runs Enable-PSRemoting and sets TrustedHosts.
    .PARAMETER ComputerName
        Describes the device name or IP Address of the computer you want to enable PSRemoting on

        Default value is the $env:Computername variable
    .PARAMETER TrustedHosts
        Describes the Trusted Hosts to include for the WinRM Configuration

        Accepts an array of Strings
    .EXAMPLE
        PS C:\> Enable-PSRemotingRemote -ComputerName 'Test-Computer'
        Will attempt to enable PSRemoting on the computer Test-Computer
    .EXAMPLE
        PS C:\> Enable-PSRemotingRemote - ComputeRName 'Test-Computer' -TrustedHosts '*.contoso.com'
        Will attempt to enable PSRemoting on the computer Test-Computer and also updated the TrustedHosts for WinRM to include *.contoso.com
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory = $false)]
        [string[]]$TrustedHosts = "*"
    )
    begin {
        Write-Verbose "Building Command"
        $commandLine = "powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -Command ""& { Start-Process powershell -Verb runAs -ArgumentList ""Enable-PSRemoting -force;Set-Item WSMan:localhost\client\trustedhosts -value $($TrustedHosts)""}"""
        Write-Verbose "Command line: $commandLine"
    }
    process {
        # WinRM isn't running on the target yet, so connect over DCOM.
        $session = New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop
        try {
            Write-Verbose "Creating process"
            Invoke-CimMethod -CimSession $session -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $commandLine } -ErrorAction Stop
        } finally {
            Remove-CimSession -CimSession $session
        }
    }
}
