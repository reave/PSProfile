Remove-Item -Path "alias:\gpush" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Pushes the current branch.
.DESCRIPTION
    Shorthand for `git push`, forwarding any arguments.
.PARAMETER Arguments
    Arguments to forward to `git push`.
.EXAMPLE
    gpush
    gpush --force-with-lease
.OUTPUTS
    None
#>
function gpush {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )
    git push @Arguments
}
