Function Send-MagicPacket {
    <#PSScriptInfo

    .VERSION 1.0.3

    .GUID cc0177f1-70ca-466f-81e5-ec2a37e67157

    .AUTHOR saw-friendship

    .COMPANYNAME

    .COPYRIGHT saw-friendship

    .TAGS Windows Network WOL Wake-on-Lan Magic Packet

    .LICENSEURI

    .PROJECTURI

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES


    #>

    <#

    .DESCRIPTION
    Send MagicPacket to NIC WOL supported

    .LINK
    https://sawfriendship.wordpress.com/

    .EXAMPLE
    Send-MagicPacket 00155df63102

    .EXAMPLE
    Get-DhcpServerv4Reservation -ScopeId 192.168.1.0 | Send-MagicPacket


    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Alias("LinkLayerAddress", "PhysicalAddress", "ClientId")][string[]]$MacAddress,
        [IPAddress]$Broadcast = [System.Net.IPAddress]::Broadcast,
        [int32[]]$Ports = @(7..9)
    )

    Process {
        foreach ($Mac in $MacAddress) {

            [string]$Mac = $Mac.ToUpper() -replace "[g-z]|[^\w\d]"
            if ($Mac.Length -ne 12) {
                Write-Error -Message 'Invalid PhysicalAddress format'
                break
            }
            [string[]]$SplitMac = $Mac -split '([\w\d]{2})' -match '[\w\d]'
            [byte[]]$packet = @( [byte] [convert]::ToInt32('FF', 16) ) * 6
            $packet += @( $SplitMac | ForEach-Object { [byte] [convert]::ToInt32($_, 16) } ) * 16

            $UdpClient = New-Object System.Net.Sockets.UdpClient

            $Ports | Foreach-Object {
                $UdpClient.Connect($broadcast, $_)
                $UdpClient.Send($packet, $packet.Length) | out-null
            }

            $UdpClient.Close()

            [pscustomobject][ordered]@{
                'Mac'  = $Mac
                'Port' = $Ports
            }
        }
    }
}