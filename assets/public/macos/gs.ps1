Remove-Item -Path "alias:\gs" -Force -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Shows git status for the current repository.
.DESCRIPTION
    Shorthand for `git status`.
.EXAMPLE
    gs
.OUTPUTS
    None
#>
function gs {
    [CmdletBinding()]
    param()
    git status
}
