Remove-Item -Path "alias:\lazyg" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Stages, commits, and pushes all changes in one step.
.DESCRIPTION
    Shorthand for `git add .`, `git commit -m <message>`, then `git push`.
.PARAMETER Message
    Words making up the commit message; joined with spaces.
.EXAMPLE
    lazyg fix the thing
.OUTPUTS
    None
#>
function lazyg {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Message
    )
    git add .
    git commit -m ($Message -join ' ')
    git push
}
