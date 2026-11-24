###############################################################################################################
# Filename     :  ConvertTo-Base64.ps1
# Autor        :  Francois-Xavier Cat (https://github.com/lazywinadmin)
# Repository   :  https://github.com/lazywinadmin/PowerShell
# License      :  MIT - Copyright (c) 2015 Francois-Xavier Cat (inherited from source repository - see LICENSE)
###############################################################################################################

function ConvertTo-Base64 {
    <#
	.SYNOPSIS
		Function to convert an image to Base64

	.DESCRIPTION
		Function to convert an image to Base64

	.PARAMETER Path
		Specifies the path of the file

	.EXAMPLE
		ConvertTo-Base64 -Path "C:\images\PowerShellLogo.png"

	.NOTES
		Francois-Xavier Cat
		@lazywinadm
		www.lazywinadmin.com
		github.com/lazywinadmin
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateScript( { Test-Path -Path $_ })]
        [String]$Path
    )
    Process {
        Write-Verbose -Message "[ConvertTo-Base64] Converting image to Base64 $Path"
        [System.convert]::ToBase64String((Get-Content -Path $path -Encoding Byte))
    }
}
