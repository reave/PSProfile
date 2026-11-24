function Edit-File {
    <#
    .SYNOPSIS
    Open a file in a detected editor/IDE/log viewer or in a specified one.

    .DESCRIPTION
    Edit-File autodetects installed editors, IDEs and log viewers (including CMTrace and CMPowerLogViewer),
    recommends an editor based on file type, and opens the file. You can list detected editors, choose one,
    or let the function pick the best match automatically.

    .PARAMETER Path
    Path to the file to open.

    .PARAMETER Editor
    Name or full path of the editor to use. If omitted the function auto-selects based on file type.

    .PARAMETER List
    When specified, lists detected editors and exits.

    .PARAMETER DetectOnly
    When specified, performs detection and recommended selection but does not launch anything.

    .PARAMETER Wait
    Waits for the editor process to exit before returning.

    .EXAMPLE
    Edit-File -Path .\example.log
    Edit-File -Path .\script.ps1 -Editor 'code'
    Edit-File -Path .\trace.log -List
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Position = 1)]
        [string]$Editor,

        [switch]$List,

        [switch]$DetectOnly,

        [switch]$Wait
    )

    begin {
        function Resolve-Executable {
            <#
            .SYNOPSIS
                Finds the full path of an executable by name.

            .DESCRIPTION
                Tries each name in turn and returns the first match. A name that looks like a path is returned
                if it exists. Otherwise the name is looked up with Get-Command, then searched for in Program
                Files, Program Files (x86), the per-user Programs and WindowsApps folders, the user's Start
                menu and the user profile folder, up to MaxDepth folders deep. A shortcut (.lnk) that matches
                is resolved to its target. Last, $env:LOCALAPPDATA\bin is checked. Returns $null if nothing is
                found.

            .PARAMETER Names
                One or more executable names or paths, in order of preference. When searching folders, a name
                without the .exe extension is also tried with it.

            .PARAMETER MaxDepth
                How many folder levels below each search folder to look in. The default is 2.

            .EXAMPLE
                Resolve-Executable -Names 'code', 'Code.exe' -MaxDepth 3

                Returns the path to Visual Studio Code if it's on the PATH or installed in one of the searched
                folders.
            #>
            param(
                [string[]]$Names,
                [int]$MaxDepth = 2
            )

            function Resolve-LnkTarget {
                <#
                .SYNOPSIS
                    Returns the target of a Windows shortcut (.lnk) file.

                .DESCRIPTION
                    Reads the shortcut with the WScript.Shell COM object and returns the full path of its target.
                    Returns $null if the shortcut can't be read or its target doesn't exist.

                .PARAMETER LinkPath
                    The path to the .lnk file.

                .EXAMPLE
                    Resolve-LnkTarget -LinkPath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Notepad++.lnk"

                    Returns the path of the program the shortcut opens.
                #>
                param([string]$LinkPath)
                try {
                    $w = New-Object -ComObject WScript.Shell
                    $shortcut = $w.CreateShortcut($LinkPath)
                    $target = $shortcut.TargetPath
                    if ($target -and (Test-Path $target)) { return (Resolve-Path -LiteralPath $target).ProviderPath }
                } catch { Write-Debug "Couldn't read the shortcut ${LinkPath}: $($_.Exception.Message)" }
                return $null
            }

            foreach ($name in $Names) {
                if (-not $name) { continue }

                # If name looks like a path, prefer it directly
                if ($name -match '[\\:]') {
                    try {
                        if (Test-Path $name) { return (Resolve-Path -LiteralPath $name).ProviderPath }
                    } catch { Write-Debug "Couldn't resolve ${name} as a path, so searching for it by name: $($_.Exception.Message)" }
                }

                # 1) If it's a simple command on PATH or an alias/function, Get-Command will find it
                try {
                    $cmd = Get-Command $name -ErrorAction SilentlyContinue
                    if ($cmd) {
                        $src = $cmd.Source
                        if ($src) { return $src }
                    }
                } catch { Write-Debug "Get-Command couldn't look up ${name}, so searching folders instead: $($_.Exception.Message)" }

                # Build candidate filenames (with/without .exe)
                $candidates = @($name)
                if ($name -notmatch '\.exe$') { $candidates += "$name.exe" }

                # 2) Check common machine-wide Program Files roots
                $programRoots = @()
                $pf = [Environment]::GetFolderPath('ProgramFiles')
                $pfx86 = ${env:ProgramFiles(x86)}
                if ($pf) { $programRoots += $pf }
                if ($pfx86) { $programRoots += $pfx86 }

                # 3) Add common per-user install locations
                if ($env:LOCALAPPDATA) {
                    $programRoots += Join-Path $env:LOCALAPPDATA 'Programs'                  # e.g. VSCode user install
                    $programRoots += Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'    # MS Store / App execution aliases
                }
                if ($env:APPDATA) {
                    $programRoots += Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'  # user start menu shortcuts
                }

                # 4) also consider user's profile (shallow search)
                if ($env:USERPROFILE) { $programRoots += $env:USERPROFILE }

                # De-duplicate roots and search them
                $seenRoots = @{}
                foreach ($root in $programRoots | Where-Object { $_ -and (Test-Path $_) }) {
                    if ($seenRoots.ContainsKey($root)) { continue }
                    $seenRoots[$root] = $true

                    foreach ($cand in $candidates) {
                        try {
                            # Use -Depth when available (PowerShell 7+). If not available, the call will still work in many environments.
                            $found = Get-ChildItem -Path $root -Filter $cand -Recurse -ErrorAction SilentlyContinue -Force -Depth $MaxDepth |
                                Select-Object -First 1
                            if ($found) {
                                if ($found.Extension -ieq '.lnk') {
                                    $target = Resolve-LnkTarget $found.FullName
                                    if ($target) { return $target }
                                } else {
                                    return $found.FullName
                                }
                            }
                        } catch {
                            # Fallback: check guessed direct path under the root
                            try {
                                $guess = Join-Path $root $cand
                                if (Test-Path $guess) { return (Resolve-Path -LiteralPath $guess).ProviderPath }
                            } catch { Write-Debug "Couldn't check $cand under ${root}: $($_.Exception.Message)" }
                        }
                    }
                }

                # 5) As a last-ditch user-scope check, look in PATH-like user-local directories
                try {
                    if ($env:LOCALAPPDATA) {
                        $localBin = Join-Path $env:LOCALAPPDATA 'bin'
                        if (Test-Path $localBin) {
                            foreach ($cand in $candidates) {
                                $p = Join-Path $localBin $cand
                                if (Test-Path $p) { return (Resolve-Path -LiteralPath $p).ProviderPath }
                            }
                        }
                    }
                } catch { Write-Debug "Couldn't search $env:LOCALAPPDATA\bin for ${name}: $($_.Exception.Message)" }
            }

            return $null
        }

        # Compose a catalog of editors to probe. Each entry: Name, ProbeNames, ArgsTemplate
        $catalog = @(
            @{ Name = 'Visual Studio (devenv)'; Probe = @('devenv.exe'); Args = '"{0}"' },
            @{ Name = 'VSCode'; Probe = @('code.exe'); Args = '-n "{0}"' },
            @{ Name = 'Notepad++'; Probe = @('notepad++.exe'); Args = '"{0}"' },
            @{ Name = 'Sublime Text'; Probe = @('sublime_text.exe'); Args = '"{0}"' },
            @{ Name = 'Atom'; Probe = @('atom.exe'); Args = '"{0}"' },
            @{ Name = 'IntelliJ/PyCharm'; Probe = @('idea64.exe', 'pycharm64.exe', 'idea.exe', 'pycharm.exe'); Args = '"{0}"' },
            @{ Name = 'PowerShell ISE'; Probe = @('powershell_ise.exe'); Args = '"{0}"' },
            @{ Name = 'Notepad'; Probe = @('notepad.exe'); Args = '"{0}"' },
            @{ Name = 'CMTrace'; Probe = @('CMTrace.exe', 'cmtrace.exe'); Args = '"{0}"' },
            @{ Name = 'CMPowerLogViewer'; Probe = @('CMPowerLogViewer.exe', 'CMPowerLogViewer.exe'); Args = '"{0}"' }
        )

        # Detect installed editors
        $detected = [System.Collections.Generic.List[psobject]]::new()
        foreach ($entry in $catalog) {
            $exe = Resolve-Executable -Names $entry.Probe -MaxDepth 3
            if ($exe) {
                $detected.Add([pscustomobject]@{
                        Name         = $entry.Name
                        Executable   = $exe
                        ArgsTemplate = $entry.Args
                        Key          = ([IO.Path]::GetFileNameWithoutExtension($exe)).ToLowerInvariant()
                    })
            }
        }

        # Always ensure Notepad is available as fallback if not detected above
        if (-not ($detected | Where-Object Name -EQ 'Notepad')) {
            $np = Resolve-Executable -Names @('notepad.exe') -MaxDepth 0
            if ($np) {
                $detected.Add([pscustomobject]@{ Name = 'Notepad'; Executable = $np; ArgsTemplate = '"{0}"'; Key = 'notepad' })
            }
        }

        # Also allow the literal editor string to be used as a direct executable later if full path supplied.
    }

    process {
        $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
        if (-not $resolvedPath) {
            Write-Error "Path '$Path' not found."
            return
        }
        $file = $resolvedPath.ProviderPath
        $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()

        if ($List) {
            $detected | Select-Object Name, Executable | Format-Table -AutoSize
            return
        }

        # Recommendation mapping by extension (ordered preference)
        $prefs = switch ($ext) {
            '.log' { @('CMTrace', 'CMPowerLogViewer', 'Notepad++', 'VSCode', 'Notepad') }
            '.etl' { @('CMTrace', 'CMPowerLogViewer', 'VSCode', 'Notepad') }
            '.ps1' { @('VSCode', 'PowerShell ISE', 'Notepad++', 'Notepad') }
            '.psm1' { @('VSCode', 'PowerShell ISE', 'Notepad++', 'Notepad') }
            '.psd1' { @('VSCode', 'PowerShell ISE', 'Notepad++', 'Notepad') }
            '.cs' { @('Visual Studio (devenv)', 'VSCode', 'Notepad++', 'Notepad') }
            '.sln' { @('Visual Studio (devenv)', 'VSCode') }
            '.py' { @('VSCode', 'IntelliJ/PyCharm', 'Notepad++', 'Notepad') }
            '.txt' { @('VSCode', 'Notepad++', 'Notepad') }
            '.json' { @('VSCode', 'Notepad++', 'Notepad') }
            default { @('VSCode', 'Notepad++', 'Notepad') }
        }

        function Find-DetectedByName($name) {
            <#
            .SYNOPSIS
                Finds a detected editor by name.

            .DESCRIPTION
                Searches the editors that Edit-File detected earlier and returns the first one whose name
                contains the given text, ignoring case, or whose key equals it. Returns $null when the name is
                empty or nothing matches.

            .PARAMETER name
                The editor name, or part of it, such as code or notepad++.

            .EXAMPLE
                Find-DetectedByName -name 'notepad++'

                Returns the detected Notepad++ entry, if Notepad++ was found.
            #>
            if (-not $name) { return $null }
            $lc = $name.ToLowerInvariant()
            return $detected |
                Where-Object { $_.Name.ToLowerInvariant() -like "*$lc*" -or $_.Key -eq $lc } |
                Select-Object -First 1
        }

        $chosen = $null

        if ($Editor) {
            # If user gave a path to exe, try to use it directly
            if (Test-Path $Editor) {
                $chosen = [pscustomobject]@{
                    Name         = [IO.Path]::GetFileNameWithoutExtension($Editor)
                    Executable   = (Resolve-Path -LiteralPath $Editor).ProviderPath
                    ArgsTemplate = '"{0}"'
                }
            } else {
                # try to match by name among detected
                $found = Find-DetectedByName $Editor
                if ($found) {
                    $chosen = $found
                } else {
                    # attempt to resolve as command on PATH
                    $exeFromCmd = Resolve-Executable -Names @( $Editor )
                    if ($exeFromCmd) {
                        $chosen = [pscustomobject]@{
                            Name         = [IO.Path]::GetFileNameWithoutExtension($exeFromCmd)
                            Executable   = $exeFromCmd
                            ArgsTemplate = '"{0}"'
                        }
                    } else {
                        Write-Error "Editor '$Editor' not found among detected editors and not resolvable on PATH."
                        return
                    }
                }
            }
        } else {
            # Auto-select from prefs
            foreach ($p in $prefs) {
                $cand = Find-DetectedByName $p
                if ($cand) { $chosen = $cand; break }
            }
            # If none matched from prefs, pick first detected as fallback
            if (-not $chosen -and $detected.Count -gt 0) {
                $chosen = $detected[0]
            }
        }

        if ($DetectOnly) {
            if ($chosen) {
                [PSCustomObject]@{
                    File              = $file
                    RecommendedEditor = $chosen.Name
                    Executable        = $chosen.Executable
                } | Format-List
            } else {
                Write-Output "No editor detected."
            }
            return
        }

        if (-not $chosen) {
            Write-Error "No editor available to open the file."
            return
        }

        # Prepare arguments and launch
        $argsStr = [String]::Format($chosen.ArgsTemplate, $file)

        # Use Start-Process with -ArgumentList split intelligently
        # If argsStr is a simple quoted path just pass it as single arg
        $argumentList = @()
        if ($argsStr -match '^\s*".*"\s*$') {
            $argumentList = , ($argsStr.Trim())
        } else {
            # naive split by space while preserving quoted segments
            $argumentList = [System.Management.Automation.Language.Parser]::ParseInput($argsStr, [ref]$null, [ref]$null) |
                ForEach-Object {
                    # Fallback: this will not always be perfect but works for typical cases
                    $_.End
                }
            # If parser approach fails, fallback to raw string
            if (-not $argumentList -or $argumentList.Count -eq 0) { $argumentList = , $argsStr }
        }

        try {
            if ($Wait) {
                Start-Process -FilePath $chosen.Executable -ArgumentList $argsStr -Wait -NoNewWindow:$false
            } else {
                Start-Process -FilePath $chosen.Executable -ArgumentList $argsStr
            }
        } catch {
            Write-Error "Failed to start editor '$($chosen.Name)' (`$($chosen.Executable)`): $_"
        }
    }
}
