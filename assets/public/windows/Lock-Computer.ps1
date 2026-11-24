function Lock-Computer {
    <#
        .DESCRIPTION
        Function to Lock your computer
        .SYNOPSIS
        Function to Lock your computer
    #>

    $signature = @"
[DllImport("user32.dll", SetLastError = true)]
public static extern bool LockWorkStation();
"@

    $LockComputer = Add-Type -MemberDefinition $signature -Name "Win32LockWorkStation" -Namespace Win32Functions -PassThru
    $LockComputer::LockWorkStation() | Out-Null
}
