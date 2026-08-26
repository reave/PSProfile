<#
    Author: Joseph Ascanio
    Description: Customized Profile for PowerShell
#>

#---------------------------------------------------------------
# Variables
#---------------------------------------------------------------
$Global:User = $env:USERNAME
$MaximumHistoryCount = 2KB
#---------------------------------------------------------------
# Functions
#---------------------------------------------------------------
Function Edit-Profile {
    $ISE = "$($PSHome)\PowerShell_ISE.exe"
    $ISEWorkDir = "$($PSHome)"
    Start-Process -FilePath $ISE -WorkingDirectory $ISEWorkDir -ArgumentList $profile
}

function Get-Time {
    Return $(get-date -ErrorAction SilentlyContinue | ForEach-Object { $_.ToLongTimeString() } )
}

function Resolve-ShortenedPath() {
    <#
.SYNOPSIS
    Shortens a path
.DESCRIPTION
    Shorten a path to a very simple format
.PARAMETER path
    The Path to shorten
.NOTES
    Name: Shorten-Path
    Author: Unknown
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string]$path = $PWD.Path
    )
    $loc = $path.Replace($HOME, '~')
    # remove prefix for UNC paths
    $loc = $loc -replace '^[^:]+::', ''
    # make path shorter like tabs in Vim,
    # handle paths starting with \\ and . correctly
    return ($loc -replace '\\(\.?)([^\\])[^\\]*(?=\\)', '\$1$2')
}

function prompt {
    <#
    .SYNOPSIS
        Prompt for PowerShell
    .DESCRIPTION
        Custom Prompt for PowerShell
    .NOTES
        Name: prompt
        Author: Joseph Ascanio

        DateModified: 2019.07.22 - Changing the icon preceeding the >> depending on what
                                    folder we are in.
    #>
    #- Prompt Variables
    $time = Get-Time
    $domain = $env:USERDNSDOMAIN
    $User = $env:USERNAME
    $curDir = (Get-Location).Path
    $lambda = [char]0x03BB
    $homedir = [char]0x00002302
    $gitdir = [char]0x000021A3
    $darrow = [char]0xBB

    #- Color Variables
    $cdelim = [ConsoleColor]::Gray
    $chost = [ConsoleColor]::Green
    $cloc = [ConsoleColor]::Cyan
    $ctim = [ConsoleColor]::DarkGray
    $cpath = [ConsoleColor]::DarkCyan
    $csep = [ConsoleColor]::Red
    $clam = [ConsoleColor]::Yellow

    #- Build the Prompt
    write-host "$time | " -n -f $ctim
    write-host "$User" -n -f $cloc
    write-host "@" -n -f $csep
    write-host $domain -n -f $chost
    write-host ' | ' -n -f $cdelim
    write-host $curDir -n -f $cpath
    write-host '' -f $cdelim
    #- This will change the default LAMBDA symbol to a
    #- house symbol if we are in a home directory
    If (($curDir -like "*$($env:USERPROFILE)*") -or
        ($curDir -like "*$($env:HOMEDRIVE)$($env:HOMEPATH)*") -or
        ($curDir -like "*$($env:HOMESHARE)*") -or
        ($curDir -like 'Microsoft.PowerShell.Core\FileSystem::\\mac\home*')) {
        Write-Host "$homedir " -n -f $clam
    }
    #- This will change the default LAMBDA symbol to a
    #- symbol that kinda of reminds me of merging code
    #- if we are in a directory that contains a .git folder
    ElseIf (Test-Path -Path "$($curDir)\.git" -ErrorAction SilentlyContinue) {
        Write-Host "$gitdir " -n -f $clam
    }
    Else {
        write-host "$lambda " -n -f $clam
    }

    write-host "$darrow " -n

    #- Return a space to avoid PS>
    return ' '
}

function Get-DriveInfo {
    <#
.SYNOPSIS
    Returns Drive Information
.DESCRIPTION
    Returns Drive Information for al drives
.NOTES
    Name: Get-DriveInfo
    Author: Unknown
.ALIASES
    df
#>
    if ($PSVersionTable.PSVersion.Major -lt 4) {
        $colItems = Get-wmiObject -Class "Win32_LogicalDisk" -Namespace "root\CIMV2" -ComputerName $env:COMPUTERNAME
    }
    else {
        $colItems = Get-CimInstance -ClassName "Win32_LogicalDisk" -Namespace "root\CIMV2" -ComputerName $env:COMPUTERNAME
    }


    foreach ($objItem in $colItems) {
        Write-Output $objItem.DeviceID $objItem.Description $objItem.FileSystem ($objItem.Size / 1GB).ToString("f3") ($objItem.FreeSpace / 1GB).ToString("f3")
    }
}

function cdd {
    <#
.SYNOPSIS
    Pull a list on ever directory change
.DESCRIPTION
    Pull a list on ever directory change
.NOTES
    Name: cdd
    Author: Joseph Ascanio
.ALIASES
    cd
#>
    param(
        [Parameter(Mandatory = $false)]
        [string]$path = "."
    )
    if (Test-Path $path) {
        $path = Resolve-Path $path
        Set-Location $path
        Get-ChildItem -Path $path -Force
    }
    else {
        Write-Error "Could not find path $path"
    }
}

Function Get-DriveInfo {
    <#
    .SYNOPSIS
        Returns Drive Information
    .DESCRIPTION
        Returns Drive Information for all drives
    .PARAMETER ComputerName
        Aliases: 'Hostname','cn','Name'
        Parameter Values: Mandatory=$false,
                        ValueFromPipeline=$True,
                        ValueFromPipelineByPropertyName=$True,
                        HelpMessage="The. Computer. Name."
        Parameter Type: Array of Strings
        Define a device or list of devices by Hostname,CN,or Name
        to get drive information for.
    .OUTPUT
        System.Management.Automation
    .NOTES
        Name: Get-DriveInfo
        Author: Joseph Ascanio
    .ALIASES
        df
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "The. Computer. Name.")]
        [Alias('Hostname', 'cn', 'Name')]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    Process {
        foreach ($computer in $ComputerName) {
            Try {
                $Session = New-CimSession -ComputerName $computer -ErrorAction Stop
                $Drives = Get-CimInstance -CimSession $Session -ClassName Win32_LogicalDisk

                foreach ($drive in $Drives) {
                    $properties = @{ComputerName = $computer
                        ComputerStatus           = 'Connected'
                        DeviceID                 = $drive.DeviceID
                        Description              = $drive.Description
                        FileSystem               = $drive.FileSystem
                        Size                     = ($drive.Size / 1GB).ToString("f3")
                        FreeSpace                = ($drive.FreeSpace / 1GB).ToString("f3")
                        Compressed               = $drive.Compressed
                        DriveType                = $drive.DriveType
                        VolumeName               = $drive.VolumeName
                    }
                    $obj = New-Object -TypeName psobject -Property $properties
                    Write-Output $obj
                }
            }
            Catch {
                $properties = @{ComputerName = $computer
                    ComputerStatus           = 'Could Not Connect'
                    DeviceID                 = $Null
                    Description              = $Null
                    FileSystem               = $Null
                    Size                     = $Null
                    FreeSpace                = $Null
                    Compressed               = $Null
                    DriveType                = $Null
                    VolumeName               = $Null
                }
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
            }
        }
    }
}

function cdd {
    <#
.SYNOPSIS
    Pull a list on ever directory change
.DESCRIPTION
    Pull a list on ever directory change
.NOTES
    Name: cdd
    Author: Joseph Ascanio
.ALIASES
    cd
#>
    [cmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true
        )]
        [string]$path = "."
    )
    Process {
        if (Test-Path $path) {
            $path = Resolve-Path $path
            Set-Location $path
            Get-ChildItem -Path $path -Force
        }
        else {
            Write-Error "Could not find path $path"
        }
    }
}

function Get-DriveSpace {
    <#
.SYNOPSIS
    Get Drive space
.DESCRIPTION
    Get Drive space for all available drives
.PARAMETER Computer
    Devices to get Drive space on
.NOTES
    Name: Get-DriveSpace
    Author: Joseph Ascanio
#>
    [cmdletBinding()]
    param(
        [parameter(
            mandatory = $false,
            ValueFromPipeline = $true
        )]
        [string]$Computer = "."
    )

    Process {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter drivetype=3 -ComputerName $Computer | ForEach-Object {
            $OutputObject = New-Object -TypeName psobject
            $OutputObject | Add-Member -MemberType NoteProperty -Name Drive -Value $_.DeviceID
            $OutputObject | Add-Member -MemberType NoteProperty -Name VolumeName -Value $_.VolumeName
            $OutputObject | Add-Member -MemberType NoteProperty -Name TotalSize -Value ([Math]::Round(($_.Size / 1GB)))
            $OutputObject | Add-Member -MemberType NoteProperty -Name FreeSpace -Value ([Math]::Round(($_.FreeSpace / 1GB)))
            $OutputObject | Add-Member -MemberType NoteProperty -Name PercentFree -Value ([Math]::Round((($_.FreeSpace / $_.size) * 100)))
            Return $OutputObject
        }
    }
} #close drivespace

function Get-FolderSizes {
    <#
.SYNOPSIS
    Get the size of folders
.DESCRIPTION
    Get the size of folders in the directory
.PARAMETER Path
    The path to get folder sizes from
.PARAMETER SizeMB
    Specify if yo uwant the size in MB
.PARAMETER ExcludeFolder
    Folders to Exclude from the Get
.NOTES
    Name: Get-FolderSizes
    Author: Unknown
.ALIASES
    gfs
#>
    [cmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        $SizeMB,
        [Parameter(Mandatory = $false)]
        [string]$ExcludeFolder
    ) #close param

    Process {

        if (!(Test-Path $Path)) {
            Throw "Invalid path. Wants gci's -path parameter."
            Break
        }

        $objectFSO = New-Object -ComObject Scripting.FileSystemObject
        $Parents = Get-ChildItem $Path -Force | Where-Object { $_.PSisContainer -and $_.Name -ne $ExcludeFolder }
        $Folders = Foreach ($folder in $parents) {
            $getFolder = $objectFSO.getFolder( $folder.fullname.tostring() )
            if (!$getFolder.Size) {
                #for "special folders" like appdata
                $lengthSum = ChildItem $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | `
                    Measure-Object -Sum length -ErrorAction SilentlyContinue | Select-Object -ExpandProperty sum
                $sizeMBs = "{0:N0}" -f ($lengthSum / 1mb)
            } #close if size property is null
            else { $sizeMBs = "{0:N0}" -f ($getFolder.size / 1mb) }
            #else {$sizeMBs = [int]($getFolder.size /1mb) }
            New-Object -TypeName psobject -Property @{
                name   = $getFolder.path;
                sizeMB = $sizeMBs
            } #close new obj property
        } #close foreach folder

        #here's the output
        $Folders | Sort-Object @{E = { [decimal]$_.sizeMB } } -Descending | ? { [decimal]$_.sizeMB -gt $SizeMB } | Format-Table -AutoSize
        #calculate the total including contents
        $sum = $Folders | Select-Object -ExpandProperty sizeMB | Measure-Object -Sum | Select-Object -ExpandProperty sum
        $sum += ( Get-ChildItem $Path | Measure-Object -Property length -Sum | Select-Object -ExpandProperty sum ) / 1mb
        $sumString = "{0:n2}" -f ($sum / 1kb)
        $sumString + " GB total"
    }
} #end function

function bye {
    <#
.SYNOPSIS
    Alternative Exit that saves history
.DESCRIPTION
    Alternative Exit that saves history to a csv that get's imported at start
.NOTES
    Name: bye
    Author: Unknown
#>
    Get-History -Count 1KB | Export-CSV ~\WindowsPowerShell\History\History.csv
    stop-process -Id $PID
}

Function Replace-TabsWithSpace {
    <#
        .SYNOPSIS
            Replaces a tab character with 4 spaces
        .DESCRIPTION
            This function examines the selected text in the PSIE SelectedText property and every tab
            character that is found is replaced with 4 spaces.
        .PARAMETER SelectedText
            The current contents of the SelectedText property
        .PARAMETER InstallMenu
            Specifies if you want to install this as a PSIE add-on menu
        .EXAMPLE
            Replace-TabsWithSpace -InstallMenu $true

            Description
            -----------
            Installs the function as a menu item.
        .NOTES
            This was written specifically for me, I had some code originally created in Notepad++ that
            used actual tabs, later I changed that to spaces, but on occasion I come accross something
            that doesn't tab shift like it should. Since I've been doing some PowerShell ISE stuff lately
            I decided to write a little function that works as an Add-On menu.
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#Replace-TabsWithSpace
    #>
    [CmdletBinding()]
    Param
    (
        $SelectedText = $psISE.CurrentFile.Editor.SelectedText,
        $InstallMenu
    )
    Begin {
        if ($InstallMenu) {
            Write-Verbose "Try to install the menu item, and error out if there's an issue."
            try {
                $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("Replace Tabs with Space", { Replace-TabsWithSpace }, "Ctrl+Alt+R") | Out-Null
            }
            catch {
                Return $Error[0].Exception
            }
        }
    }
    Process {
        Write-Verbose "Try and find the tab character in the selected PSISE text, return an error if there's an issue."
        try {
            $psISE.CurrentFile.Editor.InsertText($SelectedText.Replace("`t", "    "))
        }
        catch {
            Return $Error[0].Exception
        }
    }
    End {
    }
}

Function New-CommentBlock {
    <#
        .SYNOPSIS
            Inserts a full comment block
        .DESCRIPTION
            This function inserts a full comment block that is formatted the
            way I format all my comment blocks.
        .PARAMETER InstallMenu
            Specifies if you want to install this as a PSIE add-on menu
        .EXAMPLE
            New-CommentBlock -InstallMenu $true

            Description
            -----------
            Installs the function as a menu item.
        .NOTES
            FunctionName : New-CommentBlock
            Created by   : Jeff Patton
            Date Coded   : 09/13/2011 12:28:10
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#New-CommentBlock
    #>
    [CmdletBinding()]
    Param
    (
        $InstallMenu
    )
    Begin {
        $WikiPage = ($psISE.CurrentFile.DisplayName).Substring(0, ($psISE.CurrentFile.DisplayName).IndexOf("."))
        $CommentBlock = @(
            "    <#`r`n"
            "       .SYNOPSIS`r`n"
            "       .DESCRIPTION`r`n"
            "       .PARAMETER`r`n"
            "       .EXAMPLE`r`n"
            "       .NOTES`r`n"
            "           FunctionName : `r`n"
            "           Created by   : $($env:username)`r`n"
            "           Date Coded   : $(Get-Date)`r`n"
            "       .LINK`r`n"
            "           https://code.google.com/p/mod-posh/wiki/$($WikiPage)`r`n"
            "    #>`r`n")
        if ($InstallMenu) {
            Write-Verbose "Try to install the menu item, and error out if there's an issue."
            try {
                $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("Insert comment block", { New-CommentBlock }, "Ctrl+Alt+C") | Out-Null
            }
            catch {
                Return $Error[0].Exception
            }
        }
    }
    Process {
        if (!$InstallMenu) {
            Write-Verbose "Don't insert a comment if we're installing the menu"
            try {
                Write-Verbose "Create a new comment block, return an error if there's an issue."
                $psISE.CurrentFile.Editor.InsertText($CommentBlock)
            }
            catch {
                Return $Error[0].Exception
            }
        }
    }
    End {
    }
}

Function New-Script {
    <#
        .SYNOPSIS
            Create a new blank script
        .DESCRIPTION
            This function creates a new blank script based on my original template.ps1
        .PARAMETER InstallMenu
            Specifies if you want to install this as a PSIE add-on menu
        .PARAMETER ScriptName
            This is the name of the new script.
        .EXAMPLE
            New-Script -ScriptName "New-ImprovedScript"

            Description
            -----------
            This example shows calling the function with the ScriptName parameter
        .EXAMPLE
            New-Script -InstallMenu $true

            Description
            -----------
            Installs the function as a menu item.
        .NOTES
            FunctionName : New-Script
            Created by   : Jeff Patton
            Date Coded   : 09/13/2011 13:37:24
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#New-Script
    #>
    [CmdletBinding()]
    Param
    (
        $InstallMenu,
        $ScriptName
    )
    Begin {
        $TemplateScript = @(
            "<#`r`n"
            "   .SYNOPSIS`r`n"
            "       Template script`r`n"
            "   .DESCRIPTION`r`n"
            "       This script sets up the basic framework that I use for all my scripts.`r`n"
            "   .PARAMETER`r`n"
            "   .EXAMPLE`r`n"
            "   .NOTES`r`n"
            "       ScriptName : $($ScriptName)`r`n"
            "       Created By : $($env:Username)`r`n"
            "       Date Coded : $(Get-Date)`r`n"
            "       ScriptName is used to register events for this script`r`n"
            "       LogName is used to determine which classic log to write to`r`n"
            "`r`n"
            "       ErrorCodes`r`n"
            "           100 = Success`r`n"
            "           101 = Error`r`n"
            "           102 = Warning`r`n"
            "           104 = Information`r`n"
            "   .LINK`r`n"
            "       https://code.google.com/p/mod-posh/wiki/Production/$($ScriptName)`r`n"
            "#>`r`n"
            "[CmdletBinding()]`r`n"
            "Param`r`n"
            "   (`r`n"
            "`r`n"
            "   )`r`n"
            "Begin`r`n"
            "   {`r`n"
            "       `$ScriptName = `$MyInvocation.MyCommand.ToString()`r`n"
            "       `$LogName = `"Application`"`r`n"
            "       `$ScriptPath = `$MyInvocation.MyCommand.Path`r`n"
            "       `$Username = `$env:USERDOMAIN + `"\`" + `$env:USERNAME`r`n"
            "`r`n"
            "       New-EventLog -Source `$ScriptName -LogName `$LogName -ErrorAction SilentlyContinue`r`n"
            "`r`n"
            "       `$Message = `"Script: `" + `$ScriptPath + `"``nScript User: `" + `$Username + `"``nStarted: `" + (Get-Date).toString()`n"
            "       Write-EventLog -LogName `$LogName -Source `$ScriptName -EventID `"104`" -EntryType `"Information`" -Message `$Message`r`n"
            "`r`n"
            "       #    Dotsource in the functions you need.`r`n"
            "       }`r`n"
            "Process`r`n"
            "   {`r`n"
            "       }`r`n"
            "End`r`n"
            "   {`r`n"
            "       `$Message = `"Script: `" + `$ScriptPath + `"``nScript User: `" + `$Username + `"``nFinished: `" + (Get-Date).toString()`n"
            "       Write-EventLog -LogName `$LogName -Source `$ScriptName -EventID `"104`" -EntryType `"Information`" -Message `$Message    `r`n"
            "       }`r`n")
        if ($InstallMenu) {
            Write-Verbose "Try to install the menu item, and error out if there's an issue."
            try {
                $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("New blank script", { New-Script }, "Ctrl+Alt+S") | Out-Null
            }
            catch {
                Return $Error[0].Exception
            }
        }

    }
    Process {
        if (!$InstallMenu) {
            Write-Verbose "Don't create a script if we're installing the menu"
            try {
                Write-Verbose "Create a new blank tab for the script"
                $NewScript = $psISE.CurrentPowerShellTab.Files.Add()
                Write-Verbose "Create a new empty script, return an error if there's an issue."
                $NewScript.Editor.InsertText($TemplateScript)
                $NewScript.Editor.InsertText(($NewScript.Editor.Select(22, 1, 22, 2) -replace " ", ""))
                $NewScript.Editor.InsertText(($NewScript.Editor.Select(26, 1, 26, 2) -replace " ", ""))
                $NewScript.Editor.InsertText(($NewScript.Editor.Select(40, 1, 40, 2) -replace " ", ""))
                $NewScript.Editor.InsertText(($NewScript.Editor.Select(43, 1, 43, 2) -replace " ", ""))
                $NewScript.Editor.Select(1, 1, 1, 1)
                if ($ScriptName.Substring(($ScriptName.Length) - 4, 4) -ne ".ps1") {
                    $ScriptName += ".ps1"
                }
                Write-Verbose "Change encoding from Unicode BigEndian to ASCII"
                $psISE.CurrentFile.GetType().GetField("Encoding", "NonPublic,Instance").SetValue($psISE.CurrentFile, [text.encoding]::ASCII)
                $NewScript.SaveAs("$((Get-Location).Path)\$($ScriptName)")
            }
            catch {
                Return $Error[0].Exception
            }
        }
    }
    End {
        Return $NewScript
    }
}

Function New-Function {
    <#
        .SYNOPSIS
            Create a new function
        .DESCRIPTION
            This function creates a new function that wraps the selected text inside
            the Process section of the body of the function.
        .PARAMETER SelectedText
            Currently selected code that will become a function
        .PARAMETER InstallMenu
            Specifies if you want to install this as a PSIE add-on menu
        .PARAMETER FunctionName
            This is the name of the new function.
        .EXAMPLE
            New-Function -FunctionName "New-ImprovedFunction"

            Description
            -----------
            This example shows calling the function with the FunctionName parameter
        .EXAMPLE
            New-Function -InstallMenu $true

            Description
            -----------
            Installs the function as a menu item.
        .NOTES
            FunctionName : New-Function
            Created by   : Jeff Patton
            Date Coded   : 09/13/2011 13:37:24
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#New-Function
    #>
    [CmdletBinding()]
    Param
    (
        $SelectedText = $psISE.CurrentFile.Editor.SelectedText,
        $InstallMenu,
        $FunctionName
    )
    Begin {
        $WikiPage = ($psISE.CurrentFile.DisplayName).Substring(0, ($psISE.CurrentFile.DisplayName).IndexOf("."))
        $TemplateFunction = @(
            "Function $FunctionName`r`n"
            "{`r`n"
            "   <#`r`n"
            "       .SYNOPSIS`r`n"
            "       .DESCRIPTION`r`n"
            "       .PARAMETER`r`n"
            "       .EXAMPLE`r`n"
            "       .NOTES`r`n"
            "           FunctionName : $FunctionName`r`n"
            "           Created by   : $($env:username)`r`n"
            "           Date Coded   : $(Get-Date)`r`n"
            "       .LINK`r`n"
            "           https://code.google.com/p/mod-posh/wiki/$($WikiPage)#$($FunctionName)`r`n"
            "   #>`r`n"
            "[CmdletBinding()]`r`n"
            "Param`r`n"
            "    (`r`n"
            "    )`r`n"
            "Begin`r`n"
            "{`r`n"
            "    }`r`n"
            "Process`r`n"
            "{`r`n"
            "$($SelectedText)`r`n"
            "    }`r`n"
            "End`r`n"
            "{`r`n"
            "    }`r`n"
            "}")
        if ($InstallMenu) {
            Write-Verbose "Try to install the menu item, and error out if there's an issue."
            try {
                $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("New function", { New-Function }, "Ctrl+Alt+S") | Out-Null
            }
            catch {
                Return $Error[0].Exception
            }
        }

    }
    Process {
        if (!$InstallMenu) {
            Write-Verbose "Don't create a function if we're installing the menu"
            try {
                Write-Verbose "Create a new empty function, return an error if there's an issue."
                $psISE.CurrentFile.Editor.InsertText($TemplateFunction)
            }
            catch {
                Return $Error[0].Exception
            }
        }
    }
    End {
    }
}
Register-ObjectEvent -InputObject $psISE.CurrentPowerShellTab.Files CollectionChanged -Action {
    <#
        .SYNOPSIS
            This command register an event handler for new files created within the ISE
        .DESCRIPTION
            The default encoding for PowerShell ISE is Unicode BigEndian, for some unknown
            reason, and for those of us who use version control systems, like Subversion,
            may have come across those files being set as binary.

            I got around this issue by creating a function to change the RepoProps attribute,
            but this solution is much more elegant. Once executed, this handler waits for a new
            file to be created, once that happens, it immediately sets the Encoding property
            to ASCII.
        .PARAMETER
        .EXAMPLE
        .NOTES
            Created by   : Richard Vantreas
            Date Coded   : 10/13/2011 12:06:31
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#Register-ObjectEvent
        .LINK
            http://poshcode.org/3000
    #>
    [CmdletBinding()]
    Param
    (
    )
    Begin {
    }
    Process {
        Write-Verbose "Iterate through ISEFile objects"
        $Event.Sender | foreach {
            Write-Verbose "Set private field which holds default encoding to ASCII"
            $_.GetType().GetField("Encodindg", "Nonpublic,Instance").SetValue($_, [text.encoding]::ASCII)
        }
    }
    End {
    }
}

Function Edit-File {
    <#
        .SYNOPSIS
            Open files in specified editor.
        .DESCRIPTION
            This function will open one or more files, in the specified editor.
        .PARAMETER FileSpec
            The filepath to open
        .EXAMPLE
            Edit-File -FileSpec c:\powershell\*.ps1
        .NOTES
            Set $Global:POSHEditor in your $profile to the path of your favorite
            text editor or to C:\Windows\notepad.exe. If that variable is not set
            we'll try and open the file in the PowerShell ISE otherwise give
            the user a polite message telling them what to do.
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#Edit-File
    #>
    Param
    (
        [Parameter(ValueFromPipeline = $true)]
        $FileSpec
    )
    Begin {
        $FilesToOpen = Get-ChildItem $Filespec
    }
    Process {
        Foreach ($File in $FilesToOpen) {
            Try {
                if ($POSHEditor -ne $null) {
                    Invoke-Expression "$POSHEditor $File"
                }
                else {
                    $psISE.CurrentPowerShellTab.Files.Add($File.FullName)
                }
            }
            Catch {
                if ((Get-Host).Name -eq 'Windows PowerShell ISE Host') {
                    Return $Error[0].Exception
                }
                else {
                    $Message = "You appear to be running in the console. "
                    $Message += "Please set `$Global:POSHEditor equalto the "
                    $Message += "path of your favorite text editor. Such as "
                    $Message += "`$Global:POSHEditor = c:\windows\notepad.exe `r`n"
                    $Message += "You can access your profile by typing 'notepad `$profile'"
                    Return $Message
                }
            }
        }
    }
    End {
    }
}

Function Save-All {
    <#
        .SYNOPSIS
            Save all unsaved files in the editor
        .DESCRIPTION
            This function will save all unsaved files in the editor
        .EXAMPLE
            Save-All

            Description
            -----------
            The only syntax for the command.
        .NOTES
            FunctionName : Save-All
            Created by   : jspatton
            Date Coded   : 02/13/2012 15:08:51

            Routinely I have a need to have open and be editing several files
            at once. Decided to write a function to save them all since there
            isn't one currently available.
        .LINK
            https://code.google.com/p/mod-posh/wiki/PSISELibrary#Save-All
    #>
    [CmdletBinding()]
    Param
    (
    )
    Begin {
        Write-Verbose "Check if we're in ISE"
        if ((Get-Host).Name -ne 'Windows PowerShell ISE Host') {
            Write-Verbose "Not in the ISE exiting."
            Return
        }
    }
    Process {
        Write-Verbose "Iterate through each tab"
        foreach ($PSFile in $psISE.CurrentPowerShellTab.Files) {
            Write-Verbose "Check if $($PSFile.DisplayName) is saved"
            if ($psfile.IsSaved -eq $false) {
                Write-Verbose "Saving $($PSFile.DisplayName)"
                $PSFile.Save()
            }

        }
    }
    End {
    }
}

#---------------------------------------------------------------
# PSDrives
#---------------------------------------------------------------

#---------------------------------------------------------------
# Aliases
#---------------------------------------------------------------

#---------------------------------------------------------------
# Filters
#---------------------------------------------------------------

#---------------------------------------------------------------
# Commands
#---------------------------------------------------------------

$psise.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Copy to Clipboard", { ~\WindowsPowerShell\Scripts\Set-ClipboardScript.ps1 }, "Ctrl+Alt+C") | Out-Null
Write-Output 'Configuration Complete. Executing beastmode.exe'
Write-Output 'BEAST MODE ENGAGED (╯°□°)╯︵ ┻━┻'
Set-Location D:\SourceControl\Scripts\PowerShell # - Change this if you want it to automatically cd into a directory of your choosing
# SIG # Begin signature block
# MIISEgYJKoZIhvcNAQcCoIISAzCCEf8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAFG8jNi5OF3u/bxukS808v05
# sCGggg+HMIIHejCCBWKgAwIBAgIKJh+WQwABAAFrCDANBgkqhkiG9w0BAQUFADBG
# MRMwEQYKCZImiZPyLGQBGRYDb3JnMRQwEgYKCZImiZPyLGQBGRYEcGJzbzEZMBcG
# A1UEAxMQcGJzby1IUTJQS0kwMy1DQTAeFw0xNTA3MDcxNTQ2MTBaFw0xODA3MDYx
# NTQ2MTBaMHoxEzARBgoJkiaJk/IsZAEZFgNvcmcxFDASBgoJkiaJk/IsZAEZFgRw
# YnNvMQ8wDQYDVQQLEwZQZW9wbGUxHzAdBgNVBAsTFkluZm9ybWF0aW9uIFRlY2hu
# b2xvZ3kxGzAZBgNVBAMTEkFzY2FuaW8sIEpvc2VwaCBKLjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALcVnWpky5/u20pnOq59M3T+cBe5bf2NgwcsbIgk
# UDxZ8JHN7nvZJMykBjcuR/GlbQFOwbXshN422g8+wJ4pjRTZ/bU5yMPLdmv0DPPZ
# OonR+fwxj1S2YyG91guVBApg6mmY9l/g+39CRRDjJAABcX+JQG+mUDnLPBsA4prr
# 8k7gLHK/f+/kkFsM7eLM8kzBC8XoLjMXV9WkHv9rDW+pEyRkt87qJuLVlD3EhLkU
# gJiEHEcljxHs3VjV3dlJk4BPg70cphWOR9Kay/NqeR+L+CM5LyPWQXqQqnQ+xmi+
# os16DkspAvY0tQAierRTIdx32UByb+leSpE2buAU+PZuXpkCAwEAAaOCAzQwggMw
# MD4GCSsGAQQBgjcVBwQxMC8GJysGAQQBgjcVCIbT1G+F+ZAMhYWTCYb2oiqH84Uz
# gQCFkPVjh7PKSgIBZQIBATATBgNVHSUEDDAKBggrBgEFBQcDAzALBgNVHQ8EBAMC
# B4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUg+WlQoKJ
# bVriotLFqn7MzS7ugqAwHwYDVR0jBBgwFoAUDgguvyZA+L79IzM84UQ0x4pBZdww
# gf8GA1UdHwSB9zCB9DCB8aCB7qCB64aBtWxkYXA6Ly8vQ049cGJzby1IUTJQS0kw
# My1DQSxDTj1IUTJQS0kwMyxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
# ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1wYnNvLERDPW9yZz9j
# ZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlz
# dHJpYnV0aW9uUG9pbnSGMWh0dHA6Ly9wa2kucGJzby5vcmcvQ2VydERhdGEvcGJz
# by1IUTJQS0kwMy1DQS5jcmwwggE8BggrBgEFBQcBAQSCAS4wggEqMIGsBggrBgEF
# BQcwAoaBn2xkYXA6Ly8vQ049cGJzby1IUTJQS0kwMy1DQSxDTj1BSUEsQ049UHVi
# bGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlv
# bixEQz1wYnNvLERDPW9yZz9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9
# Y2VydGlmaWNhdGlvbkF1dGhvcml0eTBSBggrBgEFBQcwAoZGaHR0cDovL3BraS5w
# YnNvLm9yZy9DZXJ0RGF0YS9IUTJQS0kwMy5wYnNvLm9yZ19wYnNvLUhRMlBLSTAz
# LUNBKDEpLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL3BraS5wYnNvLm9yZy9vY3Nw
# LzAtBgNVHREEJjAkoCIGCisGAQQBgjcUAgOgFAwSQXNjYW5pb0pKQHBic28ub3Jn
# MA0GCSqGSIb3DQEBBQUAA4ICAQBX/JGAZkgMXx6D3mJtn7KWOqcjbnkYlvbPFdCc
# 5GWFxtb5WXlRUdtEp4W7uPS4NFOL79rljw1gqJHHXqE8/HGLVC4VlJ34ncdJrLde
# 5enneARGnGJA2Z0QsO7XIsT4KhRzPSi+IGQtj2VazkXCwSL9Pr2F6KYfy8AXIiM9
# GNe5wZAPowK5Zc8l6fM3sYtUqpbtw7T/qXgQcA5Loumg65boiWkovjpQ89N9wbJW
# kEekGFPEZgFRPKxYSva89BOwdhVA+AbqaEk2kNZopd9LxKvsYRiBVv4dYOotW/lS
# cK6b6kICWT9K3J4AhYkYs6W4FrBrS3w6zBHJDtL4czP8FFwZrE+weqVvu6T1ZvmR
# nV/sgHODDwOKS0n0BRqE88oTH8fhNZFtRyzSpHNmh5dnU8D5OHuOFyL7uRtzcKBH
# oeeCQlZ0FuIOZl4RAB3n4FjISHIoEjEP+TWvBnQvtB9VKY81q266CXeSP/AlnkSK
# IJm3kBGM+u4Ng5X55TFZwQJmhygmpT1Jm8wxKpc7NshWl45B6nb/YmFOsczY0pMe
# k/xw7tBRBVwXoeqXS4+R4qLYJw1Vb4kpGFk4QJ1o8CDJHG1G9iGiyKGC/rSZAImm
# jt148P9YQMeRczHTYgd0LVapsvKTJMGehUodoo2GBZX2BDPQHiBTlAgasJgPj1tG
# kjmzZDCCCAUwggXtoAMCAQICCkygEKUAAAAAAHswDQYJKoZIhvcNAQEFBQAwRjET
# MBEGCgmSJomT8ixkARkWA29yZzEUMBIGCgmSJomT8ixkARkWBHBic28xGTAXBgNV
# BAMTEHBic28tSFEyUEtJMDEtQ0EwHhcNMTQxMTEzMjAwOTI5WhcNMTkxMTEyMjAw
# OTI5WjBGMRMwEQYKCZImiZPyLGQBGRYDb3JnMRQwEgYKCZImiZPyLGQBGRYEcGJz
# bzEZMBcGA1UEAxMQcGJzby1IUTJQS0kwMy1DQTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAK2r57hz3solvRX2rqTPYCNhfpWMmZ71BXMQFv8AWUjzttbE
# TKdooEx22L0eZkorjXf3BJQphjtszzCkXFUJqXNqkg9wOjCAXsKsziihcvXYmJCe
# kZT2pMinpIGFGGezylmB3AsrkCWufFDOZ6uDDfUmERTArjzzbPBGlrT47EtGssRJ
# LPrujG/vcLJqzTEIvzMg7s3cxW8MEikF5MmN7NIbauOTRzzC1nTT2gR+GoBmPmJ7
# jE08od/uIBv4pBUDdpfHH8NDUjsX5HbHFi8o3yK961XV4JdqQLru0PElhUO/IuhU
# /5uu3p6tzxLbMhlA2Q/e8aU8QPLB3aCLehk+5WZFFHw+pSimUzYJbPe8RU9Qh7gk
# 2i0QI4OK3pNZcTdzijorEidPq4dDqrb3fMkwGRbqCwqHjRFFIvPSdlHW25NjuiVc
# s9uXeLUOznHaejJRSkQSZ4mVTtoKLCyfYC47JHGJsKEHixD9YN52aiWUZUaowRQu
# 7/b7JYMY6uQl7+aX6qYg3882s6zhov27z7NT/pR3F2hJZRvr35fprngjtmnOb3CG
# sVuI2zqlbEHW11b0e/Dm47epOOZuUeNtAk5Oz9+Yy6ODYTDv4ZSVXkV0SJWlx9ty
# tj1XM67d5JBfsmDqOYMqOHw4m1rnEul67gkRdKVK/yTY4iFdbpTLLDWKe+7RAgMB
# AAGjggLzMIIC7zAQBgkrBgEEAYI3FQEEAwIBATAjBgkrBgEEAYI3FQIEFgQUuyfl
# ThglECsXuvW47t6DH23td5AwHQYDVR0OBBYEFA4ILr8mQPi+/SMzPOFENMeKQWXc
# MBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMB
# Af8EBTADAQH/MB8GA1UdIwQYMBaAFFC8VQK2g/OBYO3wVVbKJw2hXNCbMIH/BgNV
# HR8EgfcwgfQwgfGgge6ggeuGgbVsZGFwOi8vL0NOPXBic28tSFEyUEtJMDEtQ0Es
# Q049SFEyUEtJMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENO
# PVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9cGJzbyxEQz1vcmc/Y2VydGlm
# aWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1
# dGlvblBvaW50hjFodHRwOi8vcGtpLnBic28ub3JnL0NlcnREYXRhL3Bic28tSFEy
# UEtJMDEtQ0EuY3JsMIIBOQYIKwYBBQUHAQEEggErMIIBJzCBrAYIKwYBBQUHMAKG
# gZ9sZGFwOi8vL0NOPXBic28tSFEyUEtJMDEtQ0EsQ049QUlBLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# cGJzbyxEQz1vcmc/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRp
# ZmljYXRpb25BdXRob3JpdHkwTwYIKwYBBQUHMAKGQ2h0dHA6Ly9wa2kucGJzby5v
# cmcvQ2VydERhdGEvSFEyUEtJMDEucGJzby5vcmdfcGJzby1IUTJQS0kwMS1DQS5j
# cnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9wa2kucGJzby5vcmcvb2NzcC8wDQYJKoZI
# hvcNAQEFBQADggIBALi4axT9oPDqttuHXT1TCNPR560nhNR+uJI9NfLYj2FiYwDK
# mrSQyXV72tmfRbXrukNvPt3J2wEXyyqGFwZw9T8IYf1ipkysBNpqXkGlX+CnBwmw
# UZuGmgick+6tJ8LWG5x0n9GDIRw7pPIbzj/PeJTSNWVNQt1uA8MouhEJ/aJWHzbl
# t6+VprCANa1sOo+JSXTjx/pqJ1RpcCGg9nRay0p7L4dZWkTEI4Llo0MYdDXk/X89
# AsjmguGDTw1lt9ypKLHWw4unJkPZ4E+GGptKEOW7OHfVEjX7rgNFlTSdOEFVgX7y
# pYbraMjCrIFNRO/zFucsyyUBk3XaLGDGC1R0LqskFMCebbLeQHViC4IzumKsXdjq
# Z0PgARM4TlWRSKZEc7726uHEG04ToLVyWkX8Cn7TdAeVvt3vkvnNAvhMoZdur+B4
# bPrJR8vi1HZLOEwrfslF3I+C3QhBR2VBFbjTR+fAhLpnfuDTRZ8CZdrhBDuseVOa
# sp5kdgVLxUFIA+1TdGt+8BJsC422JWnnBv5zIIMB0ygaAf/PDr9wNhpJts2iv2oA
# jh5A1YBSBYXdjh5SGAUY7/gw8gwTtiM3V8ni3sh9b1Ui9/zV0hF3d42FK9OkqrNf
# fbaC0bb76xI3swygumG5D3FCKNxHcTdM0T8Y20HIQJBy/oRoVLekLGKWuwURMYIB
# 9TCCAfECAQEwVDBGMRMwEQYKCZImiZPyLGQBGRYDb3JnMRQwEgYKCZImiZPyLGQB
# GRYEcGJzbzEZMBcGA1UEAxMQcGJzby1IUTJQS0kwMy1DQQIKJh+WQwABAAFrCDAJ
# BgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAj
# BgkqhkiG9w0BCQQxFgQUfalwN7OOoCDMRdHVjvbmh4lZ9yswDQYJKoZIhvcNAQEB
# BQAEggEArNK33zKJIM3t64StdwEPp0Hjj2vnctdI1CAO0OoyLvV9y/JNQCR3AISb
# HK8aNnuMvL5Ee33WPpY/InKHjkDootlq9yU9uEmBS+fyl20NRDlLWKkPokHmBncr
# 5XTTJawEQ79As368W5Tic1ZYa9P6RJzIn8s7mIQCX4hUj3BB63LqvSwGL2jZazsT
# 0feScM/g64zI4fckzXkRPSV9eJ4dwVRnBnJ4/SfDcVR2Kf85LzlkEDv56yivcWUS
# oFneDFatuU3EQMSgorYjzu5azk6QzbbCmRjGOyINN7veWMW+1I3A4AkMb78aAA9m
# btjRts3EMyHIW9/Tj7vtJnSqBDkNLA==
# SIG # End signature block
