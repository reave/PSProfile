<#
.SYNOPSIS
    Regenerates cached native PowerShell completions for the tools listed in
    config.json's NativeCompletions.
.DESCRIPTION
    For each NativeCompletions entry whose Name resolves via Get-Command, runs its
    GenerateCommand (e.g. `docker completion powershell`) and writes the output to
    assets\private\<os>\completions\native\<Name>.ps1, then immediately dot-sources
    it into the current session. completions.ps1 dot-sources these same cached files
    on every future profile load, so this is the only place that actually shells out
    to each tool - a normal shell start never pays that cost. Entries whose tool isn't
    installed are skipped, not errored on.

    Called automatically by Update-Profile after it reloads the profile. Safe to run
    directly any time - e.g. right after installing a new CLI - to pick it up without
    a full profile update.
.EXAMPLE
    Update-Completions
.OUTPUTS
    None
#>
function Update-Completions {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $Global:PSProfileRoot) {
        Write-Error 'Could not determine the PSProfile install directory ($Global:PSProfileRoot is unset).'
        return
    }

    $config = Get-PSProfileConfig
    if (-not $config.NativeCompletions) {
        Write-Verbose 'No NativeCompletions configured in config.json - nothing to do.'
        return
    }

    $osFolder = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
    $nativeDir = Join-Path $Global:PSProfileRoot "assets\private\$osFolder\completions\native"
    if (-not (Test-Path -Path $nativeDir)) {
        New-Item -ItemType Directory -Path $nativeDir -Force | Out-Null
    }

    foreach ($nc in $config.NativeCompletions) {
        if (-not (Get-Command -Name $nc.Name -ErrorAction SilentlyContinue)) {
            Write-Verbose "Skipping $($nc.Name): not installed."
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($nc.Name, 'Regenerate cached PowerShell completion')) { continue }

        try {
            $script = Invoke-Expression $nc.GenerateCommand | Out-String
            if (-not $script.Trim()) { throw 'generator produced no output' }

            $outPath = Join-Path $nativeDir "$($nc.Name).ps1"
            Set-Content -Path $outPath -Value $script -Force -Encoding utf8
            . $outPath
            Write-Host "Updated completion: $($nc.Name)" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to generate completion for $($nc.Name): $_"
        }
    }
}
