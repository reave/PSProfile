Remove-Item -Path "alias:\gcl" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Clones a git repository.
.DESCRIPTION
    Shorthand for `git clone`, forwarding any arguments.
.PARAMETER Arguments
    Arguments to forward to `git clone`.
.EXAMPLE
    gcl https://github.com/user/repo.git
.OUTPUTS
    None
#>
function gcl {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )
    git clone @Arguments
}
