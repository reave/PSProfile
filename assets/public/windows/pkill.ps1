Remove-Item -Path "alias:\pkill" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Kills processes by name.
.DESCRIPTION
    Shorthand for finding processes by name and forcibly stopping them.
.PARAMETER Name
    Process name to match (same as Get-Process -Name).
.EXAMPLE
    pkill notepad
.OUTPUTS
    None
#>
function pkill {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}
