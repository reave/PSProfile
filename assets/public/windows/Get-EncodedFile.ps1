Function Get-EncodedFile {
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
        Author: Joseph Ascanio
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
    Begin {
        $outPath = Split-Path -Path $outFile -Parent
        If (!(Test-Path -Path $outPath)) {
            Try { New-Item -ItemType Directory -Path $outPath -Force | Out-Null }
            Catch { Throw "Failed to create directory $($outPath)." }

        }
        else {
            If (!($Force)) {
                If (Test-Path -Path $outFile) {
                    Try { Rename-Item -Path $outFile -NewName "$($outFile).BAK$(Get-Random)" }
                    Catch { Throw "Failed to rename existing $($outFile). Choose a different out file or pass the force parameter to overwrite the exising file." }
                }
            }
        }
    }

    Process {
        Try {
            $Content = Get-Content -Path "$inputFile" -Encoding Byte
        }
        Catch {
            Throw "Failed to encode $($inputFile) into [System.Byte]."
        }

        Try {
            $Base64 = [System.Convert]::ToBase64String($Content)
        }
        Catch {
            Throw "Failed to convert [System.Byte] data to a Base64 string."
        }

        Try {
            If ($Force) {
                $Base64 | Out-File -FilePath $outFile -Force
            }
            else {
                $Base64 | Out-File -FilePath $outFile
            }
        }
        Catch {
            Throw "Failed to write the Base64 string to $($outFile)."
        }
    }
}