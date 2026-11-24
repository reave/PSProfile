function Get-EncodedFile {
    <#
    .DESCRIPTION
        Encode a file byte by byte into a base64 string and save the output to a file
    .PARAMETER inputFile
        File to encode

        Aliases: FullName, Name
        Accepts Value from Pipeline by property name
    .PARAMETER outFile
        Place to save the output
    .PARAMETER Force
        Overwrites the output file even if it exists
    .NOTES
        Author: reave (https://github.com/reave)
    .EXAMPLE
        Get-EncodedFile -input C:\Tools\tool.ps1 -output C:\output.txt
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName', 'Name')]
        [ValidateScript( { Test-Path $_ })]
        [string]$inputFile,
        [Parameter(Mandatory = $false)]
        [string]$outFile = 'C:\encoded\encoded.txt',
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    begin {
        $outPath = Split-Path -Path $outFile -Parent
        if (!(Test-Path -Path $outPath)) {
            try { New-Item -ItemType Directory -Path $outPath -Force | Out-Null }
            catch { throw "Failed to create directory $($outPath)." }

        } else {
            if (!($Force)) {
                if (Test-Path -Path $outFile) {
                    try { Rename-Item -Path $outFile -NewName "$($outFile).BAK$(Get-Random)" }
                    catch {
                        throw ("Failed to rename existing $($outFile). Choose a different out file or pass the " +
                            "force parameter to overwrite the exising file.")
                    }
                }
            }
        }
    }

    process {
        try {
            $Content = Get-Content -Path "$inputFile" -Encoding Byte
        } catch {
            throw "Failed to encode $($inputFile) into [System.Byte]."
        }

        try {
            $Base64 = [System.Convert]::ToBase64String($Content)
        } catch {
            throw "Failed to convert [System.Byte] data to a Base64 string."
        }

        try {
            if ($Force) {
                $Base64 | Out-File -FilePath $outFile -Force
            } else {
                $Base64 | Out-File -FilePath $outFile
            }
        } catch {
            throw "Failed to write the Base64 string to $($outFile)."
        }
    }
}
