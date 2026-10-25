<#
.SYNOPSIS
    Tests whether the current session is an interactive console.
.DESCRIPTION
    Returns $false when the host isn't ConsoleHost, or when standard input/output
    is redirected (e.g. the profile is dot-sourced by a script, a CI runner, or an
    editor's integrated PowerShell extension host). Used to gate behavior that only
    makes sense in a real interactive terminal - PSReadLine configuration, splash
    screens, console title changes, elevated-session banners - so those don't throw
    or print noise in non-interactive contexts.
.EXAMPLE
    if (Test-InteractiveShell) { Write-Host "Hi!" }
.OUTPUTS
    System.Boolean
#>
function Test-InteractiveShell {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        return $Host.Name -eq 'ConsoleHost' -and
        -not [Console]::IsInputRedirected -and
        -not [Console]::IsOutputRedirected
    }
    catch {
        return $false
    }
}
