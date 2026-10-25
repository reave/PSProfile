function Get-PathReport {
    <#
    .SYNOPSIS
        Lists PATH entries in order and flags missing and duplicate directories.
    .DESCRIPTION
        Splits PATH on the platform separator (; on Windows, : elsewhere),
        expands %VAR% and ~, and reports each entry with whether the directory
        exists and whether an earlier entry already points at the same place.
        Duplicates compare case-insensitively on Windows and macOS and
        case-sensitively on Linux, ignoring trailing separators.
    .PARAMETER Scope
        Process (default) reads the current session's PATH. User and Machine
        read the persisted values from the registry and are Windows-only.
    .PARAMETER Problems
        Only return entries that are missing, duplicated, or empty.
    .EXAMPLE
        Get-PathReport
    .EXAMPLE
        Get-PathReport -Problems
    .EXAMPLE
        Get-PathReport -Scope Machine | Where-Object Duplicate
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process',

        [switch]$Problems
    )

    if ($Scope -ne 'Process' -and -not ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop')) {
        Write-Error "Scope '$Scope' is only available on Windows; macOS and Linux have no persisted PATH store to read."
        return
    }

    $value = [Environment]::GetEnvironmentVariable('PATH', $Scope)
    if (-not $value) {
        Write-Warning "PATH is empty for scope $Scope."
        return
    }

    $comparer = if ($IsLinux) { [StringComparer]::Ordinal } else { [StringComparer]::OrdinalIgnoreCase }
    $seen = [System.Collections.Generic.Dictionary[string, int]]::new($comparer)
    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $order = 0

    foreach ($entry in $value.Split([IO.Path]::PathSeparator)) {
        $order++
        $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"'))
        if ($expanded -like '~*') {
            $expanded = $HOME + $expanded.Substring(1)
        }

        $empty = [string]::IsNullOrWhiteSpace($expanded)
        $exists = (-not $empty) -and [IO.Directory]::Exists($expanded)

        # Keep a bare root like "/" or "C:\" intact when trimming trailing separators
        $key = $expanded.TrimEnd($separators)
        if (-not $key) { $key = $expanded }

        $duplicateOf = $null
        if (-not $empty) {
            if ($seen.ContainsKey($key)) {
                $duplicateOf = $seen[$key]
            }
            else {
                $seen[$key] = $order
            }
        }

        $item = [PSCustomObject]@{
            Order       = $order
            Path        = $entry
            Expanded    = if ($expanded -ne $entry) { $expanded } else { $null }
            Exists      = $exists
            Duplicate   = $null -ne $duplicateOf
            DuplicateOf = $duplicateOf
            Empty       = $empty
        }

        if (-not $Problems -or $empty -or -not $exists -or $item.Duplicate) {
            $item
        }
    }
}
