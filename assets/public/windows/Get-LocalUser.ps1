###############################################################################################################
# Filename     :  Get-LocalUser.ps1
# Autor        :  Francois-Xavier Cat (https://github.com/lazywinadmin)
# Repository   :  https://github.com/lazywinadmin/PowerShell
# License      :  MIT - Copyright (c) 2015 Francois-Xavier Cat (inherited from source repository - see LICENSE)
###############################################################################################################

function Get-LocalUser {

    <#
	.SYNOPSIS
		This script can be list all of local user account.

	.DESCRIPTION
		This script can be list all of local user account.
		The function is using CIM to connect to the remote machine, over WSMan or, failing that, DCOM

	.PARAMETER ComputerName
		Specifies the computers on which the command . The default is the local computer.

	.PARAMETER Credential
		A description of the Credential parameter.


	.EXAMPLE
		Get-LocalUser

		This example shows how to list all of local users on local computer.

	.NOTES
		Francois-Xavier Cat
		www.lazywinadmin.com
		@lazywinadm
#>

    PARAM
    (
        [Alias('cn')]
        [String[]]$ComputerName = $Env:COMPUTERNAME,

        [String]$AccountName,

        [System.Management.Automation.PsCredential]$Credential
    )

    $Splatting = @{
        ClassName = "Win32_UserAccount"
        Namespace = "root\cimv2"
        Filter    = "LocalAccount='$True'"
    }

    #Credentials
    $SessionSplat = @{ ErrorAction = 'Stop' }
    If ($PSBoundParameters['Credential']) { $SessionSplat.Credential = $Credential }

    Foreach ($Computer in $ComputerName) {
        TRY {
            Write-Verbose -Message "[PROCESS] ComputerName: $Computer"
            $CimParams = @{}
            $CimSession = $null
            IF ($Computer -notin $env:COMPUTERNAME, 'localhost', '.' -or $PSBoundParameters['Credential']) {
                # WSMan first, then DCOM, which is how Get-WmiObject connected
                TRY { $CimSession = New-CimSession @SessionSplat -ComputerName $Computer }
                CATCH { $CimSession = New-CimSession @SessionSplat -ComputerName $Computer -SessionOption (New-CimSessionOption -Protocol Dcom) }
                $CimParams.CimSession = $CimSession
            }
            Get-CimInstance @Splatting @CimParams | Select-Object -Property Name, FullName, Caption, Disabled, Status, Lockout, PasswordChangeable, PasswordExpires, PasswordRequired, SID, SIDType, AccountType, Domain, Description
            IF ($CimSession) { Remove-CimSession -CimSession $CimSession }
        }
        CATCH {
            Write-Warning -Message "[PROCESS] Issue connecting to $Computer"
        }
    }
}