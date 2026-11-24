function Show-Sysinfo {
    <#
    .SYNOPSIS
        Show system information
    .DESCRIPTION
        Windows alternative to screenfetch or archey that will display relevant system information
    .NOTES
        Name: Show-Sysinfo
        Original Author: Unknown
        Function Author: reave (https://github.com/reave)
        Inpiration from:
    screenFetch by KittyKatt
    https://github.com/KittyKatt/screenFetch
    A very nice screenshotting and information tool. For GNU/Linux (Almost all Major Distros Supported) *This has been ported to Windows, link below.*

    archey by djmelik
    https://github.com/djmelik/archey
    Another nice screenshotting and information tool. More hardware oriented than screenFetch. For GNU/Linux
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleCommands', '',
        Justification = 'Clear-Host exists on every supported edition; the compatibility profile misses it.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleTypes', '',
        Justification = 'The Windows Forms types are used after Add-Type loads System.Windows.Forms.')]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [ValidateSet('AllMonitors', 'PowerShellOnly')]
        [string]$SSMode
    )
    if ( $Path -and !( Test-Path -Path $Path) ) {
        Write-Error "Path cannot be found..."
        break
    }

    function Save-Screenshot {
        <#
        .SYNOPSIS
            Saves a screenshot of all monitors as a PNG file.

        .DESCRIPTION
            Captures the whole virtual screen, which spans every monitor, and saves it in TarPath as
            screenshot-<MM-dd-yyyy_HH_mm_ss>.png.

        .PARAMETER TarPath
            The folder to save the screenshot in.

        .EXAMPLE
            Save-Screenshot -TarPath "$HOME\Pictures"

            Saves a screenshot of all monitors in your Pictures folder.
        #>
        [CmdletBinding()]
        param(
            [string]$TarPath
        )

        process {
            $null = [Reflection.Assembly]::LoadWithPartialName("System.Drawing")

            # Changed how $bounds is calculated so that screen shots with multiple monitors that are offset work correctly
            $bounds = [Windows.Forms.SystemInformation]::VirtualScreen
            # Check Path for Trailing BackSlashes
            if ( $TarPath.EndsWith("\") ) {
                $TarPath = $TarPath.Substring(0, $TarPath.Length - 1)
            }

            # Define The Target Path
            $stamp = Get-Date -Format MM-dd-yyyy_HH_mm_ss
            $target = "$TarPath\screenshot-$stamp.png"

            # Save the Screenshot
            $bmp = New-Object Drawing.Bitmap $bounds.width, $bounds.height
            $graphics = [Drawing.Graphics]::FromImage($bmp)
            $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
            $bmp.Save($target)
            $graphics.Dispose()
            $bmp.Dispose()
        }
    }

    function Export-ActiveWindowScreenshot {
        <#
        .SYNOPSIS
            Saves a screenshot of a process's main window.

        .DESCRIPTION
            Finds the main window of the process with the given ID, captures the area of the screen it
            covers, and saves it as <FileName>.<ImageType> in OutPath. Nothing is saved if the window's
            position can't be read.

        .PARAMETER wpid
            The ID of the process whose main window to capture.

        .PARAMETER OutPath
            The folder to save the file in. The default is $env:HOME.

        .PARAMETER FileName
            The file name, without the extension. The default is Screenshot.

        .PARAMETER ImageType
            The file name extension. The default is png.

        .EXAMPLE
            Export-ActiveWindowScreenshot -wpid $PID -OutPath "$HOME\Pictures" -FileName 'Sysinfo'

            Saves a screenshot of the current PowerShell window as Sysinfo.png in your Pictures folder.
        #>
        [cmdletbinding()]
        param(
            [Parameter(Mandatory = $true)]
            [int]$wpid,
            [Parameter(Mandatory = $false)]
            [string]$OutPath = "$Env:Home",
            [Parameter(Mandatory = $false)]
            [string]$FileName = 'Screenshot',
            [Parameter(Mandatory = $false)]
            [string]$ImageType = 'png'
        )

        $src = @'
using System;
using System.Runtime.InteropServices;

namespace PInvoke
{
    public static class NativeMethods
    {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;        // x position of upper-left corner
        public int Top;         // y position of upper-left corner
        public int Right;       // x position of lower-right corner
        public int Bottom;      // y position of lower-right corner
    }
}
'@


        Add-Type -TypeDefinition $src
        Add-Type -AssemblyName System.Drawing

        # Get a process object from which we will get the main window bounds
        $iseProc = Get-Process -Id $wpid

        $bmpScreenCap = $g = $null
        try {
            $rect = New-Object PInvoke.RECT
            if ([PInvoke.NativeMethods]::GetWindowRect($iseProc.MainWindowHandle, [ref]$rect)) {
                $width = $rect.Right - $rect.Left + 1
                $height = $rect.Bottom - $rect.Top + 1
                $bmpScreenCap = New-Object System.Drawing.Bitmap $width, $height
                $g = [System.Drawing.Graphics]::FromImage($bmpScreenCap)
                $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmpScreenCap.Size,
                    [System.Drawing.CopyPixelOperation]::SourceCopy)
                $SaveLocation = Join-Path $OutPath "$FileName.$ImageType"

                $bmpScreenCap.Save("$SaveLocation")
            }
        } finally {
            if ($bmpScreenCap) { $bmpScreenCap.Dispose() }
            if ($g) { $g.Dispose() }
        }
    }

    $username = [Environment]::USERNAME
    $workstation = $Env:COMPUTERNAME

    $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

    $arch = (Get-CimInstance -ClassName Win32_OperatingSystem).osarchitecture

    $CPU = [Decimal]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue)

    $driveSpecs = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $PSItem.DriveType -eq 3 }

    $memTotal = [Decimal]::Round(((Get-CimInstance -ClassName Win32_OperatingSystem).TotalVisibleMemorySize / 1024))
    $memFree = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    $mem = "$memFree MB out of $memTotal MB available"

    # Computed from the last boot time, since Windows PowerShell 5.1 has no Get-Uptime.
    $uptimeSpan = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $uptime = "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes, $uptimeSpan.Seconds

    # DONE: Fix support for Multiple Monitors
    # FROM: Shay Levy's Response - http://stackoverflow.com/questions/7967699/get-screen-resolution-using-wmi-powershell-in-windows-7
    $ScreenWidth = 0
    $ScreenHeight = 0
    Add-Type -AssemblyName System.Windows.Forms
    $Bounds = [System.Windows.Forms.Screen]::AllScreens | Select-Object -ExpandProperty Bounds

    $ScreenWidth = $Bounds | Measure-Object -Property Width -Sum | Select-Object -ExpandProperty Sum
    $ScreenHeight = $Bounds | Measure-Object -Property Height -Maximum | Select-Object -ExpandProperty Maximum

    $RESOLUTION = "$ScreenWidth x $ScreenHeight"

    # Clear Screen before displaying information
    Clear-Host

    # Only show the countdown if we're taking a screen shot
    if ($Path) {
        # DONE: Add Countdown Timer
        Write-Host "...3" -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "...2" -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "...1" -NoNewline
        Start-Sleep -Milliseconds 500
        Write-Host "    Cheese!"
    }


    # Array of arrays of script blocks, containing commands to draw the Windows Logo.
    # Each sub-array should correspond to 1 line of the logo
    $Logo = @(
        @( { Write-Host "`n" -NoNewline } ),
        @( { Write-Host '        ,.=:!!t3Z3z.,               ' -ForegroundColor "red" -NoNewline } ),
        @( { Write-Host '       :tt:::tt333EE3               ' -ForegroundColor "red" -NoNewline } ),
        @(	{ Write-Host '       Et:::ztt33EEEL ' -ForegroundColor "red" -NoNewline },
            { Write-Host '@Ee.,      ..,' -ForegroundColor "green" -NoNewline } ),
        @(	{ Write-Host '      ;tt:::tt333EE7 ' -ForegroundColor "red" -NoNewline },
            { Write-Host ';EEEEEEttttt33#' -ForegroundColor "green" -NoNewline } ),
        @( { Write-Host '     :Et:::zt333EEQ. ' -ForegroundColor "red" -NoNewline },
            { Write-Host '$EEEEEttttt33QL' -ForegroundColor "green" -NoNewline } ),
        @(	{ Write-Host '     it::::tt333EEF ' -ForegroundColor "red" -NoNewline },
            { Write-Host '@EEEEEEttttt33F ' -ForegroundColor "green" -NoNewline } ),
        @(	{ Write-Host '    ;3=*^```"*4EEV ' -ForegroundColor "red" -NoNewline },
            { Write-Host ':EEEEEEttttt33@. ' -ForegroundColor "green" -NoNewline } ),
        @(	{ Write-Host '    ,.=::::!t=., ' -ForegroundColor "blue" -NoNewline },
            { Write-Host '` ' -ForegroundColor "red" -NoNewline },
            { Write-Host '@EEEEEEtttz33QF  ' -ForegroundColor "green" -NoNewline } ),
        @(	{ Write-Host '   ;::::::::zt33)   ' -ForegroundColor "blue" -NoNewline },
            { Write-Host '"4EEEtttji3P*   ' -ForegroundColor "green" -NoNewline } ),
        @(	{ Write-Host '  :t::::::::tt33.' -ForegroundColor "blue" -NoNewline },
            { Write-Host ' :Z3z.. `` ,..g.   ' -ForegroundColor "yellow" -NoNewline } ),
        @(	{ Write-Host '  i::::::::zt33F ' -ForegroundColor "blue" -NoNewline },
            { Write-Host 'AEEEtttt::::ztF    ' -ForegroundColor "yellow" -NoNewline } ),
        @( { Write-Host ' ;:::::::::t33V ' -ForegroundColor "blue" -NoNewline },
            { Write-Host ';EEEttttt::::t3     ' -ForegroundColor "yellow" -NoNewline } ),
        @(	{ Write-Host ' E::::::::zt33L ' -ForegroundColor "blue" -NoNewline },
            { Write-Host '@EEEtttt::::z3F     ' -ForegroundColor "yellow" -NoNewline } ),
        @(	{ Write-Host '{3=*^```"*4E3) ' -ForegroundColor "blue" -NoNewline },
            { Write-Host ';EEEtttt:::::tZ`     ' -ForegroundColor "yellow" -NoNewline } ),
        @(	{ Write-Host '             ` ' -ForegroundColor "blue" -NoNewline },
            { Write-Host ':EEEEtttt::::z7      ' -ForegroundColor "yellow" -NoNewline } ),
        @(	{ Write-Host '                 ' -ForegroundColor "blue" -NoNewline },
            { Write-Host '"VEzjt:;;z>*`      ' -ForegroundColor "yellow" -NoNewline } ),
        @(	{ Write-Host "`n" } )
    )

    function Get-LineScriptBlock($Label, $Value, $LabelSize = 11, $PadLeft = 4 ) {
        <#
        .SYNOPSIS
            Builds the commands that write one line of system information.

        .DESCRIPTION
            Returns two script blocks. The first writes Label in red, right-aligned to LabelSize
            characters after PadLeft spaces, without ending the line. The second writes Value in white and
            ends the line. The values are fixed into the script blocks when they're created, not read when
            the blocks run.

        .PARAMETER Label
            The label text, such as OS:.

        .PARAMETER Value
            The value to show after the label.

        .PARAMETER LabelSize
            The width the label is right-aligned to. The default is 11.

        .PARAMETER PadLeft
            The number of spaces before the label. The default is 4.

        .EXAMPLE
            Get-LineScriptBlock -Label 'OS:' -Value 'Windows 11 Pro'

            Returns the script blocks that write the OS line.
        #>
        # Using [ScriptBlock]::Create rather than literal notation to force PowerShell to
        # store value of variables in scriptblock, rather than the variables themselves.
        @( [ScriptBlock]::Create("Write-Host `"$(' ' * $PadLeft)$($Label.PadLeft($LabelSize)) `" -foregroundcolor Red -nonewline"),
            [ScriptBlock]::Create("Write-Host `"$Value`" -foregroundcolor White") )
    }

    # Array of arrays of script blocks, containing commands to write out system information
    # Each sub-array should correspond to 1 line of information
    $AllInfo = @(
        @(	{ Write-Host } ),
        @(	{ Write-Host } ),
        @(	{ Write-Host "    $USERNAME" -ForegroundColor "Cyan" -NoNewline; },
            { Write-Host "@" -ForegroundColor "white" -NoNewline; },
            { Write-Host "$WORKSTATION" -ForegroundColor "Green" } ),
        @(	{ Write-Host } ),
        $(Get-LineScriptBlock -Label "OS:" -Value "$OS $ARCH"),
        $(Get-LineScriptBlock -Label "CPU:" -Value "$CPU% utilization"),
        $(Get-LineScriptBlock -Label "Memory:" -Value $MEM),
        $(Get-LineScriptBlock -Label "Uptime:" -Value $UPTIME),
        $(Get-LineScriptBlock -Label "Resolution:" -Value $RESOLUTION)
        @(	{ Write-Host } ),
        $(Get-LineScriptBlock -Label "$($driveSpecs[0].VolumeName):" -Value "$($driveSpecs[0].DeviceID)\ has $([Decimal]::Round($driveSpecs[0].FreeSpace / 1GB)) GB Free Space" )
    )

    # Add any drives besides the first
    if ($driveSpecs.Count -gt 1) {
        $driveSpecs | Select-Object -Skip 1 | ForEach-Object {
            $AllInfo += , $(Get-LineScriptBlock -Label "$($_.VolumeName):" -Value "$($_.DeviceID)\ has $([Decimal]::Round($_.FreeSpace / 1GB)) GB Free Space" )
        }
    }

    # Add enough blank lines so that $Logo and $AllInfo are the same size
    while ($Logo.Count -gt $AllInfo.Count) {
        $AllInfo += @(	{ Write-Host } )
    }

    # Add enough blank lines so that $Logo and $AllInfo are the same size
    while ($AllInfo.Count -gt $Logo.Count) {
        $Logo += @(	{ Write-Host } )
    }

    # Loop through both arrays and execute the script blocks
    for ($i = 0; $i -lt $Logo.Count; $i++) {
        $Logo[$i] | ForEach-Object { & $_ }
        $AllInfo[$i] | ForEach-Object { & $_ }
    }

    # Take Screenshot if the Parameters are assigned...
    if ( $Path ) {
        switch ($SSMode) {
            'AllMonitors' { Save-Screenshot -TarPath $Path }
            'PowerShellOnly' { Export-ActiveWindowScreenshot -wpid $(([System.Diagnostics.Process]::GetCurrentProcess()).id) -OutPath $Path }
        }
    }
}
