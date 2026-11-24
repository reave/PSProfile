function Update-GoogleDNS {
    <#
    .SYNOPSIS
        Update Google Dynamic DNS
    .DESCRIPTION
        Update Google Dynamic DNS via their API
    .PARAMETER Credential
        The Dynamic DNS update username and password
    .PARAMETER DomainName
        The domain you are updating DNS for. include the subdomain if you are
        updating a subdomain
    .PARAMETER IPAddress
        The external IP Address to assign to the record
    .EXAMPLE
        PS C:\> Update-GoogleDNS -Credential (Get-Credential) -DomainName 'subdomain.example.com' -IPAddress '172.22.22.172'
        Update the DNS for subdomain.example.com to 172.22.22.172
    .NOTES

    #>
    [CmdLetBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory = $false)]
        [string]$DomainName,
        [Parameter(Mandatory = $false)]
        [string]$IPAddress
    )
    begin {
        $URI = "https://domains.google.com/nic/update?hostname=$($DomainName)&myip=$($IPAddress)"
        Write-Verbose "API URL Endpoint Updated to: $URI"
    }
    process {
        if (-not $PSCmdlet.ShouldProcess($DomainName, "Update Dynamic DNS record to $IPAddress")) { return }
        try {
            $Result = Invoke-WebRequest -Uri $URI -Credential $Credential
            Write-Output "Update Complete."
            $Result
        } catch {
            throw "Failed to update Dynamic DNS Record for $($DomainName)."
        }
    }
}
