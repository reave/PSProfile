<#
.SYNOPSIS
    Regenerates cached native PowerShell completions for the tools listed in
    config.json's NativeCompletions, and refreshes carapace's tool list.
.DESCRIPTION
    For each NativeCompletions entry whose Name resolves via Get-Command, runs its
    GenerateCommand (e.g. `docker completion powershell`) and writes the output to
    assets/private/<os>/completions/native/<Name>.ps1, then immediately dot-sources
    it into the current session. completions.ps1 lazy-loads these same cached files
    on every future profile load, so this is the only place that actually shells out
    to each tool - a normal shell start never pays that cost. Entries whose tool isn't
    installed are skipped, not errored on.

    When carapace (https://carapace.sh) is installed and config.json doesn't set
    "Carapace": false, also writes the tools carapace has completers for to
    carapace.names.txt, and the ones of those installed on this machine to
    carapace.installed.txt, in the same folder. PowerShell 7.6+ uses the first list;
    5.1 and 7.4/7.5 register a completer at startup for each tool in the second, so
    run this again after installing a CLI there.

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
    $carapace = $null
    if ($config.Carapace -ne $false) {
        $carapace = Get-Command -Name carapace -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $config.NativeCompletions -and -not $carapace) {
        Write-Verbose 'No NativeCompletions configured in config.json and carapace is not installed - nothing to do.'
        return
    }

    $osFolder = if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
    $nativeDir = [IO.Path]::Combine($Global:PSProfileRoot, 'assets', 'private', $osFolder, 'completions', 'native')
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

    if ($carapace -and $PSCmdlet.ShouldProcess('carapace', 'Refresh the list of tools carapace completes')) {
        try {
            # Get-PSProfileCarapaceName lives with the rest of the completion code, which a
            # session only loads on its first Tab.
            if (-not (Get-Command -Name Get-PSProfileCarapaceName -ErrorAction SilentlyContinue)) {
                . ([IO.Path]::Combine($Global:PSProfileRoot, 'assets', 'lib', 'PSProfile.Completion.ps1'))
            }
            $names = @(Get-PSProfileCarapaceName -Path $carapace.Source | Where-Object { $_ } | Sort-Object -Unique)
            if ($names.Count -eq 0) { throw 'carapace listed no completers' }

            # Tools in the list that are on PATH here, by name without extension (git.exe -> git).
            # One directory listing per PATH entry is far quicker than Get-Command per name.
            $isWindowsHost = $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'
            $pathExt = @(($env:PATHEXT -split ';') | Where-Object { $_ })
            $onPath = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            foreach ($dir in ($env:PATH -split [IO.Path]::PathSeparator) | Where-Object { $_ } | Sort-Object -Unique) {
                foreach ($file in Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue) {
                    if ($isWindowsHost) {
                        if ($pathExt -contains $file.Extension) { [void]$onPath.Add($file.BaseName) }
                    }
                    else { [void]$onPath.Add($file.Name) }
                }
            }
            $installed = @($names | Where-Object { $onPath.Contains($_) })

            Set-Content -Path (Join-Path $nativeDir 'carapace.names.txt') -Value $names -Force -Encoding ascii
            Set-Content -Path (Join-Path $nativeDir 'carapace.installed.txt') -Value $installed -Force -Encoding ascii
            Write-Host "Updated carapace completions: $($installed.Count) installed tools of $($names.Count)" -ForegroundColor Green

            # Before 7.6 the dispatcher only hears about tools registered by name at startup;
            # register the installed list now so this session needn't restart.
            if ($PSVersionTable.PSVersion -lt [version]'7.6' -and $installed.Count -gt 0 -and
                (Get-Command -Name Invoke-PSProfileNativeCompleter -ErrorAction SilentlyContinue)) {
                Register-ArgumentCompleter -Native -CommandName $installed -ScriptBlock {
                    param($wordToComplete, $commandAst, $cursorPosition)
                    Invoke-PSProfileNativeCompleter -WordToComplete $wordToComplete -CommandAst $commandAst -CursorPosition $cursorPosition
                }
            }
        }
        catch {
            Write-Error "Failed to refresh carapace's tool list: $_"
        }
    }

    # Let the running session's completion dispatcher pick up new or changed files.
    $Global:PSProfileLazyCompleterFiles = $null
    $Global:PSProfileCarapace = $null
}
