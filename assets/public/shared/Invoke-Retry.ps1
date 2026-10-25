function Invoke-Retry {
    <#
    .SYNOPSIS
        Runs a script block, retrying on failure with exponential backoff.
    .DESCRIPTION
        Invokes ScriptBlock up to MaxAttempts times. Any error, including a
        non-terminating one, counts as a failure. Between attempts it waits
        DelaySeconds, multiplied by BackoffFactor each time and capped at
        MaxDelaySeconds, plus up to 25% random jitter so parallel callers don't
        retry in lockstep. Returns the script block's output on the first
        success and rethrows the last error if every attempt fails.
    .PARAMETER ScriptBlock
        The work to run.
    .PARAMETER MaxAttempts
        Total attempts, including the first. Default 3.
    .PARAMETER DelaySeconds
        Wait before the second attempt. Default 1.
    .PARAMETER BackoffFactor
        Multiplier applied to the delay after each failure. Default 2.
    .PARAMETER MaxDelaySeconds
        Upper bound for any single wait. Default 30.
    .PARAMETER RetryOn
        Only retry when the exception is one of these types (or derives from
        one). Any other exception is rethrown immediately.
    .EXAMPLE
        Invoke-Retry { Invoke-RestMethod https://api.github.com/rate_limit }
    .EXAMPLE
        Invoke-Retry -MaxAttempts 5 -DelaySeconds 2 { git push origin main; if ($LASTEXITCODE) { throw "git push exited $LASTEXITCODE" } }
    .EXAMPLE
        Invoke-Retry -RetryOn ([System.Net.Http.HttpRequestException]) { Invoke-WebRequest $url }
    .NOTES
        Native commands don't throw on a non-zero exit code; throw on
        $LASTEXITCODE inside the script block if you want those retried.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [scriptblock]$ScriptBlock,

        [ValidateRange(1, 100)]
        [int]$MaxAttempts = 3,

        [ValidateRange(0, 3600)]
        [double]$DelaySeconds = 1,

        [ValidateRange(1, 10)]
        [double]$BackoffFactor = 2,

        [ValidateRange(0, 3600)]
        [double]$MaxDelaySeconds = 30,

        [type[]]$RetryOn
    )

    $delay = $DelaySeconds
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Write-Verbose "Invoke-Retry: attempt $attempt of $MaxAttempts"
            # Stop turns non-terminating errors from cmdlets into catchable failures
            $ErrorActionPreference = 'Stop'
            return (& $ScriptBlock)
        }
        catch {
            $ex = $_.Exception
            if ($RetryOn -and -not ($RetryOn | Where-Object { $_.IsInstanceOfType($ex) })) {
                throw
            }
            if ($attempt -ge $MaxAttempts) {
                throw
            }

            $wait = [math]::Min($delay, $MaxDelaySeconds)
            $wait += $wait * (Get-Random -Minimum 0.0 -Maximum 0.25)
            Write-Warning ("Attempt {0} of {1} failed: {2} Retrying in {3:N1}s." -f $attempt, $MaxAttempts, $ex.Message, $wait)
            Start-Sleep -Milliseconds ([int]($wait * 1000))
            $delay *= $BackoffFactor
        }
    }
}
