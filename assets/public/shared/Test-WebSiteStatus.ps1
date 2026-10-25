Function Test-WebSiteStatus {
    <#
    .SYNOPSIS
        Perform a web request
    .DESCRIPTION
        Perform a web request and return the HTTP_Status Code
    .PARAMETER URI
        URL to get a status code for
    .NOTES
        Name: Test-WebSiteStatus
        Author: Joseph Ascaino
        DateCreated: 07/21/2015
    .EXAMPLE
        Test-WebSiteStatus -URI "http://www.google.com"
        Tests the status of the site for www.google.com
    #>
    #Requires -Version 2
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$URI
    )
    Begin {
        Write-Verbose "Building the Web Request"
        $HTTP_Request = [System.Net.WebRequest]::Create($URI)
        $HTTP_Request.UseDefaultCredentials = $true
    }
    Process {
        Write-Verbose "Intiating web request"
        Try {
            $HTTP_Response = $HTTP_Request.GetResponse()
            $HTTP_Status = $HTTP_Response
        }
        Catch [System.Net.WebException] {
            # Crap we got a code other than 200 and PowerShell 2.0
            # doesn't know what he heck to do with it... so we throw
            # an exception with the code in it ><
            $props = @{
                StatusCode = [int]$_.Exception.Response.StatusCode
            }
            $HTTP_Status = New-Object -TypeName PsObject -Property $props
        }

        If ($HTTP_Response) { $HTTP_Response.Close() }

        Write-Output $HTTP_Status
    }
}