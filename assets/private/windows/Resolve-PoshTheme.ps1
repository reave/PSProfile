<#
.SYNOPSIS
    Resolves a PoshTheme config value to an oh-my-posh theme file path.
.DESCRIPTION
    Accepts either a bare theme name (looked up under $env:POSH_THEMES_PATH)
    or a full path to a .omp.json file. $env:POSH_THEMES_PATH is set
    automatically by oh-my-posh's winget/scoop packages on Windows, but NOT
    by its Homebrew package on macOS/Linux - so a bare theme name won't
    resolve there unless the variable is set some other way. Returns $null
    if neither resolves, so the caller can fall back to oh-my-posh's
    built-in default theme instead of erroring (e.g. on a null Join-Path).
.PARAMETER PoshTheme
    The PoshTheme setting from profile config: a bare theme name or a full path.
.EXAMPLE
    Resolve-PoshTheme -PoshTheme 'M365Princess'
.EXAMPLE
    Resolve-PoshTheme -PoshTheme '/opt/homebrew/opt/oh-my-posh/themes/night-owl.omp.json'
.OUTPUTS
    System.String, or $null if the theme couldn't be resolved.
#>
function Resolve-PoshTheme {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$PoshTheme
    )

    if ([string]::IsNullOrWhiteSpace($PoshTheme)) { return $null }

    if (Test-Path -Path $PoshTheme -PathType Leaf) {
        return (Resolve-Path -Path $PoshTheme).Path
    }

    if ($env:POSH_THEMES_PATH) {
        $candidate = Join-Path $env:POSH_THEMES_PATH "$PoshTheme.omp.json"
        if (Test-Path -Path $candidate -PathType Leaf) {
            return $candidate
        }
    }

    Write-Warning "Could not resolve oh-my-posh theme '$PoshTheme' (checked as a direct path, then under `$env:POSH_THEMES_PATH). Falling back to oh-my-posh's default theme. Set `$env:POSH_THEMES_PATH, or put a full path in PoshTheme, to use this theme."
    return $null
}
