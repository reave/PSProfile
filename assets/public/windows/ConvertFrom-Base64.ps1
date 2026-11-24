###############################################################################################################
# Filename     :  ConvertFrom-Base64.ps1
# Autor        :  Francois-Xavier Cat (https://github.com/lazywinadmin)
# Repository   :  https://github.com/lazywinadmin/PowerShell
# License      :  MIT - Copyright (c) 2015 Francois-Xavier Cat (inherited from source repository - see LICENSE)
###############################################################################################################

function ConvertFrom-Base64 {
    <#
	.SYNOPSIS
		Converts the specified string, which encodes binary data as base-64 digits, to an equivalent 8-bit unsigned integer array.

	.DESCRIPTION
		Converts the specified string, which encodes binary data as base-64 digits, to an equivalent 8-bit unsigned integer array.

	.PARAMETER String
		Specifies the String to Convert

	.EXAMPLE
		ConvertFrom-Base64 -String $ImageBase64 |Out-File ImageTest.png

	.NOTES
		Francois-Xavier Cat
		@lazywinadm
		www.lazywinadmin.com
		github.com/lazywinadmin
	#>
    [CmdletBinding()]
    PARAM (
        [parameter(Mandatory = $true, ValueFromPipeline)]
        [String]$String
    )
    Process {
        TRY {
            Write-Verbose -Message "[ConvertFrom-Base64] Converting String"
            [System.Text.Encoding]::Default.GetString(
                [System.Convert]::FromBase64String($String)
            )
        }
        CATCH {
            Write-Error -Message "[ConvertFrom-Base64] Something wrong happened"
            $Error[0].Exception.Message
        }
    }
}
