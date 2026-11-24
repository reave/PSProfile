function sudo {
    # $IsWindows doesn't exist in Windows PowerShell 5.1; check the edition first.
    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) {
        Start-Process @args -Verb RunAs -Wait
        return
    } else {
        $sudoExe = Get-Command sudo -CommandType Application -ErrorAction Stop
        & $sudoExe.Source @args
    }
}
