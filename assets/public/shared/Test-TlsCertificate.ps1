function Test-TlsCertificate {
    <#
    .SYNOPSIS
        Connects to a TLS endpoint and reports its certificate: expiry, SANs, issuer, and chain status.
    .DESCRIPTION
        Opens a TCP connection, performs a TLS handshake with SNI, and captures
        the server certificate and the validation result. The handshake accepts
        any certificate so that expired, self-signed, or mismatched certificates
        can still be inspected; check the Valid and PolicyErrors properties for
        the verdict the OS trust store would have given. Uses .NET SslStream, so
        it works the same on Windows, macOS, and Linux.
    .PARAMETER ComputerName
        Host name, "host:port", or a URL such as https://example.com:8443/path.
        Accepts pipeline input.
    .PARAMETER Port
        TCP port. Default 443. A port in ComputerName takes precedence.
    .PARAMETER ServerName
        SNI and name-validation host, when it differs from ComputerName (for
        example, testing a backend by IP).
    .PARAMETER WarningDays
        Flag certificates expiring within this many days. Default 30.
    .PARAMETER TimeoutMs
        Connect and handshake timeout in milliseconds. Default 5000.
    .EXAMPLE
        Test-TlsCertificate github.com
    .EXAMPLE
        'portal.contoso.com', 'https://api.contoso.com:8443' | Test-TlsCertificate | Where-Object Expiring
    .EXAMPLE
        Test-TlsCertificate 10.0.0.15 -ServerName intranet.contoso.com
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Host', 'Uri', 'Url')]
        [string[]]$ComputerName,

        [ValidateRange(1, 65535)]
        [int]$Port = 443,

        [string]$ServerName,

        [int]$WarningDays = 30,

        [ValidateRange(100, 600000)]
        [int]$TimeoutMs = 5000
    )
    process {
        foreach ($target in $ComputerName) {
            $targetHost = $target
            $targetPort = $Port
            if ($target -match '^[a-z][a-z0-9+.-]*://') {
                $uri = [Uri]$target
                $targetHost = $uri.Host
                if (-not $uri.IsDefaultPort -or $uri.Scheme -eq 'https') { $targetPort = $uri.Port }
            }
            elseif ($target -match '^(?<h>[^:\[\]]+|\[[0-9a-fA-F:]+\]):(?<p>\d+)$') {
                $targetHost = $Matches.h
                $targetPort = [int]$Matches.p
            }
            $targetHost = $targetHost.Trim('[', ']')
            $sni = if ($ServerName) { $ServerName } else { $targetHost }

            # The validation callback runs during AuthenticateAsClient; it records
            # what the platform decided and then accepts so we can inspect the cert.
            $state = @{ Errors = $null; ChainStatus = @() }
            $callback = [System.Net.Security.RemoteCertificateValidationCallback] {
                param($sender, $certificate, $chain, $sslPolicyErrors)
                $state.Errors = $sslPolicyErrors
                if ($chain) {
                    $state.ChainStatus = @($chain.ChainStatus | ForEach-Object { $_.Status.ToString() } | Where-Object { $_ -ne 'NoError' })
                    $state.Chain = @($chain.ChainElements | ForEach-Object { $_.Certificate.Subject })
                }
                return $true
            }

            $client = [System.Net.Sockets.TcpClient]::new()
            $ssl = $null
            try {
                if (-not $client.ConnectAsync($targetHost, $targetPort).Wait($TimeoutMs)) {
                    throw "Timed out connecting to ${targetHost}:$targetPort after $TimeoutMs ms"
                }
                $stream = $client.GetStream()
                $stream.ReadTimeout = $TimeoutMs
                $stream.WriteTimeout = $TimeoutMs
                $ssl = [System.Net.Security.SslStream]::new($stream, $false, $callback)
                $ssl.AuthenticateAsClient($sni)

                $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
                $sanExt = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' }
                # Format() gives "DNS Name=a, DNS Name=b" on Windows and "DNS:a, DNS:b" on OpenSSL platforms
                $sans = if ($sanExt) {
                    @($sanExt.Format($false) -split ',\s*' | ForEach-Object { ($_ -replace '^[^:=]+[:=]\s*', '').Trim() } | Where-Object { $_ })
                }
                else { @() }

                $days = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                [PSCustomObject]@{
                    ComputerName  = $targetHost
                    Port          = $targetPort
                    ServerName    = $sni
                    Subject       = $cert.Subject
                    Issuer        = $cert.Issuer
                    NotBefore     = $cert.NotBefore
                    NotAfter      = $cert.NotAfter
                    DaysRemaining = $days
                    Expiring      = $days -le $WarningDays
                    Valid         = $state.Errors -eq [System.Net.Security.SslPolicyErrors]::None
                    PolicyErrors  = $state.Errors
                    ChainStatus   = $state.ChainStatus
                    Chain         = $state.Chain
                    SANs          = $sans
                    Protocol      = $ssl.SslProtocol
                    KeyAlgorithm  = $cert.PublicKey.Oid.FriendlyName
                    Thumbprint    = $cert.Thumbprint
                    SerialNumber  = $cert.SerialNumber
                }
            }
            catch {
                $inner = $_.Exception
                while ($inner.InnerException) { $inner = $inner.InnerException }
                Write-Error "Test-TlsCertificate ${targetHost}:${targetPort}: $($inner.Message)"
            }
            finally {
                if ($ssl) { $ssl.Dispose() }
                $client.Dispose()
            }
        }
    }
}
