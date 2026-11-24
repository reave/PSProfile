function Get-BatteryStatus {
    <#
    .SYNOPSIS
    Retrieve battery information

    .DESCRIPTION
    Retrieve battery information

    .EXAMPLE
    Get-BatteryStatus

    .NOTES
        http://www.powershellmagazine.com/2012/10/18/pstip-get-system-power-information/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleTypes', '',
        Justification = 'SystemInformation is available on both editions once Add-Type loads System.Windows.Forms.')]
    [CmdletBinding()]
    param()
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SystemInformation]::PowerStatus
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
