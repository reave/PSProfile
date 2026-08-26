###############################################################################################################
# Language     :  PowerShell 4.0
# Filename     :  Get-MACVendor.ps1
# Autor        :  BornToBeRoot (https://github.com/BornToBeRoot)
# Description  :  Get Vendor from a MAC-Address
# Repository   :  https://github.com/BornToBeRoot/PowerShell
###############################################################################################################

<#
    .SYNOPSIS
    Get Vendor from a MAC-Address

    .DESCRIPTION
    Get Vendor from a MAC-Address, based on the MAC-Address or the first 6 digits

    .EXAMPLE
    Get-MACVendor -MACAddress 5C:49:79:8A:0B:77, 5C-49-79

    MACAddress        Vendor
    ----------        ------
    5C:49:79:8A:0B:77 AVM Audiovisuelles Marketing und Computersysteme GmbH
    5C-49-79          AVM Audiovisuelles Marketing und Computersysteme GmbH

    .LINK
    https://github.com/BornToBeRoot/PowerShell/blob/master/Documentation/Function/Get-MACVendor.README.md
#>

function Get-MACVendor {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = 'MAC-Address or the first 6 digits of it')]
        [ValidateScript({
                if ($_ -match "^(([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){6})|([0-9A-Fa-f]{2}[:-]){2}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){3}$") {
                    return $true
                }
                else {
                    throw "Enter a valid MAC-Address (like 00:00:00:00:00:00 or 00-00-00-00-00-00)!"
                }
            })]
        [String[]]$MACAddress
    )

    Begin {
        # MAC-Vendor list path
        $CSV_MACVendorList_Path = "$($env:PSAssetPath)\IEEE\IEEE-MAC Address Block Large.csv"

        if ([System.IO.File]::Exists($CSV_MACVendorList_Path)) {
            $MAC_VendorList = Import-Csv -Path $CSV_MACVendorList_Path | Select-Object -Property "Assignment", "Organization Name"
        }
        else {
            #- Ask if the user would like to download the file or exit the function
            $choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Download default CSV (recommended) from https://standards.ieee.org/products-programs/regauth/"),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Provide URL"),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Exit")
            )
            $caption = "MAC vendor CSV not found"
            $message = "The IEEE MAC vendor CSV file was not found at $CSV_MACVendorList_Path.`nWhat would you like to do?"
            $result = $Host.UI.PromptForChoice($caption, $message, $choices, 0)

            switch ($result) {
                0 {
                    $downloadUrl = 'http://standards-oui.ieee.org/oui/oui.csv'
                }
                1 {
                    $downloadUrl = Read-Host "Enter the URL to download the CSV from"
                }
                default {
                    throw [System.IO.FileNotFoundException] "No CSV-File to assign vendor with MAC-Address found!"
                }
            }

            try {
                $dir = Split-Path -Parent $CSV_MACVendorList_Path
                if (-not (Test-Path -Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

                Invoke-WebRequest -Uri $downloadUrl -OutFile $CSV_MACVendorList_Path -UseBasicParsing -ErrorAction Stop

                $MAC_VendorList = Import-Csv -Path $CSV_MACVendorList_Path | Select-Object -Property "Assignment", "Organization Name"
            }
            catch {
                throw [System.IO.IOException] "Failed to download or import CSV: $($_.Exception.Message)"
            }
        }
    }

    Process {
        foreach ($MACAddress2 in $MACAddress) {
            $Vendor = [String]::Empty

            # Split it, so we can search the vendor (XX-XX-XX-XX-XX-XX to XX-XX-XX)
            $MAC_VendorSearch = $MACAddress2.Replace("-", "").Replace(":", "").Substring(0, 6)

            foreach ($ListEntry in $MAC_VendorList) {
                if ($ListEntry.Assignment -eq $MAC_VendorSearch) {
                    $Vendor = $ListEntry."Organization Name"

                    [pscustomobject] @{
                        MACAddress = $MACAddress2
                        Vendor     = $Vendor
                    }
                }
            }
        }
    }

    End {

    }
}