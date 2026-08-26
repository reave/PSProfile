Function Enable-PSRemotingRemote {
	<#
	.SYNOPSIS
		Enable PSRemoting on a remote device
	.DESCRIPTION
		Enable PSRemoting on a remote computer
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
	Param(
		[Parameter(Mandatory = $false)]
		[string]$ComputerName = $env:COMPUTERNAME,
		[Parameter(Mandatory = $false)]
		[string[]]$TrustedHosts = "*"
	)
	Begin {
		Write-Verbose "Building Command"
		$cargs = @{
			ComputerName = "$($ComputerName)"
			Class        = 'Win32_Process'
			Name         = 'Create'
			ArgumentList = "powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -Command ""& { Start-Process powershell -Verb runAs -ArgumentList ""Enable-PSRemoting -force;Set-Item WSMan:localhost\client\trustedhosts -value $($TrustedHosts)""}"""
			ErrorAction  = 'Stop'
		}
		$tempObject = New-Object -TypeName psobject -Property $cargs
		Write-Verbose "Arguments: $($tempObject)"
	}
	Process {
		Write-Verbose "Creating process"
		Invoke-WmiMethod @args -EnableAllPrivileges
	}
}