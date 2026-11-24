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

    $addTypeParams = @{
        MemberDefinition = $signature
        Name = "Win32LockWorkStation"
        Namespace = 'Win32Functions'
        PassThru = $true
    }
    $LockComputer = Add-Type @addTypeParams
    $LockComputer::LockWorkStation() | Out-Null
}
