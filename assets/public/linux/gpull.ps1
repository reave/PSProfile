Remove-Item -Path "alias:\gpull" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Pulls the current branch.
.DESCRIPTION
    Shorthand for `git pull`, forwarding any arguments.
.PARAMETER Arguments
    Arguments to forward to `git pull`.
.EXAMPLE
    gpull
    gpull --rebase
.OUTPUTS
    None
#>
function gpull {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )
    git pull @Arguments
}
