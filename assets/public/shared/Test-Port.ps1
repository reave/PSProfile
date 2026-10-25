function Test-Port {
    <#
    .SYNOPSIS
        Tests whether a TCP port is reachable, with a short timeout.
    .DESCRIPTION
        Opens a TCP connection to each ComputerName/Port pair and reports whether
        it connected and how long it took. Uses .NET TcpClient, so it behaves the
        same on Windows, macOS, and Linux (Test-NetConnection is Windows-only and
        much slower to time out).
    .PARAMETER ComputerName
        Host name or IP address. Accepts pipeline input. Defaults to localhost.
    .PARAMETER Port
        One or more TCP ports to test.
    .PARAMETER TimeoutMs
        How long to wait for each connection, in milliseconds. Default 1000.
    .PARAMETER Quiet
        Return only $true/$false for each test instead of an object.
    .EXAMPLE
        Test-Port github.com 443
    .EXAMPLE
        'web01', 'web02' | Test-Port -Port 80, 443 -TimeoutMs 500
    .EXAMPLE
        if (Test-Port db01 5432 -Quiet) { 'Postgres is up' }
    .OUTPUTS
        PSCustomObject
        System.Boolean
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Host', 'CN')]
        [string[]]$ComputerName = 'localhost',

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 65535)]
        [int[]]$Port,

        [ValidateRange(1, 600000)]
        [int]$TimeoutMs = 1000,

        [switch]$Quiet
    )
    process {
        foreach ($computer in $ComputerName) {
            foreach ($p in $Port) {
                $client = [System.Net.Sockets.TcpClient]::new()
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                $open = $false
                $err = $null
                try {
                    $task = $client.ConnectAsync($computer, $p)
                    if ($task.Wait($TimeoutMs)) {
                        $open = $client.Connected
                    }
                    else {
                        $err = "Timed out after $TimeoutMs ms"
                    }
                }
                catch {
                    # ConnectAsync wraps socket and DNS failures in an AggregateException
                    $inner = $_.Exception
                    while ($inner.InnerException) { $inner = $inner.InnerException }
                    $err = $inner.Message
                }
                finally {
                    $timer.Stop()
                    $client.Dispose()
                }

                Write-Verbose "${computer}:$p open=$open $err"
                if ($Quiet) {
                    $open
                }
                else {
                    [PSCustomObject]@{
                        ComputerName = $computer
                        Port         = $p
                        Open         = $open
                        LatencyMs    = if ($open) { [math]::Round($timer.Elapsed.TotalMilliseconds, 1) } else { $null }
                        Error        = $err
                    }
                }
            }
        }
    }
}
