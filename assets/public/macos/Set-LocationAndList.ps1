#- If called Swap the CD Alias to my custom function
Remove-Item -Path alias:\cd -Force -ErrorAction SilentlyContinue
New-Alias -Name cd -Value Set-LocationAndList -Description "Change Directory and List" -Force

function Set-LocationAndList {
    <#
    .SYNOPSIS
        Pull a list on ever directory change
    .DESCRIPTION
        Pull a list on ever directory change
    .NOTES
        Name: Set-LocationAndList
        Author: Joseph Ascanio
    .ALIASES
        cd
    #>
    [cmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true
        )]
        [string]$path = "."
    )
    Process {
        if (Test-Path $path) {
            $path = Resolve-Path $path
            Set-Location $path
            Get-ChildItem -Path $path -Force
        }
        else {
            Write-Error "Could not find path $path"
        }
    }
}