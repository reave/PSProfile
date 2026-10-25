function Search-Google {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Query
    )

    Begin {
        $uri = 'https://www.google.com/search?q='
    }
    Process {
        Write-Verbose "Search query = $($Query)"
        $url = "$($uri)$($Query)"
        Write-Verbose "Complete URL = $($url)"
    }
    End {
        Write-Verbose "Launching default browser and navigating to: $($url)"
        Start-Process "$url"
    }
}