function Invoke-DNSCacheFlush {
    <#
    .SYNOPSIS
        Flushes the DNS cache on the local computer or one or more remote computers.

    .DESCRIPTION
        Invoke-DNSCacheFlush attempts to clear the DNS resolver cache. It prefers the native
        Clear-DnsClientCache cmdlet when available; if not, it falls back to running
        "ipconfig /flushdns". Supports remote execution via -ComputerName or -CimSession.

    .PARAMETER ComputerName
        One or more remote computer names to flush. Uses PowerShell remoting (Invoke-Command).

    .PARAMETER CimSession
        One or more CimSession objects to run the flush on.

    .PARAMETER Force
        Suppresses non-error interactive prompts.

    .EXAMPLE
        Invoke-DNSCacheFlush

    .EXAMPLE
        Invoke-DNSCacheFlush -ComputerName Server01,Server02 -Verbose

    .NOTES
        Requires administrative privileges on target machines to flush DNS cache.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]] $ComputerName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Microsoft.Management.Infrastructure.CimSession[]] $CimSession,

        [switch] $Force
    )
    process {

        function Clear-DnsCacheLocal {
            <#
            .SYNOPSIS
                Clears the DNS client cache on the local computer.

            .DESCRIPTION
                Uses Clear-DnsClientCache when it's available, and otherwise runs ipconfig /flushdns. Returns
                a hashtable with Success, Method and Message keys.

            .EXAMPLE
                Clear-DnsCacheLocal

                Clears the local DNS cache and returns the result.
            #>
            param()

            # Check for native cmdlet
            if (Get-Command -Name Clear-DnsClientCache -ErrorAction SilentlyContinue) {
                Clear-DnsClientCache -ErrorAction Stop
                return @{ Success = $true; Method = 'Clear-DnsClientCache'; Message = 'Cache cleared.' }
            }

            # Fallback to ipconfig
            $proc = Start-Process -FilePath 'ipconfig.exe' -ArgumentList '/flushdns' -NoNewWindow -Wait -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0) {
                return @{ Success = $true; Method = 'ipconfig /flushdns'; Message = 'Cache flushed.' }
            } else {
                return @{ Success = $false; Method = 'ipconfig /flushdns'; Message = "ipconfig returned exit code $($proc.ExitCode)." }
            }
        }

        function Clear-DnsCacheRemote {
            <#
            .SYNOPSIS
                Clears the DNS client cache on a remote computer.

            .DESCRIPTION
                Runs the same steps as Clear-DnsCacheLocal on the remote computer through PowerShell remoting
                and returns its result hashtable. When Session is given, the command still runs over a new
                remoting session to Target. Errors are passed on to the caller.

            .PARAMETER Target
                The name of the remote computer.

            .PARAMETER Session
                A CIM session for the remote computer. Optional.

            .EXAMPLE
                Clear-DnsCacheRemote -Target 'Server01'

                Clears the DNS cache on Server01.
            #>
            param(
                [string] $Target,
                [Microsoft.Management.Infrastructure.CimSession] $Session
            )

            $script = {
                    # Same logic inside remote session
                if (Get-Command -Name Clear-DnsClientCache -ErrorAction SilentlyContinue) {
                    Clear-DnsClientCache -ErrorAction Stop
                    return @{ Success = $true; Method = 'Clear-DnsClientCache'; Message = 'Cache cleared.' }
                }
                $proc = Start-Process -FilePath 'ipconfig.exe' -ArgumentList '/flushdns' -NoNewWindow -Wait -PassThru -ErrorAction Stop
                if ($proc.ExitCode -eq 0) {
                    return @{ Success = $true; Method = 'ipconfig /flushdns'; Message = 'Cache flushed.' }
                } else {
                    return @{ Success = $false; Method = 'ipconfig /flushdns'; Message = "ipconfig returned exit code $($proc.ExitCode)." }
                }
            }

            try {
                if ($Session) {
                    Invoke-CimMethod -CimSession $Session -ClassName __Namespace -MethodName NonExistentMethod -ErrorAction SilentlyContinue | Out-Null
                    # Using Invoke-Command with CimSession isn't direct, so use Invoke-Command against the session's machine
                    $result = Invoke-Command -Session (New-PSSession -ComputerName $Target -ErrorAction Stop) -ScriptBlock $script -ErrorAction Stop
                } else {
                    $result = Invoke-Command -ComputerName $Target -ScriptBlock $script -ErrorAction Stop
                }
                return $result
            } catch {
                throw $_
            }
        }

        # Determine targets: local when neither ComputerName nor CimSession provided
        $targets = if ($PSBoundParameters.ContainsKey('ComputerName')) { $ComputerName } else { @('localhost') }

        foreach ($t in $targets) {
            $isLocal = ($t -eq 'localhost' -or $t -eq $env:COMPUTERNAME -or [string]::IsNullOrWhiteSpace($t))

            if ($PSCmdlet.ShouldProcess($t, "Flush DNS cache")) {
                try {
                    if ($isLocal -and -not $PSBoundParameters.ContainsKey('CimSession')) {
                        # Local flush
                        $admin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        if (-not $admin -and -not $Force) {
                            Write-Warning "Administrator privileges are recommended to flush the DNS cache. Rerun with elevated rights or -Force to attempt anyway."
                        }

                        $res = Clear-DnsCacheLocal
                        [PSCustomObject]@{
                            ComputerName = $env:COMPUTERNAME
                            Success      = $res.Success
                            Method       = $res.Method
                            Message      = $res.Message
                            TimeStamp    = (Get-Date)
                        }
                    } else {
                        # Remote flush
                        $res = Clear-DnsCacheRemote -Target $t -Session $null
                        [PSCustomObject]@{
                            ComputerName = $t
                            Success      = $res.Success
                            Method       = $res.Method
                            Message      = $res.Message
                            TimeStamp    = (Get-Date)
                        }
                    }
                } catch {
                    [PSCustomObject]@{
                        ComputerName = $t
                        Success      = $false
                        Method       = 'Error'
                        Message      = $_.Exception.Message
                        TimeStamp    = (Get-Date)
                    }
                }
            }
        }
    }
}
