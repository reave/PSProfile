function Get-QuoteOfTheDay {
    <#
    .SYNOPSIS
        Grab a quote of the day
    .DESCRIPTION
        Grab a quote of the day and display it
    .PARAMETER url
        Defines the API you would like to pull quotes from

        The API must return XML data and must include the following node names:
        rss.channel.item
        Description, Title
    .PARAMETER random
        If passed will use a random quote from those returned rather than the newest one
    .NOTES
        Name: Get-QOTD
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$url = 'http://feeds.feedburner.com/brainyquote/QUOTEBR',
        [Parameter(Mandatory = $false)]
        [switch]$random
    )

    begin {
        Write-Verbose "Creating webclient object"
        $webclient = New-Object System.Net.WebClient
    }

    process {
        Write-Verbose "Connecting to $url"
        try {
            [xml]$data = $webclient.downloadstring($url)

            if ($random) {
                $options = $data.rss.channel.item
                $quote = $options | Get-Random -Count 1
            } else {
                $quote = $data.rss.channel.item[0]
            }

            if ($quote) {
                Write-Verbose $quote.OrigLink
                Write-Output "$($quote.Description) - $($quote.Title)"
            } else {
                Write-Warning "Failed to parse data from $url"
            }
        } catch {
            Write-Error "There was an error connecting to $url"
            throw $_.Exception.Message
        }
    }

    end {
        Write-Verbose "Ending Get-QOTD"
    }
}
