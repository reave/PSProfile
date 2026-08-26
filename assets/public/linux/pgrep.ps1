Remove-Item -Path "alias:\pgrep" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Finds processes by name.
.DESCRIPTION
    Shorthand for Get-Process -Name, tolerating no match instead of erroring.
.PARAMETER Name
    Process name to match.
.EXAMPLE
    pgrep notepad
.OUTPUTS
    System.Diagnostics.Process
#>
function pgrep {
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    Get-Process -Name $Name -ErrorAction SilentlyContinue
}
