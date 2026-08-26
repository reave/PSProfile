Function Update-GoogleDNS {
    <#
    .SYNOPSIS
        Update Google Dynamic DNS
    .DESCRIPTION
        Update Google Dynamic DNS via their API
    .PARAMETER Username
        The Dynamic DNS Update Username
    .PARAMETER Password
        The Dynamic DNS Update Password
    .PARAMETER DomainName
        The domain you are updating DNS for. include the subdomain if you are
        updating a subdomain
    .PARAMETER IPAddress
        The external IP Address to assign to the record
    .EXAMPLE
        PS C:\> Update-GoogleDNS -Username 'user' -Password 'password' -DomainName 'subdomain.example.com' -IPAdress '172.22.22.172'
        Update the DNS for subdomain.example.com to 172.22.22.172
    .NOTES

    #>
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Username,
        [Parameter(Mandatory = $false)]
        [SecureString]$Password,
        [Parameter(Mandatory = $false)]
        [string]$DomainName,
        [Parameter(Mandatory = $false)]
        [string]$IPAddress
    )
    Begin {
        $URI = "https://domains.google.com/nic/update?hostname=$($DomainName)&myip=$($IPAddress)"
        Write-Verbose "API URL Endpoint Updated to: $URI"
    }
    Process {
        Try {
            $Credentials = New-Object System.Management.Automation.PSCredential($Username, $Password)
            Write-Verbose "Created credential object."
            $Result = Invoke-WebRequest -Uri $URI -Credential $Credentials
            Write-Output "Update Complete."
            $Result
        }
        Catch {
            Throw "Failed to update Dynamic DNS Record for $($DomainName)."
        }
    }
}