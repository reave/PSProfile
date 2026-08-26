Function Get-RandomString {
    <#
    .SYNOPSIS
    Generate a random string of alphanumeric characters
    .DESCRIPTION
    Generate a random string of alphanumeric characters of an arbitrary length
    .PARAMETER Length
    Determines the length of the string returned
    .NOTES
    .LINK
    http://stackingcode.com/blog/2011/10/27/quick-random-string
    .EXAMPLE
    Get-RandomString -Length 16

    .EXAMPLE
    Get-RandomString
    #>
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )
        ]
        [int]$Length = 8
    )
    $set = "0123456789".ToCharArray()
    $result = ""
    for ($x = 0; $x -lt $Length; $x++) {
        $result += $set | Get-Random
    }
    Write-Output $result
}