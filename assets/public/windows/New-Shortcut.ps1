Function New-Shortcut {
    <#
    .SYNOPSIS
        Create a shortcut on Public Desktop and or the Public Start Menu.
    .DESCRIPTION
        This script can be used to create shortcuts within Public Desktop, Public Start Menu, or under it's own folder in Public Start Menu.
    .PARAMETER Name

        Name of the shortcut to create. Requires an extension of either .LNK or .URL
        Validation: Name must end in LNK or URL
    .PARAMETER Description

        A description of the shortcut or the application the shortcut refers too. .URL shortcuts do not recieve a description.
        Alias: ShortcutDescription
    .PARAMETER Target

        Target Application, Directory, Website, etc... of the shortcut
        Validation: If not URL, target must exist.
    .PARAMETER WorkingDirectory

        Working Directory for the target
        Validation: If not URL, Directory must exist
    .PARAMETER Icon

        Icon to be used by the shortcut
        Validation: Icon file or refrence must exist.
    .PARAMETER Arguments

        Arguments to be added to the shortcut.
    .PARAMETER StartMenuFolder

        Name of folder to create in startmenu if applicable
    .PARAMETER SaveLocation

        Where to create the shortcut
        Validation Set: Desktop,StartMenu,Both
    .PARAMETER LogOutput

        Switch where true will log output to a file and false or not passed will not
    .PARAMETER LogDirectory

        Directory to save Transcript of events too
        Logfile will be called New-Shortcut_M-D-YYYY.log
        Default Directory is: C:\Windows\Logs
    .NOTES
        Version:        2.0
        Author:         Joseph Ascanio
        Creation Date:  09.11.2015
        Change 09.11.2015: Initial script development
        Change 09.12.2015: Created validation for parameters where necessary
        Change 09.12.2015: Created logic to create URL shortcuts
        Change 09.13.2015: Created logic to create LNK shortcuts
        Change 09.24.2015: Added console logging and header
        Change 02.05.2018: Re-named all the parameters, changed logging from
                            transcripting to standard out-file calls, moved
                            default log directory to a universal location,
                            fixed a bug in the SaveLocation for "Both" where
                            the Start Menu Folder would not be created and fail,
                            the whole script.

        Exit Codes:
        10004 - Failed to create the start menu folder
        10005 - Failed to create start menu shortcut
        10006 - Failed to create the desktop shortcut
        10007 - Failed to create both shorcuts

    .EXAMPLE

        .\new-shortcut.ps1 -Name 'TestShortcut.lnk' -Description 'This is a test.' -Target "$ENV:ProgramFiles\TestApplication\TestApp.exe" -WorkingDirectory "$ENV:ProgramFiles\TestApplication" -Icon "$ENV:ProgramFiles\TestApplication\icon.ico" -Arguments '-debug' -SaveLocation Desktop
        Will create a shortcut called "TestShortcut.lnk" on the %PUBLIC%\Desktop pointing to ProgramFiles\TestApplication\TestApp.exe
    .EXAMPLE

        .\new-shortcut.ps1 -Name 'TestShortcut.lnk' -Description 'This is a test.' -Target "$ENV:ProgramFiles\TestApplication\TestApp.exe" -WorkingDirectory "$ENV:ProgramFiles\TestApplication" -Icon "$ENV:ProgramFiles\TestApplication\icon.ico" -Arguments '-debug' -SaveLocation Desktop -logOutPut -LogDirectory "C:\Test\Log.log"
        Will create a shortcut called "TestShortcut.lnk" on the %PUBLIC%\Desktop pointing to ProgramFiles\TestApplication\TestApp.exe and log the output of the script to C:\Test\Log.Log
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $false)]
        [string]$Icon,
        [Parameter(Mandatory = $false)]
        [string]$Arguments,
        [Parameter(Mandatory = $false)]
        [string]$StartMenuFolder,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Desktop', 'StartMenu', 'Both')]
        [string]$SaveLocation
    )
    Begin {
        Write-Verbose 'Creating WScript.Shell object'
        $objShell = New-Object -ComObject WScript.Shell
    }
    Process {
        Switch ($SaveLocation) {
            'StartMenu' {
                if (($Name.ToLower()).EndsWith('url')) {
                    If ($StartMenuFolder) {
                        Write-Verbose "A Start folder was specified"
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs\$($StartMenuFolder)"
                        If (!(Test-Path -Path $sFolder -ErrorAction SilentlyContinue)) {
                            Write-Verbose "Specified start folder doesn't exist. Creating it."
                            Try {
                                New-Item -Path $sFolder -ItemType Directory -Force -ErrorAction SilentlyContinue
                            }
                            Catch {
                                Write-Error "Failed to create the start menu folder: $($Name)"
                                Exit(10004)
                            }
                        }
                    }
                    Else {
                        Write-Verbose "No Start folder was specified. Will put the shortcut in the root of programs."
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs"
                    }

                    $sSPath = Join-Path -Path $sFolder -ChildPath $Name
                    $Shortcut = $objShell.CreateShortcut("$sSPath")
                    $Shortcut.TargetPath = $Target

                    Write-Output 'Creating a shortcut in the Public Start Menu.'
                    Write-Verbose "Shortcut $($Name) will be created in $($sFolder)"
                    Write-Verbose "Shorcut $($Name) has a target of $($Target)."

                    Try {
                        $Shortcut.Save()
                        Write-Output "Successfully created the start menu shortcut $($Name)."
                        Exit(0)
                    }
                    Catch {
                        Write-Error "Failed to create start menu shortcut: $($Name)"
                        Exit(10005)
                    }
                }
                else {
                    If ($StartMenuFolder) {
                        Write-Verbose "A Start folder was specified"
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs\$($StartMenuFolder)"
                        If (!(Test-Path -Path $sFolder -ErrorAction SilentlyContinue)) {
                            Write-Verbose "Specified start folder doesn't exist. Creating it."
                            Try {
                                New-Item -Path $sFolder -ItemType Directory -Force -ErrorAction SilentlyContinue
                            }
                            Catch {
                                Write-Error "Failed to create the start menu folder: $($Name)"
                                Exit(10004)
                            }
                        }
                    }
                    Else {
                        Write-Verbose "No Start folder was specified. Will put the shortcut in the root of programs."
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs"
                    }

                    $sSPath = Join-Path -Path $sFolder -ChildPath $Name
                    $Shortcut = $objShell.CreateShortcut("$sSPath")
                    $Shortcut.TargetPath = $Target

                    Write-Output 'Creating a shortcut in the Public Start Menu.'
                    Write-Verbose "Shortcut $($Name) will be created in $($sFolder)"
                    Write-Verbose "Shorcut $($Name) has a target of $($Target)."

                    if ($Arguments -ne '') {
                        $Shortcut.Arguments = $Arguments
                        Write-Verbose 'Applying the following Arguments to the shortcut:'
                        Write-Verbose $Arguments
                    }

                    if ($Icon -ne '') {
                        $Shortcut.IconLocation = $Icon
                        Write-Verbose 'Applying the following Icon to the shorcut:'
                        Write-Verbose $Icon
                    }

                    if ($Description -ne '') {
                        $Shortcut.Description = $Description
                        Write-Verbose 'Applying the following description to the shorcut:'
                        Write-Verbose $Description
                    }

                    if ($WorkingDirectory -ne '') {
                        $Shortcut.WorkingDirectory = $WorkingDirectory
                        Write-Verbose 'Applying the following working directory to the shorcut:'
                        Write-Verbose $WorkingDirectory
                    }

                    Try {
                        $Shortcut.Save()
                        Write-Output "Successfully created the start menu shortcut $($Name)."
                        Exit(0)
                    }
                    Catch {
                        Write-Error "Failed to create start menu shortcut: $($Name)"
                        Exit(10005)
                    }
                }
            }

            'Desktop' {
                if (($Name.ToLower()).EndsWith('url')) {
                    $sSPath = Join-Path -Path "$env:PUBLIC\Desktop" -ChildPath $Name
                    $Shortcut = $objShell.CreateShortcut("$sSPath")
                    $Shortcut.TargetPath = $Target

                    Write-Output 'Creating a shortcut in the Public Start Menu.'
                    Write-Verbose "Shortcut $($Name) will be created in $($env:PUBLIC)\Desktop"
                    Write-Verbose "Shorcut $($Name) has a target of $($Target)."

                    Try {
                        $Shortcut.Save()
                        Write-Output "Successfully created the desktop shortcut: $($Name)."
                        Exit(0)
                    }
                    Catch {
                        Write-Error "Failed to create the desktop shortcut: $($Name)"
                        Exit(10006)
                    }
                }
                else {
                    $sSPath = Join-Path -Path "$env:PUBLIC\Desktop" -ChildPath $Name
                    $Shortcut = $objShell.CreateShortcut("$sSPath")
                    $Shortcut.TargetPath = $Target

                    Write-Output 'Creating a shortcut in the Public Start Menu.'
                    Write-Verbose "Shortcut $($Name) will be created in $($env:PUBLIC)\Desktop"
                    Write-Verbose "Shorcut $($Name) has a target of $($Target)."

                    if ($Arguments -ne '') {
                        $Shortcut.Arguments = $Arguments
                        Write-Verbose 'Applying the following Arguments to the shortcut:'
                        Write-Verbose $Arguments
                    }

                    if ($Icon -ne '') {
                        $Shortcut.IconLocation = $Icon
                        Write-Verbose 'Applying the following Icon to the shorcut:'
                        Write-Verbose $Icon
                    }

                    if ($Description -ne '') {
                        $Shortcut.Description = $Description
                        Write-Verbose 'Applying the following description to the shorcut:'
                        Write-Verbose $Description
                    }

                    if ($WorkingDirectory -ne '') {
                        $Shortcut.WorkingDirectory = $WorkingDirectory
                        Write-Verbose 'Applying the following working directory to the shorcut:'
                        Write-Verbose $WorkingDirectory
                    }

                    Try {
                        $Shortcut.Save()
                        Write-Output "Successfully created the desktop shortcut: $($Name)."
                        Exit(0)
                    }
                    Catch {
                        Write-Error "Failed to create the desktop shortcut: $($Name)"
                        Exit(10006)
                    }
                }
            }

            'Both' {
                if (($Name.ToLower()).EndsWith('url')) {
                    If ($StartMenuFolder) {
                        Write-Verbose "A Start folder was specified"
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs\$($StartMenuFolder)"
                        If (!(Test-Path -Path $sFolder -ErrorAction SilentlyContinue)) {
                            Write-Verbose "Specified start folder doesn't exist. Creating it."
                            Try {
                                New-Item -Path $sFolder -ItemType Directory -Force -ErrorAction SilentlyContinue
                            }
                            Catch {
                                Write-Error "Failed to create the start menu folder: $($Name)"
                                Exit(10004)
                            }
                        }
                    }
                    Else {
                        Write-Verbose "No Start folder was specified. Will put the shortcut in the root of programs."
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs"
                    }
                    $sSPath = Join-Path -Path $sFolder -ChildPath $Name
                    $sDPath = Join-Path -Path "$env:PUBLIC\Desktop" -ChildPath $Name
                    $ShortcutD = $objShell.CreateShortcut("$sDPath")
                    $ShortcutD.TargetPath = $Target
                    $ShortcutS = $objShell.CreateShortcut("$sSPath")
                    $ShortcutS.TargetPath = $Target

                    Write-Output 'Creating a shortcut in the Public Start Menu and the Public Desktop.'
                    Write-Verbose "Shortcut $($Name) will be created in $($sFolder)"
                    Write-Verbose "Shortcut $($Name) will be created in $($env:PUBLIC)\Desktop"
                    Write-Verbose "Shorcut $($Name) has a target of $($Target)."

                    Try {
                        $ShortcutS.Save()
                        Write-Output "Successfully created shortcut $($Name) in the Start Menu."

                        $ShortcutD.Save()
                        Write-Output "Successfully created shortcut $($Name) in on the Desktop."
                        Exit(0)
                    }
                    Catch {
                        If (Test-Path -Path $sSPath) {
                            If (Test-Path $sDPath) {
                                Write-Warning "Both shortcuts appear to have been created but an exception was thrown. Verify the shorctus are correct."
                                Exit(0)
                            }
                            else {
                                Write-Error "Failed to create shorcut $($Name) on the desktop."
                                Exit(10006)
                            }
                        }
                        else {
                            If (Test-Path -Path $sDPath) {
                                Write-Error "Failed to create shortcut $($Name) in the Start Menu."
                                Exit(10005)
                            }
                            else {
                                Write-Error "Failed to create either shorcut."
                                Exit(10007)
                            }
                        }
                    }
                }

                else {
                    If ($StartMenuFolder) {
                        Write-Verbose "A Start folder was specified"
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs\$($StartMenuFolder)"
                        If (!(Test-Path -Path $sFolder -ErrorAction SilentlyContinue)) {
                            Write-Verbose "Specified start folder doesn't exist. Creating it."
                            Try {
                                New-Item -Path $sFolder -ItemType Directory -Force -ErrorAction SilentlyContinue
                            }
                            Catch {
                                Write-Error "Failed to create the start menu folder:  $($Name)"
                                Exit(10004)
                            }
                        }
                    }
                    Else {
                        Write-Verbose "No Start folder was specified. Will put the shortcut in the root of programs."
                        $sFolder = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Microsoft\Windows\Start Menu\Programs"
                    }

                    $sSPath = Join-Path -Path $sFolder -ChildPath $Name
                    $sDPath = Join-Path -Path "$env:PUBLIC\Desktop" -ChildPath $Name
                    $ShortcutD = $objShell.CreateShortcut("$sDPath")
                    $ShortcutD.TargetPath = $Target
                    $ShortcutS = $objShell.CreateShortcut("$sSPath")
                    $ShortcutS.TargetPath = $Target

                    Write-Output 'Creating a shortcut in the Public Start Menu and the Public Desktop.'
                    Write-Verbose "Shortcut $($Name) will be created in $($sFolder)"
                    Write-Verbose "Shortcut $($Name) will be created in $($env:PUBLIC)\Desktop"
                    Write-Verbose "Shorcut $($Name) has a target of $($Target)."

                    if ($Arguments -ne '') {
                        $ShortcutD.Arguments = $Arguments
                        $ShortcutS.Arguments = $Arguments
                        Write-Verbose 'Applying the following Arguments to the shortcut:'
                        Write-Verbose $Arguments
                    }

                    if ($Icon -ne '') {
                        $ShortcutD.IconLocation = $Icon
                        $ShortcutS.IconLocation = $Icon
                        Write-Verbose 'Applying the following Icon to the shorcut:'
                        Write-Verbose $Icon
                    }

                    if ($Description -ne '') {
                        $ShortcutD.Description = $Description
                        $ShortcutS.Description = $Description
                        Write-Verbose 'Applying the following description to the shorcut:'
                        Write-Verbose $Description
                    }

                    if ($WorkingDirectory -ne '') {
                        $ShortcutD.WorkingDirectory = $WorkingDirectory
                        $ShortcutS.WorkingDirectory = $WorkingDirectory
                        Write-Verbose 'Applying the following working directory to the shorcut:'
                        Write-Verbose $WorkingDirectory
                    }


                    Try {
                        $ShortcutS.Save()
                        Write-Output "Successfully created shortcut $($Name) in the Start Menu."

                        $ShortcutD.Save()
                        Write-Output "Successfully created shortcut $($Name) in on the Desktop."
                        Exit(0)
                    }
                    Catch {
                        If (Test-Path -Path $sSPath) {
                            If (Test-Path $sDPath) {
                                Write-Warning "Both shortcuts appear to have been created but an exception was thrown. Verify the shorctus are correct."
                                Exit(0)
                            }
                            else {
                                Write-Error "Failed to create shorcut $($Name) on the desktop."
                                Exit(10006)
                            }
                        }
                        else {
                            If (Test-Path -Path $sDPath) {
                                Write-Error "Failed to create shortcut $($Name) in the Start Menu."
                                Exit(10005)
                            }
                            else {
                                Write-Error "Failed to create either shorcut."
                                Exit(10007)
                            }
                        }
                    }
                }
            }
        }
    }
    End {

    }
}