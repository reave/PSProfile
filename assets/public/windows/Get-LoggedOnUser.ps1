function Get-LoggedOnUser {
    <#
    .SYNOPSIS
        Retrieve currently logged on users of a device
    .DESCRIPTION
        Retrieve currently logged on users of a specified device
    .PARAMETER ComputerName
        Describes the target computer to retrieve logged on users for
    .EXAMPLE
        PS C:\> Get-LoggedOnUser -ComputerName Test-Computer
        Retrieves logged on users for Test-Computer
    .EXAMPLE
        PS C:\> 'Test-Computer' | Get-LoggedOnUser
        Retrieves logged on users for Test-Computer passed through the pipeline
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$ComputerName = $ENV:COMPUTERNAME
    )
    begin {
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
    }
    process {
        # The queries run here rather than in begin, so a computer name from the pipeline is used.
        $cimSession = $null
        $cimParams = @{ ErrorAction = 'SilentlyContinue' }
        if ($ComputerName -notin $env:COMPUTERNAME, 'localhost', '.') {
            # WSMan first, then DCOM, which is how the earlier Get-WmiObject version connected.
            try { $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop }
            catch {
                $dcomSessionParams = @{
                    ComputerName = $ComputerName
                    SessionOption = (New-CimSessionOption -Protocol Dcom)
                    ErrorAction = 'SilentlyContinue'
                }
                $cimSession = New-CimSession @dcomSessionParams
            }
            if (-not $cimSession) {
                Write-Error -Message "Can't connect to $ComputerName."
                return
            }
            $cimParams.CimSession = $cimSession
        }

        Write-Verbose "Retrieving Logged on Sessions"
        $logon_sessions = Get-CimInstance -ClassName Win32_LogonSession @cimParams

        Write-Verbose "Retrieving Logged on Users"
        $logon_users = Get-CimInstance -ClassName Win32_LoggedOnUser @cimParams
        if ($cimSession) { Remove-CimSession -CimSession $cimSession }

        $session_user = @{ }

        Write-Verbose "Building logon principal name for each discovered user"
        foreach ($logon_user in $logon_users) {
            # CIM returns the account and the session as objects rather than WMI path strings.
            $username = $logon_user.Antecedent.Domain + "\" + $logon_user.Antecedent.Name
            $session_user[$logon_user.Dependent.LogonId] += $username

            Write-Verbose "Finished processing $username"
        }

        Write-Verbose "Processing each session"
        foreach ($session in $logon_sessions) {
            Write-Verbose "Calculating session start time"
            $starttime = $session.StartTime

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
