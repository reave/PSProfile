function Get-PublicDesktopShortcuts {
    <#
    .SYNOPSIS
        Lists the shortcuts on the user and public desktops.

    .DESCRIPTION
        Finds every shortcut (.lnk) file on the current user's desktop and the public desktop,
        including subfolders, and returns an object for each with its Hotkey, TargetPath, LinkPath,
        Arguments, Target, Link, WindowStyle and IconLocation.

    .PARAMETER ComputerName
        The listing runs once for each name given. The shortcuts are always read from the local
        computer, and nothing is returned if no name is given.

    .EXAMPLE
        Get-PublicDesktopShortcuts -ComputerName $env:COMPUTERNAME

        Lists the desktop shortcuts on this computer.
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ComputerName
    )

    foreach ($Computer in $ComputerName) {
        Write-Verbose "Creating a Shell object"
        $obj = New-Object -ComObject WScript.Shell

        Write-Verbose "Expanding envinronment variables for User and Public Desktop folders"
        $pathUser = [System.Environment]::GetFolderPath('Desktop')
        $pathCommon = $obj.SpecialFolders.Item('AllUsersDesktop')

        Write-Verbose "Getting a list of all shortcuts in the user and public desktop locations"
        $Shortcuts = Get-ChildItem -Path $pathUser, $pathCommon -Filter *.lnk -Recurse -ErrorAction SilentlyContinue

        Write-Verbose "Discovered $(($Shortcuts | Measure-Object).Count) shortcuts"

        $counter = 1
        foreach ($Shortcut in $Shortcuts) {
            Write-Verbose "Processing shortcut number $($counter)"
            # Preparing Empty Hashtable for data
            Write-Verbose "Preparing Empty Hashtable for data"
            $info = @{ }

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
