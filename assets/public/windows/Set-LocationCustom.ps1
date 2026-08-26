function Set-LocationCustom {
    <#
.SYNOPSIS
    Custom implementation of Set-Location
.DESCRIPTION
    Custom implementation of Set-Location. This
    implementation will run a Get-ChildItem after
    Set-Location completes.
.NOTES
    Name: Set-LocationCustom
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