function Edit-Profile {
    <#
    .SYNOPSIS
        Edit the powershell profile of the current powershell user
    .DESCRIPTION
        Edit PowerShell Profile
    .NOTES
        Author: reave (https://github.com/reave)
    #>
    [CmdletBinding()]
    param()
    begin {
        Write-Verbose "Profile Path: $PROFILE"
    }
    process {
        switch ((Get-Host).Name) {
            'Visual Studio Code Host' { Open-EditorFile "$PROFILE" }
            'Windows PowerShell ISE Host' { psedit "$PROFILE" }
            default {
                # $IsWindows, $IsMacOS and $IsLinux don't exist in Windows PowerShell 5.1 and throw under
                # strict mode there, so check the edition first.
                $onWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows
                $onMacOS = $PSVersionTable.PSEdition -ne 'Desktop' -and $IsMacOS
                $onLinux = $PSVersionTable.PSEdition -ne 'Desktop' -and $IsLinux
                if ($onLinux) {
                    $nano = Get-Command "nano" -ErrorAction SilentlyContinue
                    $vim = Get-Command "vim" -ErrorAction SilentlyContinue
                    $gedit = Get-Command "gedit" -ErrorAction SilentlyContinue

                    if ($gedit) {
                        Start-Process "gedit" -ArgumentList "$PROFILE"
                        return
                    } elseif ($nano) {
                        Start-Process "nano" -ArgumentList "$PROFILE"
                        return
                    } elseif ($vim) {
                        Start-Process "vim" -ArgumentList "$PROFILE"
                        return
                    } else {
                        Write-Error "Could not detect a text editor."
                        return
                    }
                } elseif ($onMacOS) {
                    Start-Process "open" -ArgumentList "$PROFILE"
                    return
                } elseif ($onWindows) {
                    if (Get-Command "notepad" -ErrorAction SilentlyContinue) {
                        Start-Process "notepad" -ArgumentList "$PROFILE"
                        return
                    } else {
                        Write-Error "Could not detect notepad."
                    }
                } else {
                    Write-Error "Could not detect host."
                }
            }
        }
    }
}
