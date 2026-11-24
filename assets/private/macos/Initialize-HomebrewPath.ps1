<#
.SYNOPSIS
    Puts Homebrew's bin directory on PATH if brew is installed but not resolvable.
.DESCRIPTION
    Homebrew's installer adds its PATH setup to .zprofile/.bash_profile, which a
    PowerShell session never sources - so if pwsh is launched directly (not from
    a zsh/bash login shell that already ran it), `brew` and anything installed
    through it are invisible to the whole session, not just this profile.

    No-op on Windows, and a no-op anywhere brew is already on PATH. Checks the
    standard install locations: /opt/homebrew (Apple Silicon) and /usr/local
    (Intel) on macOS, /home/linuxbrew/.linuxbrew and ~/.linuxbrew on Linux.
.EXAMPLE
    Initialize-HomebrewPath
.OUTPUTS
    None
#>
function Initialize-HomebrewPath {
    [CmdletBinding()]
    param()

    if (Get-Command -Name brew -ErrorAction SilentlyContinue) { return }

    $candidates = if ($IsMacOS) {
        '/opt/homebrew/bin/brew', '/usr/local/bin/brew'
    }
    elseif ($IsLinux) {
        '/home/linuxbrew/.linuxbrew/bin/brew', (Join-Path $HOME '.linuxbrew/bin/brew')
    }
    else {
        @()
    }

    foreach ($brewPath in $candidates) {
        if (Test-Path -Path $brewPath -PathType Leaf) {
            $brewBinDir = Split-Path -Path $brewPath -Parent
            $brewPrefix = Split-Path -Path $brewBinDir -Parent
            $pathSeparator = [IO.Path]::PathSeparator

            if ($env:PATH -notlike "*$brewBinDir*") {
                $env:PATH = "$brewBinDir$pathSeparator$env:PATH"
            }

            $sbinDir = Join-Path $brewPrefix 'sbin'
            if ((Test-Path -Path $sbinDir) -and ($env:PATH -notlike "*$sbinDir*")) {
                $env:PATH = "$sbinDir$pathSeparator$env:PATH"
            }

            $env:HOMEBREW_PREFIX = $brewPrefix
            $env:HOMEBREW_CELLAR = Join-Path $brewPrefix 'Cellar'
            $env:HOMEBREW_REPOSITORY = $brewPrefix
            return
        }
    }
}
