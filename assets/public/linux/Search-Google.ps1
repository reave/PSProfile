function Search-Google {
    <#
    .SYNOPSIS
        Opens a Google search in the default browser.

    .DESCRIPTION
        Appends Query to https://www.google.com/search?q= and opens the result in the default
        browser. The query isn't URL-encoded, so characters such as & and # change what's searched
        for.

    .PARAMETER Query
        The text to search for.

    .EXAMPLE
        Search-Google -Query 'PowerShell comment-based help'

        Opens the Google results for the query.
    #>
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
