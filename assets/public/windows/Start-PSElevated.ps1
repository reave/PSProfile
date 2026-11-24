Function Start-PSElevated {
	<#
	.SYNOPSIS
		Execute a command or start an elevated PS Prompt
	.DESCRIPTION
		Executes a provided scriptblock or opens an elevated powershell prompt
	.EXAMPLE
		PS C:\> Start-PSElevated -ScriptBlock 'Get-Service'

		Runs the scriptblock 'get-service' in an elevated context
	#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $false)]
		[string]$ScriptBlock,
		[Parameter(Mandatory = $false)]
		[switch]$NoExit
	)

	$sh = new-object -com 'Shell.Application'

	If ($ScriptBlock -eq '') {
		$sh.ShellExecute('powershell', '-NoLogo', '', 'runas')
	}
	Else {
		If ($NoExit) {
			$sh.ShellExecute('powershell', "-NoExit -Command $scriptblock", '', 'runas')
		}
		Else {
			$sh.ShellExecute('powershell', "-Command $scriptblock", '', 'runas')
		}
	}
}