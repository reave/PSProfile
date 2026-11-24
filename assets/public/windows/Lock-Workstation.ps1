function Lock-Workstation {
    <#
    .SYNOPSIS
        Locks the workstation.

    .DESCRIPTION
        Calls the Windows LockWorkStation function, which shows the lock screen as if you had pressed
        Windows+L.

    .EXAMPLE
        Lock-Workstation

        Locks this computer.

    .NOTES
        Name: Lock-Workstation
        Author: Unknown
    #>
    $signature = @"
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool LockWorkStation();
"@
    $LockWorkStation = Add-Type -MemberDefinition $signature -Name "Win32LockWorkStation" -Namespace Win32Functions -PassThru

    $LockWorkStation::LockWorkStation() | Out-Null
}
