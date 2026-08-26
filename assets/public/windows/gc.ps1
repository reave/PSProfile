Remove-Item -Path "alias:\gc" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Commits staged changes with a message.
.DESCRIPTION
    Shorthand for `git commit -m <message>`.
.PARAMETER Message
    Words making up the commit message; joined with spaces.
.EXAMPLE
    gc fix the thing
.OUTPUTS
    None
.NOTES
    PowerShell's built-in "gc" alias for Get-Content takes precedence over a
    same-named function (aliases resolve before functions), so this file
    removes that alias before defining the function - otherwise typing "gc"
    would silently keep invoking Get-Content. Use Get-Content directly (or
    its "cat"/"type" aliases) if you need it.
#>
function gc {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Message
    )
    git commit -m ($Message -join ' ')
}
