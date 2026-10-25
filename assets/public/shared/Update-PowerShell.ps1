<#
.SYNOPSIS
    Upgrades PowerShell 7 to the newest patch of the target LTS line (7.6 by default).
.DESCRIPTION
    Finds the newest stable release in the -TargetVersion line on GitHub, compares it with the
    installed PowerShell 7, and upgrades with the package manager that owns the install:
      Windows: winget (Microsoft.PowerShell, pinned to the exact target version)
      macOS:   brew upgrade powershell, or the signed .pkg when brew doesn't manage pwsh
      Linux:   apt-get or dnf/yum, for the packages.microsoft.com "powershell" package

    Run from Windows PowerShell 5.1 it checks the pwsh on PATH, not the running shell, and
    installs PowerShell 7 if there's none.

    brew, apt and dnf install whatever their repo calls latest stable. That's the 7.6 line
    until 7.7 ships; after that they move past -TargetVersion, and only winget stays pinned.
.PARAMETER TargetVersion
    The major.minor release line to track. Default: 7.6, the current LTS (supported until
    November 2028).
.PARAMETER CheckOnly
    Report the installed and target versions without upgrading.
.EXAMPLE
    Update-PowerShell
.EXAMPLE
    Update-PowerShell -CheckOnly
.EXAMPLE
    Update-PowerShell -WhatIf
.OUTPUTS
    None
#>
function Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidatePattern('^\d+\.\d+$')]
        [string]$TargetVersion = '7.6',

        [switch]$CheckOnly
    )

    $onWindows = $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'

    try {
        $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=100' -ErrorAction Stop
    }
    catch {
        Write-Error "Could not read PowerShell releases from GitHub: $_"
        return
    }
    $linePattern = '^v' + [regex]::Escape($TargetVersion) + '\.\d+$'
    $latest = $releases | Where-Object { -not $_.prerelease -and -not $_.draft -and $_.tag_name -match $linePattern } |
        ForEach-Object { [version]($_.tag_name.TrimStart('v')) } |
        Sort-Object -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Error "No stable PowerShell $TargetVersion release found on GitHub."
        return
    }

    # The running shell is the install to check on 7.x; on 5.1 it's whatever pwsh is on PATH.
    # Prerelease labels (7.7.0-preview.1) are dropped so the comparison is a plain [version].
    $current = $null
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $current = [version](("$($PSVersionTable.PSVersion)" -split '-')[0])
    }
    elseif ($pwsh = Get-Command -Name pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1) {
        $reported = & $pwsh.Source -NoProfile -NoLogo -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
        if ($reported) { $current = [version]((("$reported").Trim() -split '-')[0]) }
    }

    $currentText = if ($current) { "PowerShell $current" } else { 'PowerShell 7 (not installed)' }
    if ($current -and $current -ge $latest) {
        Write-Host "$currentText is up to date (newest $TargetVersion release: $latest)." -ForegroundColor Green
        return
    }
    if ($CheckOnly) {
        Write-Host "$currentText can be updated to $latest." -ForegroundColor Yellow
        return
    }
    if (-not $PSCmdlet.ShouldProcess($currentText, "Install PowerShell $latest")) { return }

    $isRoot = $onWindows -or $(try { (id -u) -eq '0' } catch { $false })
    $sudo = if ($isRoot) { @() } else { @('sudo') }

    function Invoke-Upgrade([string[]]$Command) {
        $exe, $rest = $Command
        & $exe @rest
        if ($LASTEXITCODE -ne 0) { throw "'$($Command -join ' ')' exited with code $LASTEXITCODE" }
    }

    try {
        if ($onWindows) {
            if (-not (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
                Write-Warning 'winget is required to update PowerShell automatically.'
                return
            }
            $verb = if ($current) { 'upgrade' } else { 'install' }
            Invoke-Upgrade @('winget', $verb, '--id', 'Microsoft.PowerShell', '--exact', '--version', "$latest", '--accept-source-agreements', '--accept-package-agreements')
        }
        elseif ($IsMacOS) {
            $brew = Get-Command -Name brew -ErrorAction SilentlyContinue
            if ($brew -and (& $brew.Source list --versions powershell 2>$null)) {
                Invoke-Upgrade @('brew', 'update')
                Invoke-Upgrade @('brew', 'upgrade', 'powershell')
            }
            else {
                $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }
                $pkg = Join-Path ([System.IO.Path]::GetTempPath()) "powershell-$latest-osx-$arch.pkg"
                Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$latest/powershell-$latest-osx-$arch.pkg" -OutFile $pkg -ErrorAction Stop
                Invoke-Upgrade ($sudo + @('installer', '-pkg', $pkg, '-target', '/'))
                Remove-Item -Path $pkg -Force -ErrorAction SilentlyContinue
            }
        }
        elseif ((Get-Command -Name dpkg -ErrorAction SilentlyContinue) -and (& dpkg -s powershell 2>$null)) {
            Invoke-Upgrade ($sudo + @('apt-get', 'update'))
            Invoke-Upgrade ($sudo + @('apt-get', 'install', '-y', '--only-upgrade', 'powershell'))
        }
        elseif ((Get-Command -Name rpm -ErrorAction SilentlyContinue) -and (& rpm -q powershell 2>$null)) {
            $manager = if (Get-Command -Name dnf -ErrorAction SilentlyContinue) { 'dnf' } else { 'yum' }
            Invoke-Upgrade ($sudo + @($manager, 'upgrade', '-y', 'powershell'))
        }
        else {
            Write-Warning "PowerShell wasn't installed from a package this function knows how to upgrade. See https://aka.ms/powershell-release?tag=lts for $latest."
            return
        }
        Write-Host "PowerShell $latest is installed. Restart your shell to use it." -ForegroundColor Magenta
    }
    catch {
        Write-Error "Failed to update PowerShell: $_"
    }
}
