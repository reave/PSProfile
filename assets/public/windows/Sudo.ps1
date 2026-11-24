function sudo {
    if ($IsWindows) {
        Start-Process @args -Verb RunAs -Wait
        return
    }
    else {
        $sudoExe = Get-Command sudo -CommandType Application -ErrorAction Stop
        & $sudoExe.Source @args
    }
}