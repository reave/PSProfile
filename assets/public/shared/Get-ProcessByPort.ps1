function Get-ProcessByPort {
    <#
    .SYNOPSIS
        Shows which process owns a local TCP or UDP port.
    .DESCRIPTION
        Finds sockets bound to the given local port(s) and resolves the owning
        process. By default only listening TCP sockets and bound UDP sockets are
        returned; use -All to include established and other TCP states.
        Windows uses Get-NetTCPConnection/Get-NetUDPEndpoint, Linux uses ss
        (falling back to lsof), and macOS uses lsof. Without elevation, Linux
        and macOS only reveal the process for sockets you own; ProcessId is
        empty for the rest, so rerun with sudo to see them.
    .PARAMETER Port
        One or more local port numbers. Omit to list every matching socket.
    .PARAMETER Protocol
        TCP, UDP, or Both (default).
    .PARAMETER All
        Include TCP sockets in every state, not only LISTEN.
    .EXAMPLE
        Get-ProcessByPort 8080
    .EXAMPLE
        Get-ProcessByPort 53 -Protocol UDP
    .EXAMPLE
        Get-ProcessByPort 8080 | ForEach-Object { Stop-Process -Id $_.ProcessId -WhatIf }
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('LocalPort')]
        [ValidateRange(1, 65535)]
        [int[]]$Port,

        [ValidateSet('TCP', 'UDP', 'Both')]
        [string]$Protocol = 'Both',

        [switch]$All
    )
    begin {
        $wantTcp = $Protocol -in 'TCP', 'Both'
        $wantUdp = $Protocol -in 'UDP', 'Both'
        $ports = [System.Collections.Generic.List[int]]::new()

        function New-PortRecord($Proto, $Address, $LocalPort, $State, $ProcessId, $Name) {
            $proc = if ($ProcessId) { Get-Process -Id $ProcessId -ErrorAction SilentlyContinue }
            [PSCustomObject]@{
                Protocol     = $Proto
                LocalAddress = $Address
                LocalPort    = [int]$LocalPort
                State        = $State
                ProcessId    = if ($ProcessId) { [int]$ProcessId } else { $null }
                ProcessName  = if ($proc) { $proc.ProcessName } elseif ($Name) { $Name } else { $null }
                Path         = if ($proc) { $proc.Path } else { $null }
            }
        }

        # "0.0.0.0:22", "[::]:22", "*:22", "127.0.0.53%lo:53" -> address, port
        function Split-Endpoint([string]$Endpoint) {
            $i = $Endpoint.LastIndexOf(':')
            $addr = $Endpoint.Substring(0, $i).Trim('[', ']') -replace '%.*$', ''
            , @($addr, $Endpoint.Substring($i + 1))
        }
    }
    process {
        if ($Port) { $ports.AddRange($Port) }
    }
    end {
        $results = [System.Collections.Generic.List[object]]::new()

        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            if ($wantTcp) {
                $tcp = @{ ErrorAction = 'SilentlyContinue' }
                if ($ports.Count) { $tcp.LocalPort = $ports.ToArray() }
                if (-not $All) { $tcp.State = 'Listen' }
                foreach ($c in Get-NetTCPConnection @tcp) {
                    $results.Add((New-PortRecord 'TCP' $c.LocalAddress $c.LocalPort $c.State.ToString() $c.OwningProcess))
                }
            }
            if ($wantUdp) {
                $udp = @{ ErrorAction = 'SilentlyContinue' }
                if ($ports.Count) { $udp.LocalPort = $ports.ToArray() }
                foreach ($u in Get-NetUDPEndpoint @udp) {
                    $results.Add((New-PortRecord 'UDP' $u.LocalAddress $u.LocalPort 'Bound' $u.OwningProcess))
                }
            }
        }
        elseif ($IsLinux -and (Get-Command ss -CommandType Application -ErrorAction SilentlyContinue)) {
            # -H no header, -n numeric, -p processes; -l listening only unless -All
            $flags = '-Hnp' + $(if ($All) { 'a' } else { 'l' })
            $sets = @()
            if ($wantTcp) { $sets += , @('TCP', ($flags + 't')) }
            if ($wantUdp) { $sets += , @('UDP', ($flags + 'u')) }
            foreach ($set in $sets) {
                foreach ($line in (& ss $set[1] 2>$null)) {
                    # State Recv-Q Send-Q Local Peer [users:(("name",pid=123,fd=4),...)]
                    $cols = -split $line
                    if ($cols.Count -lt 5) { continue }
                    $ep = Split-Endpoint $cols[3]
                    if ($ports.Count -and [int]$ep[1] -notin $ports) { continue }
                    $state = if ($set[0] -eq 'UDP') { 'Bound' } else { $cols[0] }
                    $owners = [regex]::Matches($line, '\("(?<n>[^"]+)",pid=(?<p>\d+)')
                    if ($owners.Count) {
                        foreach ($o in ($owners | Group-Object { $_.Groups['p'].Value })) {
                            $m = $o.Group[0]
                            $results.Add((New-PortRecord $set[0] $ep[0] $ep[1] $state $m.Groups['p'].Value $m.Groups['n'].Value))
                        }
                    }
                    else {
                        $results.Add((New-PortRecord $set[0] $ep[0] $ep[1] $state $null $null))
                    }
                }
            }
        }
        elseif (Get-Command lsof -CommandType Application -ErrorAction SilentlyContinue) {
            # -F emits one field per line: p<pid> c<command> f<fd> P<proto> n<name> TST=<state>
            $selectors = @()
            if ($wantTcp) { $selectors += if ($ports.Count) { $ports | ForEach-Object { "-iTCP:$_" } } else { '-iTCP' } }
            if ($wantUdp) { $selectors += if ($ports.Count) { $ports | ForEach-Object { "-iUDP:$_" } } else { '-iUDP' } }
            $lsofArgs = @('-nP', '-FpcfPnT') + $selectors
            if (-not $All -and $Protocol -eq 'TCP') { $lsofArgs += '-sTCP:LISTEN' }

            $procId = $null; $cmd = $null; $proto = $null; $name = $null
            $flush = {
                if ($name -and $proto) {
                    $st = if ($proto -eq 'UDP') { 'Bound' } else { $state }
                    $ep = Split-Endpoint ($name -split '->')[0]
                    $isListen = $proto -eq 'UDP' -or $st -eq 'LISTEN'
                    if ($ep[1] -match '^\d+$' -and ($All -or $isListen) -and (-not $ports.Count -or [int]$ep[1] -in $ports)) {
                        $results.Add((New-PortRecord $proto $ep[0] $ep[1] $st $procId $cmd))
                    }
                }
            }
            $state = $null
            foreach ($line in (& lsof @lsofArgs 2>$null)) {
                if (-not $line) { continue }
                $field = $line.Substring(1)
                switch -CaseSensitive ($line[0]) {
                    'p' { . $flush; $procId = $field; $cmd = $null; $proto = $null; $name = $null; $state = $null }
                    'c' { $cmd = $field }
                    'f' { . $flush; $proto = $null; $name = $null; $state = $null }
                    'P' { $proto = $field }
                    'n' { $name = $field }
                    'T' { if ($field -like 'ST=*') { $state = $field.Substring(3) } }
                }
            }
            . $flush
        }
        else {
            Write-Error 'Neither ss nor lsof is available to enumerate sockets.'
            return
        }

        # lsof and ss report IPv4 and IPv6 sockets separately; keep both but drop exact repeats
        $results | Sort-Object Protocol, LocalPort, LocalAddress, ProcessId -Unique
    }
}
