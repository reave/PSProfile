###############################################################################################################
# Language     :  PowerShell 4.0
# Filename     :  Clear-ARPCache.ps1
# Autor        :  BornToBeRoot (https://github.com/BornToBeRoot)
# Description  :  Clear the ARP cache
# Repository   :  https://github.com/BornToBeRoot/PowerShell
###############################################################################################################

<#
    .SYNOPSIS
    Clear the ARP cache

    .DESCRIPTION
    Clear the Address Resolution Protocol (ARP) cache, which is used for resolution of internet layer addresses into link layer addresses.
    Reports Success or Failure based on netsh's own exit code (0 = success), and prints Write-Verbose tracing at each step with -Verbose.

    .EXAMPLE
    Clear-ARPCache

    .EXAMPLE
    Clear-ARPCache -Verbose

    .LINK
    https://github.com/BornToBeRoot/PowerShell/blob/master/Documentation/Function/Clear-ARPCache.README.md
#>

function Clear-ARPCache
{
    [CmdletBinding()]
    param(

    )

    Begin{
        Write-Verbose "Checking for administrator privileges..."
        if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
        {
            Write-Warning -Message "Administrator rights are required to clear the ARP cache! Attempts to start the process with elevated privileges..."
            Write-Verbose "Not running elevated - netsh.exe will be launched via a UAC prompt (-Verb RunAs)."
        }
        else
        {
            Write-Verbose "Already running with administrator privileges."
        }
    }

    Process{
        # -RedirectStandardOutput can't be combined with -Verb RunAs (elevated processes launched via
        # ShellExecute don't support redirected stdio handles) - netsh's exit code is what's actually
        # available here, and is what "Success"/"Failure" below is based on. 0 means netsh succeeded.
        $netshArguments = "interface ipv4 delete arpcache"

        try{
            Write-Verbose "Launching netsh.exe with arguments: $netshArguments"
            $process = Start-Process -FilePath "$env:SystemRoot\System32\netsh.exe" -ArgumentList $netshArguments -Verb "RunAs" -WindowStyle Hidden -Wait -PassThru
            Write-Verbose "netsh.exe exited with code $($process.ExitCode)"

            if ($process.ExitCode -eq 0)
            {
                Write-Host "Success: ARP cache cleared." -ForegroundColor Green
            }
            else
            {
                Write-Host "Failure: netsh.exe exited with code $($process.ExitCode)." -ForegroundColor Red
            }
        }
        catch{
            Write-Verbose "Failed to launch netsh.exe: $_"
            Write-Host "Failure: $_" -ForegroundColor Red
            throw
        }
    }

    End{

    }
}