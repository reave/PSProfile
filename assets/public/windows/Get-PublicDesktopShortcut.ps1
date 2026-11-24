function Get-PublicDesktopShortcut {
    <#
    .SYNOPSIS
        Lists the shortcuts on the user and public desktops.

    .DESCRIPTION
        Finds every shortcut (.lnk) file on the desktops, including subfolders, and returns an
        object for each with its ComputerName, Hotkey, TargetPath, LinkPath, Arguments, Target,
        Link, WindowStyle and IconLocation. On the local computer it reads the current user's
        desktop and the public desktop. On a remote computer it reads the public desktop through
        the C$ administrative share, which needs administrator rights on that computer.

    .PARAMETER ComputerName
        The computers to read. The default is the local computer.

    .EXAMPLE
        Get-PublicDesktopShortcut

        Lists the shortcuts on your desktop and the public desktop.

    .EXAMPLE
        Get-PublicDesktopShortcut -ComputerName 'Server01'

        Lists the shortcuts on the public desktop of Server01.
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )

    foreach ($Computer in $ComputerName) {
        Write-Verbose "Creating a Shell object"
        $obj = New-Object -ComObject WScript.Shell

        if ($Computer -in $env:COMPUTERNAME, 'localhost', '.') {
            Write-Verbose "Expanding environment variables for User and Public Desktop folders"
            $desktopPaths = [System.Environment]::GetFolderPath('Desktop'), $obj.SpecialFolders.Item('AllUsersDesktop')
        } else {
            # Only the public desktop is reachable remotely: each user's desktop lives in their profile.
            $desktopPaths = "\\$Computer\C$\Users\Public\Desktop"
            if (-not (Test-Path -Path $desktopPaths)) {
                Write-Error -Message "Can't read the public desktop on $Computer at $desktopPaths."
                continue
            }
        }

        Write-Verbose "Getting a list of all shortcuts in $($desktopPaths -join ', ')"
        $Shortcuts = Get-ChildItem -Path $desktopPaths -Filter *.lnk -Recurse -ErrorAction SilentlyContinue

        Write-Verbose "Discovered $(($Shortcuts | Measure-Object).Count) shortcuts"

        $counter = 1
        foreach ($Shortcut in $Shortcuts) {
            Write-Verbose "Processing shortcut number $($counter)"
            # Preparing Empty Hashtable for data
            Write-Verbose "Preparing Empty Hashtable for data"
            $info = @{ }
            $info.ComputerName = $Computer

            # Instantiating and object from the current shortcut
            Write-Verbose "Instantiating and object from the current shortcut"
            $link = $obj.CreateShortcut($Shortcut.FullName)

            # Filling the Empty Hashtable with data from the Link Object
            Write-Verbose "Filling the Empty Hashtable with data from the Link Object"
            $info.Hotkey = $link.Hotkey
            $info.TargetPath = $link.TargetPath
            $info.LinkPath = $link.FullName
            $info.Arguments = $link.Arguments
            $info.Target = try { Split-Path $info.TargetPath -Leaf -ErrorAction SilentlyContinue } catch { 'n/a' }
            $info.Link = try { Split-Path $info.LinkPath -Leaf -ErrorAction SilentlyContinue } catch { 'n/a' }
            $info.WindowStyle = $link.WindowStyle
            $info.IconLocation = $link.IconLocation

            # Creating an object out of the newly filled hashtable
            Write-Verbose "Creating an object out of the newly filled hashtable"
            New-Object PSObject -Property $info

            $counter++
        }
    }
}
