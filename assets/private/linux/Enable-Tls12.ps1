<#
.SYNOPSIS
    Enables TLS 1.2 for .NET web requests made via ServicePointManager.
.DESCRIPTION
    Windows PowerShell 5.1 (and older .NET Framework versions) can default to
    TLS 1.0/1.1, which many HTTPS APIs now reject outright. This forces TLS 1.2
    on for the process before any profile function makes a web request
    (Get-Weather, Get-MACVendor's CSV download, Invoke-IPv4PortScan's IANA
    download, etc.). Harmless no-op on PowerShell 7+/.NET, which already
    default to TLS 1.2+.
.EXAMPLE
    Enable-Tls12
.OUTPUTS
    None
#>
function Enable-Tls12 {
    [CmdletBinding()]
    param()

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Write-Verbose "Unable to enable TLS 1.2 explicitly: $_"
    }
}
