Remove-Item -Path "alias:\unzip" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Extracts a zip archive into the current directory.
.DESCRIPTION
    Thin wrapper around Expand-Archive - the extraction counterpart to this
    profile's New-ZipFile, which only creates archives.
.PARAMETER File
    Path to the zip file to extract.
.EXAMPLE
    unzip archive.zip
.OUTPUTS
    None
#>
function unzip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$File
    )

    if (-not (Test-Path -Path $File -PathType Leaf)) {
        Write-Error "File not found: $File"
        return
    }

    Expand-Archive -Path $File -DestinationPath (Get-Location) -Force
}
