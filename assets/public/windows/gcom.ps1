Remove-Item -Path "alias:\gcom" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Stages all changes and commits them with a message.
.DESCRIPTION
    Shorthand for `git add .` followed by `git commit -m <message>`.
.PARAMETER Message
    Words making up the commit message; joined with spaces.
.EXAMPLE
    gcom fix the thing
.OUTPUTS
    None
#>
function gcom {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Message
    )
    git add .
    git commit -m ($Message -join ' ')
}
