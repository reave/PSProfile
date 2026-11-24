#- If called Swap the CD Alias to my custom function
Remove-Item -Path alias:\cd -Force -ErrorAction SilentlyContinue
New-Alias -Name cd -Value Set-LocationAndList -Description "Change Directory and List" -Force

function Set-LocationAndList {
    <#
    .SYNOPSIS
        Changes to a folder and lists its contents.

    .DESCRIPTION
        Resolves path, makes it the current location, and lists everything in it, including hidden
        items. Writes an error if the path doesn't exist. This script also makes cd an alias for this
        function.

    .PARAMETER path
        The folder to change to. Accepts pipeline input. The default is the current folder.

    .EXAMPLE
        Set-LocationAndList -path "$HOME\Documents"

        Changes to your Documents folder and lists what's in it.

    .NOTES
        Name: Set-LocationAndList
        Author: reave (https://github.com/reave)
    #>
    [cmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Only changes the current location of the session.')]
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
