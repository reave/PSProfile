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
        # ReadAllBytes rather than Get-Content -Encoding Byte, which PowerShell 7 removed.
        [System.convert]::ToBase64String([System.IO.File]::ReadAllBytes((Convert-Path -LiteralPath $Path)))
    }
}
