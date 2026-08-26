Remove-Item -Path "alias:\tail" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Shows the last lines of a file, optionally following new content.
.DESCRIPTION
    Thin wrapper around Get-Content -Tail, with a -f switch matching Unix
    `tail -f` for continuously streaming appended lines.
.PARAMETER Path
    File to read.
.PARAMETER n
    Number of trailing lines to show. Default 10.
.PARAMETER f
    Keep the file open and stream new lines as they're written.
.EXAMPLE
    tail app.log
    tail app.log -n 50 -f
.OUTPUTS
    System.String
#>
function tail {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,
        [int]$n = 10,
        [switch]$f
    )
    Get-Content -Path $Path -Tail $n -Wait:$f
}
