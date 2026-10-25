function ConvertFrom-Jwt {
    <#
    .SYNOPSIS
        Decodes a JWT's header and payload offline and shows when it expires.
    .DESCRIPTION
        Splits a JSON Web Token, base64url-decodes the header and payload, and
        converts the iat/nbf/exp claims to local DateTime values. Nothing is sent
        anywhere. The signature is NOT verified, so use this for inspection only,
        never to decide whether a token is trustworthy.
    .PARAMETER Token
        The JWT. A leading "Bearer " is stripped. Accepts pipeline input.
    .EXAMPLE
        ConvertFrom-Jwt $env:ACCESS_TOKEN
    .EXAMPLE
        Get-Clipboard | ConvertFrom-Jwt | Select-Object -ExpandProperty Payload
    .EXAMPLE
        (az account get-access-token | ConvertFrom-Json).accessToken | ConvertFrom-Jwt
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('AccessToken', 'IdToken')]
        [string]$Token
    )
    begin {
        function ConvertFrom-Base64Url([string]$Value) {
            $s = $Value.Replace('-', '+').Replace('_', '/')
            switch ($s.Length % 4) {
                2 { $s += '==' }
                3 { $s += '=' }
            }
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($s))
        }
        function ConvertFrom-UnixTime($Seconds) {
            if ($null -eq $Seconds) { return $null }
            [DateTimeOffset]::FromUnixTimeSeconds([int64]$Seconds).LocalDateTime
        }
    }
    process {
        $raw = $Token.Trim() -replace '^Bearer\s+', ''
        $parts = $raw.Split('.')
        if ($parts.Count -lt 2) {
            Write-Error 'Not a JWT: expected header.payload.signature.'
            return
        }
        if ($parts.Count -eq 5) {
            Write-Error 'This is an encrypted JWE (5 segments); its payload cannot be read without the key.'
            return
        }

        try {
            $header = ConvertFrom-Base64Url $parts[0] | ConvertFrom-Json
            $payload = ConvertFrom-Base64Url $parts[1] | ConvertFrom-Json
        }
        catch {
            Write-Error "Could not decode JWT: $($_.Exception.Message)"
            return
        }

        $expires = ConvertFrom-UnixTime $payload.exp
        $now = Get-Date
        [PSCustomObject]@{
            Algorithm     = $header.alg
            Issuer        = $payload.iss
            Subject       = $payload.sub
            Audience      = $payload.aud
            IssuedAt      = ConvertFrom-UnixTime $payload.iat
            NotBefore     = ConvertFrom-UnixTime $payload.nbf
            Expires       = $expires
            Expired       = if ($expires) { $expires -lt $now } else { $null }
            TimeRemaining = if ($expires -and $expires -gt $now) { $expires - $now } else { $null }
            Header        = $header
            Payload       = $payload
            Signed        = ($parts.Count -ge 3 -and $parts[2].Length -gt 0)
        }
    }
}
