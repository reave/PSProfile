function Resolve-ShortURL {
    <#
    .SYNOPSIS
        Follows the redirects of a shortened URL and returns where it ends up.

    .DESCRIPTION
        Requests each URL without following redirects automatically, then follows each Location
        header itself, up to MaxRedirection times. It uses HEAD requests, and switches to GET if a HEAD
        request fails. A URL without a scheme is treated as https. Returns one object per URL with
        InputUrl, FinalUrl, StatusCode, Redirects (the From, To and StatusCode of each hop),
        MaxRedirectionReached and Error.

    .PARAMETER Url
        One or more URLs to resolve. Accepts pipeline input, by value or by property name.

    .PARAMETER MaxRedirection
        The maximum number of redirects to follow. The default is 10.

    .PARAMETER TimeoutSeconds
        How long to wait for each response, in seconds. The default is 30.

    .EXAMPLE
        Resolve-ShortURL -Url 'https://aka.ms/powershell'

        Returns the page the short link points to, with each redirect along the way.

    .EXAMPLE
        'https://aka.ms/powershell', 'https://aka.ms/terminal' | Resolve-ShortURL

        Resolves two short links passed through the pipeline.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
        [string[]]$Url,

        [Parameter()]
        [int]$MaxRedirection = 10,

        [Parameter()]
        [int]$TimeoutSeconds = 30
    )

    begin {
        # HttpClient that does NOT follow redirects so we can observe Location headers
        $handler = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

        # Use a common User-Agent to avoid blocks from some services
        if (-not $client.DefaultRequestHeaders.UserAgent) {
            $client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT) PowerShell/Resolve-ShortURL")
        }
    }

    process {
        foreach ($uriinput in $Url) {
            $resultError = $null
            $redirects = @()
            $statusCode = $null

            # Normalize URL: if scheme missing, assume https
            $raw = $uriinput
            try {
                $uri = [Uri]::new($raw)
                if (-not $uri.Scheme) { throw "no scheme" }
            } catch {
                try {
                    $raw = "https://$raw"
                    $uri = [Uri]::new($raw)
                } catch {
                    $resultError = "Invalid URI"
                }
            }

            if ($null -ne $resultError) {
                [PSCustomObject]@{
                    InputUrl   = $input
                    FinalUrl   = $null
                    StatusCode = $null
                    Redirects  = @()
                    Error      = $resultError
                }
                continue
            }

            $current = $uri.AbsoluteUri
            $method = "Head"
            $maxReached = $false

            for ($i = 0; $i -le $MaxRedirection; $i++) {
                try {
                    $httpMethod = [System.Net.Http.HttpMethod]::new($method)
                    $req = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $current)
                    $resp = $client.SendAsync($req).GetAwaiter().GetResult()
                } catch {
                    # If HEAD fails (some servers don't allow HEAD), retry once with GET
                    if ($method -eq "Head") {
                        $method = "Get"
                        try {
                            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
                            $req = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $current)
                            $resp = $client.SendAsync($req).GetAwaiter().GetResult()
                        } catch {
                            $resultError = $_.Exception.Message
                            break
                        }
                    } else {
                        $resultError = $_.Exception.Message
                        break
                    }
                }

                $statusCode = [int]$resp.StatusCode

                # If there's a Location header, compute absolute URL and continue
                if ($resp.Headers.Location) {
                    $loc = $resp.Headers.Location
                    if (-not $loc.IsAbsoluteUri) {
                        try {
                            $baseUri = [Uri]::new($current)
                            $loc = [Uri]::new($baseUri, $loc)
                        } catch {
                            $resultError = "Failed to resolve relative Location header: $($_.Exception.Message)"
                            break
                        }
                    }
                    $redirects += [PSCustomObject]@{
                        From       = $current
                        To         = $loc.AbsoluteUri
                        StatusCode = $statusCode
                    }

                    $current = $loc.AbsoluteUri
                    continue
                }

                # No Location header -- if status is 3xx, redirection info missing; stop
                if ($statusCode -ge 300 -and $statusCode -lt 400) {
                    $resultError = "Redirect status ($statusCode) with no Location header"
                    break
                }

                # Not a redirect status -> final URL reached
                break
            }

            if ($redirects.Count -gt $MaxRedirection) { $maxReached = $true }

            [PSCustomObject]@{
                InputUrl              = $uriinput
                FinalUrl              = $current
                StatusCode            = $statusCode
                Redirects             = $redirects
                MaxRedirectionReached = $maxReached
                Error                 = $resultError
            }
        }
    }

    end {
        if ($client) { $client.Dispose() }
    }
}
