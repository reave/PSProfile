Function Set-PathVariable {
    param (
        [string]$AddPath,
        [string]$RemovePath,
        [ValidateSet('User', 'Machine', 'Process')]
        [string]$Scope = 'User'
    )

    function Normalize-PathEntry {
        param([string]$p)
        if (-not $p) { return $null }
        $p = $p.Trim()
        $expanded = [Environment]::ExpandEnvironmentVariables($p)
        # remove trailing slashes for consistent comparison
        return $expanded.TrimEnd('\', '/').Trim()
    }

    # Determine target
    $target = if ($Scope -eq 'Process') { 'Process' } else { [System.Enum]::Parse([System.EnvironmentVariableTarget], $Scope) }

    # If modifying Machine scope require elevation
    if ($Scope -eq 'Machine') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Modifying the Machine PATH requires administrative privileges. Re-run PowerShell as Administrator."
        }
    }

    # Read current PATH for the chosen target
    if ($Scope -eq 'Process') {
        $currentPathString = $env:Path
    }
    else {
        $currentPathString = [Environment]::GetEnvironmentVariable('Path', $target)
    }
    if ($null -eq $currentPathString) { $currentPathString = '' }

    $currentEntries = $currentPathString -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    # Build mapping of normalized -> original (preserve original formatting when writing back)
    $map = @{}
    foreach ($e in $currentEntries) {
        $norm = Normalize-PathEntry $e
        if ($norm -and -not $map.ContainsKey($norm)) {
            $map[$norm] = $e
        }
    }

    $changed = $false

    if ($PSBoundParameters.Keys -contains 'RemovePath' -and $RemovePath) {
        $removeNorm = Normalize-PathEntry $RemovePath
        if ($removeNorm) {
            if ($map.ContainsKey($removeNorm)) {
                $map.Remove($removeNorm) | Out-Null
                $changed = $true
            }
            else {
                # Also try matching without expanding variables if user passed literal env var form
                $literalMatches = $currentEntries | Where-Object { $_ -ieq $RemovePath }
                foreach ($lm in $literalMatches) {
                    $ln = Normalize-PathEntry $lm
                    if ($map.ContainsKey($ln)) {
                        $map.Remove($ln) | Out-Null
                        $changed = $true
                    }
                }
            }
        }
    }

    if ($PSBoundParameters.Keys -contains 'AddPath' -and $AddPath) {
        $addNorm = Normalize-PathEntry $AddPath
        if ($addNorm) {
            if (-not $map.ContainsKey($addNorm)) {
                # Add to end using the original AddPath text (preserve env var form if provided)
                $map[$addNorm] = $AddPath.Trim()
                $changed = $true
            }
        }
    }

    if ($changed) {
        # Reconstruct PATH preserving original order as much as possible:
        # Start with original entries order, then append any new entries that weren't present
        $finalList = [System.Collections.Generic.List[string]]::new()
        foreach ($orig in $currentEntries) {
            $n = Normalize-PathEntry $orig
            if ($n -and $map.ContainsKey($n) -and -not $finalList.Contains($map[$n])) {
                $finalList.Add($map[$n])
            }
        }
        # Add any remaining entries from map (these are new)
        foreach ($kvp in $map.GetEnumerator()) {
            if (-not $finalList.Contains($kvp.Value)) { $finalList.Add($kvp.Value) }
        }

        $newPathString = $finalList -join ';'

        if ($Scope -eq 'Process') {
            $env:Path = $newPathString
        }
        else {
            [Environment]::SetEnvironmentVariable('Path', $newPathString, $target)
            # Broadcast WM_SETTINGCHANGE so other processes know environment changed
            $signature = @"
using System;
using System.Runtime.InteropServices;
public static class EnvNotify {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
            Add-Type -TypeDefinition $signature -PassThru | Out-Null
            $HWND_BROADCAST = [IntPtr]0xffff
            $WM_SETTINGCHANGE = 0x1A
            $SMTO_ABORTIFHUNG = 0x0002
            $timeout = 5000
            $ptrResult = [UIntPtr]::Zero
            [EnvNotify]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", $SMTO_ABORTIFHUNG, $timeout, [ref]$ptrResult) | Out-Null
        }

        Write-Output "PATH updated for scope '$Scope'. Added: '$AddPath', Removed: '$RemovePath'."
    }
    else {
        Write-Output "No changes required to PATH for scope '$Scope'."
    }
}