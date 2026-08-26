Function Get-ADCertificateInformation {
    <#
    .SYNOPSIS
        Get Certificate information for a user in Active Directory
    .PARAMETER Username
        Alias Name, Identity, SamAccountName
        User name(s) or string objects to get data for
    .DESCRIPTION
        Retrieves information about all certificates for a given user or list of users or
        pipeline object of users
    .LINK
        Get-ADUser
        New-Object
        Write-Output
    .EXAMPLE
        Get-ADCertificateInformation.ps1 -Username testert
        Returns certificate information for the given user
    .EXAMPLE
        Get-ADGroupMember -Identity 'Group' | Select -Expand SamAccountName | .\Get-ADCertificateInformation.ps1
        Returns certificate information for all members of the AD Group
    #>

    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $True,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Please enter a user name for us to search for.'
        )
        ]
        [ValidateScript( { Get-ADUser -Identity $_ })]
        [Alias('SamAccountName', 'Identity', 'Name')]
        [string[]]$UserName
    )

    Process {
        Foreach ($userID in $UserName) {
            Write-Verbose "Retrieving Certificates for $userID"
            $user = Get-ADUser -Identity $userID -Properties "Certificates"

            if ($(Get-ADUser -Identity $userID -Properties "Certificates" | Select-Object -ExpandProperty Certificates) -isnot [System.Object]) {
                $properties = @{Identity = $userID
                    IssuedOn             = $null
                    ExpiresOn            = $null
                    RawData              = $null
                    IssuedBy             = $null
                    EnhancedKeyUsageList = $null
                }
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }

            Write-Verbose "Discovered $($user.Certificates.Count) certificates"
            Foreach ($Certificate in $user.Certificates) {
                Try {
                    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Certificate
                    $properties = @{
                        EnhancedKeyUsageList = $cert.EnhancedKeyUsageList
                        Identity             = $userID
                        NotBefore            = $cert.NotBefore
                        NotAfter             = $cert.NotAfter
                        RawData              = $cert.RawData
                        IssuedBy             = $cert.Issuer
                        Thumbprint           = $cert.Thumbprint
                    }
                }
                Catch {
                    $properties = @{
                        EnhancedKeyUsageList = $null
                        Identity             = $userID
                        NotBefore            = $null
                        NotAfter             = $null
                        RawData              = $null
                        IssuedBy             = $null
                        Thumbprint           = $null
                    }
                }
                Finally {
                    $CertObject = New-Object -TypeName psobject -Property $properties
                    if (!($CertObject)) { Write-Output $CertObject }
                    try {
                        $properties = @{
                            Identity             = $userID
                            IssuedOn             = $CertObject.NotBefore
                            ExpiresOn            = $CertObject.NotAfter
                            RawData              = $CertObject.RawData
                            IssuedBy             = $CertObject.IssuedBy
                            EnhancedKeyUsageList = $CertObject.EnhancedKeyUsageList
                            Thumbprint           = $CertObject.Thumbprint
                        }
                    }
                    catch {
                        $properties = @{
                            Identity             = $userID
                            IssuedOn             = $null
                            ExpiresOn            = $null
                            RawData              = $null
                            IssuedBy             = $null
                            EnhancedKeyUsageList = $null
                            Thumbprint           = $null
                        }
                    }
                    finally {
                        $obj = New-Object -TypeName psobject -Property $properties
                        Write-Output $obj
                    }
                }
            }
        }
    }
}