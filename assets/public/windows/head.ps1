Remove-Item -Path "alias:\head" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Shows the first lines of a file.
.DESCRIPTION
    Thin wrapper around Get-Content -TotalCount - the natural counterpart to
    this profile's tail function.
.PARAMETER Path
    File to read.
.PARAMETER n
    Number of leading lines to show. Default 10.
.EXAMPLE
    head app.log
    head app.log -n 50
.OUTPUTS
    System.String
#>
function head {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,
        [int]$n = 10
    )
    Get-Content -Path $Path -TotalCount $n
}
