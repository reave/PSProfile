###############################################################################################################
# Filename     :  Get-ImageInformation.ps1
# Autor        :  Francois-Xavier Cat (https://github.com/lazywinadmin)
# Repository   :  https://github.com/lazywinadmin/PowerShell
# License      :  MIT - Copyright (c) 2015 Francois-Xavier Cat (inherited from source repository - see LICENSE)
###############################################################################################################

function Get-ImageInformation {
    <#
.SYNOPSIS
	function to retrieve Image file information

.DESCRIPTION
	function to retrieve Image file information

.PARAMETER FilePath
	Specify one or multiple image file path(s).

.EXAMPLE
	PS C:\> Get-ImageInformation -FilePath c:\temp\image.png

.NOTES
	Francois-Xavier Cat
	lazywinadmin.com
	@lazywinadm
	github.com/lazywinadmin
#>
    PARAM (
        [System.String[]]$FilePath
    )
    Foreach ($Image in $FilePath) {
        # Load Assembly
        Add-type -AssemblyName System.Drawing

        # Retrieve information
        New-Object -TypeName System.Drawing.Bitmap -ArgumentList $Image
    }
}