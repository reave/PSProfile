function Get-Time {
    <#
    .SYNOPSIS
        Convert time into another format
    .DESCRIPTION
        Converts time from Powershell standard Get-Date into one of the following:
        Short Time, Long Time, Universal Time, File Time, OLEAutomation time
    .PARAMETER Format
        Validated set including: 'Short','Long','Universal','File','OLEAutomation'

        Determines what format we output. Derfault is long time
    .NOTES
    #>
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Short', 'Long', 'Universal', 'File', 'OLEAutomation')]
        [string]$Format = 'Long'
    )

    Process {

        Write-Verbose "Current Date and Time: $(Get-Date)"

        Switch ($Format) {
            'Short' {
                Write-Verbose "Converting to Short Time"
                $Outstring = $(Get-Date | ForEach-Object { $_.ToShortTimeString() } )
            }
            'Long' {
                Write-Verbose "Converting to Long Time"
                $Outstring = $(Get-Date | ForEach-Object { $_.ToLongTimeString() } )
            }
            'Universal' {
                Write-Verbose "Converting to Universal Time"
                $Outstring = $(Get-Date | ForEach-Object { $_.ToUniversalTime() } )
            }
            'File' {
                Write-Verbose "Converting to File Time"
                $Outstring = $(Get-Date | ForEach-Object { $_.ToFileTime() } )
            }
            'OLEAutomation' {
                Write-Verbose "Converting to OLEAutomation Time"
                $Outstring = $(Get-Date | ForEach-Object { $_.ToOADate() } )
            }
        }

        Write-Output $Outstring
    }
}