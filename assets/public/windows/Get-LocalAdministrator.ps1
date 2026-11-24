###############################################################################################################
# Filename     :  Get-LocalAdministrator.ps1
# Autor        :  Francois-Xavier Cat (https://github.com/lazywinadmin)
# Repository   :  https://github.com/lazywinadmin/PowerShell
# License      :  MIT - Copyright (c) 2015 Francois-Xavier Cat (inherited from source repository - see LICENSE)
###############################################################################################################

function Get-LocalAdministratorBuiltin {
    <#
	.SYNOPSIS
		function to retrieve the local Administrator account

	.DESCRIPTION
		function to retrieve the local Administrator account

	.PARAMETER ComputerName
		Specifies the computername

	.EXAMPLE
		PS C:\> Get-LocalAdministratorBuiltin

	.EXAMPLE
		PS C:\> Get-LocalAdministratorBuiltin -ComputerName SERVER01

	.NOTES
		Francois-Xavier Cat
		www.lazywinadmin.com
		@lazywinadm

	#function to get the BUILTIN LocalAdministrator
	#http://blog.simonw.se/powershell-find-builtin-local-administrator-account/
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        $ComputerName = $env:computername
    )
    Process {
        Foreach ($Computer in $ComputerName) {
            Try {
                Add-Type -AssemblyName System.DirectoryServices.AccountManagement
                $PrincipalContext = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $Computer)
                $UserPrincipal = New-Object -TypeName System.DirectoryServices.AccountManagement.UserPrincipal($PrincipalContext)
                $Searcher = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalSearcher
                $Searcher.QueryFilter = $UserPrincipal
                $Searcher.FindAll() | Where-Object { $_.Sid -Like "*-500" }
            }
            Catch {
                Write-Warning -Message "$($_.Exception.Message)"
            }
        }
    }
}