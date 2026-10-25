Function Get-QuoteOfTheDay {
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
    Param(
        [Parameter(Mandatory = $false)]
        [string]$url = 'http://feeds.feedburner.com/brainyquote/QUOTEBR',
        [Parameter(Mandatory = $false)]
        [switch]$random
    )

    Begin {
        Write-Verbose "Creating webclient object"
        $webclient = New-Object System.Net.WebClient
    }

    Process {
        Write-Verbose "Connecting to $url"
        Try {
            [xml]$data = $webclient.downloadstring($url)

            If ($random) {
                $options = $data.rss.channel.item
                $quote = $options | Get-Random -Count 1
            }
            else {
                $quote = $data.rss.channel.item[0]
            }

            if ($quote) {
                Write-Verbose $quote.OrigLink
                Write-Output "$($quote.Description) - $($quote.Title)"
            }
            else {
                Write-Warning "Failed to parse data from $url"
            }
        }
        Catch {
            Write-Error "There was an error connecting to $url"
            Throw $_.Exception.Message
        }
    }

    End {
        Write-Verbose "Ending Get-QOTD"
    }
}