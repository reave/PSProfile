Remove-Item -Path "alias:\ga" -Force -ErrorAction Ignore

<#
.SYNOPSIS
    Stages all changes in the current git repository.
.DESCRIPTION
    Shorthand for `git add .`.
.EXAMPLE
    ga
.OUTPUTS
    None
#>
function ga {
    [CmdletBinding()]
    param()
    git add .
}
