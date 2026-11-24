function Set-LocationCustom {
    <#
    .SYNOPSIS
        Changes to a folder and lists its contents.

    .DESCRIPTION
        A version of Set-Location that runs Get-ChildItem afterwards. It resolves path, makes it the
        current location, and lists everything in it, including hidden items. Writes an error if the
        path doesn't exist.

    .PARAMETER path
        The folder to change to. Accepts pipeline input. The default is the current folder.

    .EXAMPLE
        Set-LocationCustom -path "$HOME\Documents"

        Changes to your Documents folder and lists what's in it.

    .NOTES
        Name: Set-LocationCustom
        Author: reave (https://github.com/reave)
    #>
    [cmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true
        )]
        [string]$path = "."
    )
    process {
        if (Test-Path $path) {
            $path = Resolve-Path $path
            Set-Location $path
            Get-ChildItem -Path $path -Force
        } else {
            Write-Error "Could not find path $path"
        }
    }
}
