function sudo {
    <#
    .SYNOPSIS
        Runs a command with administrator or root rights.

    .DESCRIPTION
        On Windows, passes its arguments to Start-Process with -Verb RunAs, which starts the program
        as Administrator after a User Account Control prompt, and waits for it to exit. On macOS and
        Linux, passes its arguments to the system sudo command.

    .EXAMPLE
        sudo -FilePath 'notepad.exe' -ArgumentList 'C:\Windows\System32\drivers\etc\hosts'

        On Windows, opens the hosts file in Notepad as Administrator.

    .EXAMPLE
        sudo apt-get update

        On Linux, runs apt-get update as root.
    #>
    # $IsWindows doesn't exist in Windows PowerShell 5.1; check the edition first.
    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) {
        Start-Process @args -Verb RunAs -Wait
        return
    } else {
        $sudoExe = Get-Command sudo -CommandType Application -ErrorAction Stop
        & $sudoExe.Source @args
    }
}
