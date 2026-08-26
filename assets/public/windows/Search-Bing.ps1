Function Search-Bing {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$ApiKey = '',
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "A single query, list of queries, or object containing queries.")]
        [ValidateNotNull()]
        [Alias('Filter', 'Search', 'String', 'SearchString')]
        [string]$Query
    )
    Begin {
        Try {
            Write-Verbose "Converting API key to Base64"
            $Base64KeyBytes = [byte[]] [Text.Encoding]::ASCII.GetBytes("ignored:$ApiKey")
            $Base64Key = [Convert]::ToBase64String($Base64KeyBytes)
        } Catch {
            Throw "Failed to convert ApiKey to Base64."
        }

        Try {
            Write-Verbose "Initializing .Net System.Web Assembly"
            Add-Type -Assembly System.Web
        } Catch {
            Throw "Failed to initialize System.Web assembly."
        }

        $serviceBaseURI = 'https://api.datamarket.azure.com/Bing/Search/Web?$format=json&Query='
        Write-Verbose "Service Base URL is: $($serviceBaseURI)"
    }
    Process {
        Try {
            Write-Verbose "Formatting Query for Service."
            $FormattedQuery = '%27' + ([Web.HttpUtility]::UrlEncode($Query)) + '%27'
            Write-Verbose "Formatted Query: $($FormattedQuery)"
        } Catch {
            Throw "Failed to format Query to meet Bing API requirements"
        }

        $Uri = $serviceBaseURI + $FormattedQuery
        Write-Verbose "Full Service URL: $($Uri)"

        Try {
            Write-Verbose "Submitting Web Request"
            $Results = Invoke-RestMethod -Uri $Uri -Headers @{ Authorization = "Basic $Base64Key" } -ErrorAction Stop
            $Results.d.results | ForEach-Object {
                $Properties = @{Title = $_.Title
                    Description       = $_.Description
                    DisplayURL        = $_.DisplayUrl
                    FullURL           = $_.Url
                }
                $obj = New-Object -TypeName psobject -Property $Properties
                Write-Output $obj
            }
        } Catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Error $ErrorMessage
            Write-Error $FailedItem
            Break
        }
    }
}