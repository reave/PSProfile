Function Get-LoggedOnUsers {
    <#
    .SYNOPSIS
        Retrieve currently logged on users of a device
    .DESCRIPTION
        Retrieve currently logged on users of a specified device
    .PARAMETER ComputerName
        Describes the target computer to retrieve logged on users for
    .EXAMPLE
        PS C:\> Get-LoggedOnUsers -ComputerName Test-Computer
        Retrieves logged on users for Test-Computer
    .EXAMPLE
        PS C:\> 'Test-Computer' | Get-LoggedOnUsers
        Retrieves logged on users for Test-Computer passed through the pipeline
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$ComputerName = $ENV:COMPUTERNAME
    )
    Begin {
        Write-Verbose "Building Regex for user identification"
        $regexa = '.+Domain="(.+)",Name="(.+)"$'
        $regexd = '.+LogonId="(\d+)"$'

        Write-Verbose "Configuring Logon Type HashTable"
        $logontype = @{
            "0"  = "Local System"      # (Local System Accounts)
            "2"  = "Interactive"       # (Local logon)
            "3"  = "Network"           # (Remote logon)
            "4"  = "Batch"             # (Scheduled task)
            "5"  = "Service"           # (Service account logon)
            "7"  = "Unlock"            # (Screen saver)
            "8"  = "NetworkCleartext"  # (Cleartext network logon)
            "9"  = "NewCredentials"    # (RunAs using alternate credentials)
            "10" = "RemoteInteractive" # (RDP\TS\RemoteAssistance)
            "11" = "CachedInteractive" # (Local w\cached credentials)
        }

        Write-Verbose "Retrieving Logged on Sessions"
        $logon_sessions = Get-WMIObject -Class Win32_logonsession -ComputerName $computername -ErrorAction SilentlyContinue

        Write-Verbose "Retrieving Logged on Users"
        $logon_users = Get-WMIObject -Class Win32_loggedonuser -ComputerName $computername -ErrorAction SilentlyContinue
    }
    Process {
        $session_user = @{ }

        Write-Verbose "Building logon principal name for each discovered user"
        Foreach ($logon_user in $logon_users) {
            $logon_user.antecedent -match $regexa > $nul
            $username = $matches[1] + "\" + $matches[2]
            $logon_user.dependent -match $regexd > $nul
            $session = $matches[1]
            $session_user[$session] += $username

            Write-Verbose "Finished processing $username"
        }

        Write-Verbose "Processing each session"
        Foreach ($session in $logon_sessions) {
            Write-Verbose "Calculating session start time"
            $starttime = [management.managementdatetimeconverter]::todatetime($session.starttime)

            Write-Verbose "Creating session object"
            $Props = @{
                "ComputerName" = $ComputerName
                "Session"      = $session.logonid
                "User"         = $session_user[$session.logonid]
                "Type"         = $logontype[$session.logontype.tostring()]
                "Auth"         = $session.authenticationpackage
                "StartTime"    = $starttime
            }

            $loggedonuser = New-Object -TypeName psobject -Property $Props

            Write-Output $loggedonuser
        }
    }
}