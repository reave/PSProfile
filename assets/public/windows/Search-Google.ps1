function Search-Google {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Query
    )

    begin {
        $uri = 'https://www.google.com/search?q='
    }
    process {
        Write-Verbose "Search query = $($Query)"
        $url = "$($uri)$($Query)"
        Write-Verbose "Complete URL = $($url)"
    }
    end {
        Write-Verbose "Launching default browser and navigating to: $($url)"
        Start-Process "$url"
    }
}
