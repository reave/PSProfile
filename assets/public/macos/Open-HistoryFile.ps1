function Open-HistoryFile {
    <#
    .SYNOPSIS
        Opens the PowerShell history file.
    .DESCRIPTION
        Opens the (Get-PSReadLineOption).HistorySavePath file conditionally in one
        of the following programs:
        1. PowerShell ISE, if detected as the current host.
        2. VSCode, if detected as the current host.
        3. gedit, nano or VIM if Linux
        4. open, if MacOS
        5. Notepad, if Windows
        6. Write-Error, if none of the above are detected.
    .EXAMPLE
        Open-HistoryFile
    #>

    $HISTORY_PATH = (Get-PSReadLineOption).HistorySavePath

    switch ((Get-Host).Name) {
        'Visual Studio Code Host' { Open-EditorFile "$HISTORY_PATH" }
        'Windows PowerShell ISE Host' { psedit "$HISTORY_PATH" }
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
                    Start-Process "gedit" -ArgumentList "$HISTORY_PATH"
                    return
                } elseif ($nano) {
                    Start-Process "nano" -ArgumentList "$HISTORY_PATH"
                    return
                } elseif ($vim) {
                    Start-Process "vim" -ArgumentList "$HISTORY_PATH"
                    return
                } else {
                    Write-Error "Could not detect a text editor."
                    return
                }
            } elseif ($onMacOS) {
                Start-Process "open" -ArgumentList "$HISTORY_PATH"
                return
            } elseif ($onWindows) {
                if (Get-Command "notepad" -ErrorAction SilentlyContinue) {
                    Start-Process "notepad" -ArgumentList "$HISTORY_PATH"
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
