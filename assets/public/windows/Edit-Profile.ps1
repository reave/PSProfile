Function Edit-Profile {
    <#
    .SYNOPSIS
        Edit the powershell profile of the current powershell user
    .DESCRIPTION
        Edit PowerShell Profile
    .NOTES
        Author: Joseph Ascanio
    #>
    [CmdletBinding()]
    Param()
    Begin {
        Write-Verbose "Profile Path: $PROFILE"
    }
    Process {
        Switch ((Get-Host).Name) {
            'Visual Studio Code Host' { Open-EditorFile "$PROFILE" }
            'Windows PowerShell ISE Host' { psedit "$PROFILE" }
            default {
                if ($IsLinux) {
                    $nano = Get-Command "nano" -ErrorAction SilentlyContinue
                    $vim = Get-Command "vim" -ErrorAction SilentlyContinue
                    $gedit = Get-Command "gedit" -ErrorAction SilentlyContinue

                    if ($gedit) {
                        Start-Process "gedit" -ArgumentList "$PROFILE"
                        return
                    }
                    elseif ($nano) {
                        Start-Process "nano" -ArgumentList "$PROFILE"
                        return
                    }
                    elseif ($vim) {
                        Start-Process "vim" -ArgumentList "$PROFILE"
                        return
                    }
                    else {
                        Write-Error "Could not detect a text editor."
                        return
                    }
                }
                elseif ($IsMacOS) {
                    Start-Process "open" -ArgumentList "$PROFILE"
                    return
                }
                elseif ($IsWindows) {
                    if (Get-Command "notepad" -ErrorAction SilentlyContinue) {
                        Start-Process "notepad" -ArgumentList "$PROFILE"
                        return
                    }
                    else {
                        Write-Error "Could not detect notepad."
                    }
                }
                else {
                    Write-Error "Could not detect host."
                }
            }
        }
    }
}