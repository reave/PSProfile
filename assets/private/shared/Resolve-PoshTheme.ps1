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

    With -Override and -OverridePath, the theme's top-level settings in
    Override (e.g. shell_integration, async, streaming) are applied to a copy
    of the theme written to OverridePath, and that copy's path is returned.
    The copy is only rewritten when the theme file or the overrides change;
    a sidecar OverridePath.key file records what it was made from. Only JSON
    themes can be overridden; any other format is returned as is.
.PARAMETER PoshTheme
    The PoshTheme setting from profile config: a bare theme name or a full path.
.PARAMETER Override
    The PoshThemeOverrides setting from profile config: an object whose
    properties are oh-my-posh general settings to set on the theme.
.PARAMETER OverridePath
    Where to write the overridden copy of the theme (a .omp.json path).
.EXAMPLE
    Resolve-PoshTheme -PoshTheme 'M365Princess'
.EXAMPLE
    Resolve-PoshTheme -PoshTheme '/opt/homebrew/opt/oh-my-posh/themes/night-owl.omp.json'
.EXAMPLE
    Resolve-PoshTheme -PoshTheme 'M365Princess' -Override ([PSCustomObject]@{ shell_integration = $true }) -OverridePath "$env:TEMP\theme.omp.json"
.OUTPUTS
    System.String, or $null if the theme couldn't be resolved.
#>
function Resolve-PoshTheme {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$PoshTheme,
        [object]$Override,
        [string]$OverridePath
    )

    if ([string]::IsNullOrWhiteSpace($PoshTheme)) { return $null }

    $themePath = $null
    if (Test-Path -Path $PoshTheme -PathType Leaf) {
        $themePath = (Resolve-Path -Path $PoshTheme).Path
    }
    elseif ($env:POSH_THEMES_PATH) {
        $candidate = Join-Path $env:POSH_THEMES_PATH "$PoshTheme.omp.json"
        if (Test-Path -Path $candidate -PathType Leaf) {
            $themePath = $candidate
        }
    }

    if (-not $themePath) {
        Write-Warning "Could not resolve oh-my-posh theme '$PoshTheme' (checked as a direct path, then under `$env:POSH_THEMES_PATH). Falling back to oh-my-posh's default theme. Set `$env:POSH_THEMES_PATH, or put a full path in PoshTheme, to use this theme."
        return $null
    }

    $overrideProperties = @(if ($Override) { $Override.PSObject.Properties })
    if (-not $OverridePath -or $overrideProperties.Count -eq 0) { return $themePath }
    if ($themePath -notmatch '\.json$') {
        Write-Warning "PoshThemeOverrides only apply to JSON themes, so '$themePath' is used as is."
        return $themePath
    }

    $key = (@($themePath, [System.IO.File]::GetLastWriteTimeUtc($themePath).Ticks) +
        @($overrideProperties | ForEach-Object { "$($_.Name)=$($_.Value)" })) -join '|'
    $keyPath = "$OverridePath.key"
    try {
        if ([System.IO.File]::Exists($OverridePath) -and [System.IO.File]::Exists($keyPath) -and
            [System.IO.File]::ReadAllText($keyPath) -eq $key) {
            return $OverridePath
        }
    }
    catch { Write-Verbose "Rebuilding the overridden oh-my-posh theme: $_" }

    $tempPath = "$OverridePath.$PID.tmp"
    try {
        $theme = [System.IO.File]::ReadAllText($themePath) | ConvertFrom-Json -ErrorAction Stop
        foreach ($property in $overrideProperties) {
            $theme | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
        }
        $overrideDir = Split-Path -Path $OverridePath -Parent
        if (-not (Test-Path -Path $overrideDir)) { $null = New-Item -ItemType Directory -Path $overrideDir -Force -ErrorAction Stop }
        # Written to a temporary file and moved into place, so a shell starting at the same
        # moment never reads a half-written theme.
        [System.IO.File]::WriteAllText($tempPath, ($theme | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $OverridePath -Force -ErrorAction Stop
        [System.IO.File]::WriteAllText($keyPath, $key)
        return $OverridePath
    }
    catch {
        Remove-Item -LiteralPath $tempPath -ErrorAction Ignore
        Write-Warning "Could not apply PoshThemeOverrides to '$themePath', so it is used as is: $_"
        return $themePath
    }
}
