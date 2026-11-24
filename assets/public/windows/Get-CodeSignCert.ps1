<#
.SYNOPSIS
    Retrieve code signing certificates from a certificate store.

.DESCRIPTION
    Get-CodeSignCert enumerates certificates in Cert:\<StoreLocation>\<StoreName>
    and returns certificates that include the Code Signing EKU (1.3.6.1.5.5.7.3.3).
    It can filter by subject or thumbprint, require a private key, exclude expired certs,
    and return only the latest-valid certificate.

.EXAMPLE
    Get-CodeSignCert -Subject 'CN=MyCodeSigner' -OnlyWithPrivateKey -Latest

.EXAMPLE
    Get-CodeSignCert -StoreLocation LocalMachine -StoreName My -IncludeExpired

#>
function Get-CodeSignCert {
    [CmdletBinding(DefaultParameterSetName = 'Find')]
    param(
        [Parameter(Position = 0)]
        [string]$Subject,

        [Parameter(Position = 1)]
        [string]$Thumbprint,

        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$StoreLocation = 'CurrentUser',

        [ValidateSet('My', 'TrustedPublisher', 'Root', 'CA')]
        [string]$StoreName = 'My',

        [switch]$IncludeExpired,

        [switch]$OnlyWithPrivateKey,

        [switch]$Latest
    )

    begin {
        # OID for Code Signing EKU
        $codeSigningOid = '1.3.6.1.5.5.7.3.3'
        $storePath = "Cert:\$StoreLocation\$StoreName"
    }

    process {
        try {
            $certs = Get-ChildItem -Path $storePath -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to enumerate certificates in $storePath. $_"
            return
        }

        $allMatches = foreach ($cert in $certs) {
            # Basic filters
            if ($Thumbprint -and ($cert.Thumbprint -ne $Thumbprint)) { continue }
            if ($Subject -and ($cert.Subject -notmatch [regex]::Escape($Subject))) { continue }

            if (-not $IncludeExpired) {
                if ($cert.NotAfter -lt (Get-Date)) { continue }
            }

            if ($OnlyWithPrivateKey -and -not $cert.HasPrivateKey) { continue }

            # Check Enhanced Key Usage for Code Signing OID
            $hasCodeEku = $false
            foreach ($ext in $cert.Extensions) {
                if ($ext.Oid -and $ext.Oid.Value -eq '2.5.29.37') {
                    try {
                        $ekuExt = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]$ext
                        foreach ($usage in $ekuExt.EnhancedKeyUsages) {
                            if ($usage.Value -eq $codeSigningOid) {
                                $hasCodeEku = $true
                                break
                            }
                        }
                    }
                    catch {
                        # ignore parse errors and continue
                    }
                }
                if ($hasCodeEku) { break }
            }

            if (-not $hasCodeEku) { continue }

            [PSCustomObject]@{
                Subject       = $cert.Subject
                Thumbprint    = $cert.Thumbprint
                FriendlyName  = $cert.FriendlyName
                NotBefore     = $cert.NotBefore
                NotAfter      = $cert.NotAfter
                HasPrivateKey = $cert.HasPrivateKey
                StoreLocation = $StoreLocation
                StoreName     = $StoreName
                Certificate   = $cert
            }
        }

        if ($Latest) {
            $latestMatch = $allMatches | Sort-Object NotAfter -Descending | Select-Object -First 1
            $latestMatch
        }
        else {
            $allMatches
        }
    }
}