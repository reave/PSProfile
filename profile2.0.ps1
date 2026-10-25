#- Set default settings for advanced cmdlets
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Completion
using namespace System.Management.Automation.Host
using namespace System.Management.Automation.Runspaces

#- Windows PowerShell 5.1 predates $IsWindows/$IsMacOS/$IsLinux, so every OS check below
#- would read $null and no functions would load. 5.1 only runs on Windows; define them there.
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $IsWindows = $true
    $IsMacOS = $false
    $IsLinux = $false
}

#---------------------------------------------------------------
# Load timing (opt-in)
#---------------------------------------------------------------
# Set $env:PSPROFILE_TRACE = 1 before starting a shell to print how long each section of this
# profile took. Rows stay in $Global:PSProfileTrace afterward, including work deferred until the
# first idle prompt (Phase 'Deferred'), which lands there a moment after the prompt appears.
$Global:PSProfileTrace = $null
if ($env:PSPROFILE_TRACE) {
    $Global:PSProfileTrace = [System.Collections.Generic.List[PSCustomObject]]::new()
    $Global:PSProfileTraceClock = [System.Diagnostics.Stopwatch]::StartNew()
    $Global:PSProfileTraceLastMark = 0
}

<#
.SYNOPSIS
    Records a timing row for a profile section when PSPROFILE_TRACE is set.
.DESCRIPTION
    Without -Milliseconds, the row's time is everything since the previous mark, so calling
    this at the end of each section times that section. Pass -Milliseconds to record a
    duration measured separately (e.g. deferred work). A no-op when tracing is off.
.PARAMETER Section
    Name of the section being recorded.
.PARAMETER Phase
    'Load' for work done before the prompt appears, 'Deferred' for work done after.
.PARAMETER Milliseconds
    An explicit duration to record instead of the time since the previous mark.
.EXAMPLE
    Add-PSProfileTrace -Section 'Modules'
.OUTPUTS
    None
#>
function Add-PSProfileTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Section,
        [string]$Phase = 'Load',
        [double]$Milliseconds = -1
    )

    if ($null -eq $Global:PSProfileTrace) { return }
    $now = $Global:PSProfileTraceClock.Elapsed.TotalMilliseconds
    if ($Milliseconds -lt 0) {
        $Milliseconds = $now - $Global:PSProfileTraceLastMark
        $Global:PSProfileTraceLastMark = $now
    }
    $Global:PSProfileTrace.Add([PSCustomObject]@{ Phase = $Phase; Section = $Section; Ms = [math]::Round($Milliseconds, 1) })
}

#- Set Filters

<#
.SYNOPSIS
    Filters pipeline input to items with a Length at or below a given size.
.DESCRIPTION
    Intended for use after Get-ChildItem to filter files by size.
.PARAMETER size
    The maximum size, in bytes, an item's Length may be to pass the filter.
.EXAMPLE
    Get-ChildItem | FileSizeBelow 1MB
.OUTPUTS
    System.IO.FileSystemInfo
#>
filter FileSizeBelow($size) { if ($_.length -le $size) { $_ } }

<#
.SYNOPSIS
    Filters pipeline input to items with a Length at or above a given size.
.DESCRIPTION
    Intended for use after Get-ChildItem to filter files by size.
.PARAMETER size
    The minimum size, in bytes, an item's Length must be to pass the filter.
.EXAMPLE
    Get-ChildItem | FileSizeAbove 1MB
.OUTPUTS
    System.IO.FileSystemInfo
#>
filter FileSizeAbove($size) { if ($_.Length -ge $size) { $_ } }

<#
.SYNOPSIS
    Filters pipeline input to items with a Length within a given range.
.DESCRIPTION
    Intended for use after Get-ChildItem to filter files by size.
.PARAMETER min
    The minimum size, in bytes, an item's Length must be to pass the filter.
.PARAMETER max
    The maximum size, in bytes, an item's Length may be to pass the filter.
.EXAMPLE
    Get-ChildItem | FileSizeBetween 1MB 10MB
.OUTPUTS
    System.IO.FileSystemInfo
#>
filter FileSizeBetween($min, $max) { if ($_.Length -ge $min -and $_.Length -le $max) { $_ } }

<#
.SYNOPSIS
    Escapes PowerShell special characters in a string.
.DESCRIPTION
    Backtick-escapes whitespace and characters PowerShell treats specially
    (#, @, $, ;, comma, quotes, braces, parens, backtick, pipe, angle brackets, &)
    so a value can be safely embedded in a command line, e.g. an oh-my-posh segment
    value passed through Invoke-Expression.
.EXAMPLE
    "some value" | __oh-my-posh_escapeStringWithSpecialChars
.OUTPUTS
    System.String
#>
filter __oh-my-posh_escapeStringWithSpecialChars {
    $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}

#---------------------------------------------------------------
# Configuration
#---------------------------------------------------------------

<#
.SYNOPSIS
    Loads the PSProfile JSON configuration.
.DESCRIPTION
    Looks for a personal config at assets\config\config.json, relative to this
    profile script's directory. If it isn't present, falls back to the checked-in
    assets\config\sample-config.json template and emits a warning. Returns $null
    if neither file exists or the JSON fails to parse, so callers should treat
    every setting as optional and supply a default.
.EXAMPLE
    $config = Get-PSProfileConfig
    $config.settings.MaximumHistoryCount
.OUTPUTS
    System.Management.Automation.PSCustomObject, or $null if no config could be loaded.
.NOTES
    Copy sample-config.json to config.json and edit it to customize this profile.
    config.json is gitignored so personal paths never get committed.
#>
function Get-PSProfileConfig {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $configPath = Join-Path $PSScriptRoot 'assets\config\config.json'
    $samplePath = Join-Path $PSScriptRoot 'assets\config\sample-config.json'

    $path = if (Test-Path -Path $configPath) { $configPath } else { $samplePath }
    if ($path -eq $samplePath -and (Test-Path -Path $samplePath)) {
        Write-Warning "assets\config\config.json not found - falling back to sample-config.json. Copy sample-config.json to config.json and adjust it for your machine."
    }

    if (-not (Test-Path -Path $path)) {
        Write-Warning "No profile config found at $path - continuing with built-in defaults."
        return $null
    }

    try {
        return Get-Content -Path $path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to load profile config from $path`: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Tests whether the current OS matches a config entry's OS field.
.DESCRIPTION
    Compares the running platform ($IsWindows/$IsMacOS/$IsLinux) against a
    comma-separated list of OS names from profile config, e.g. "Windows,MacOS".
    A blank value or the literal "All" matches every OS.
.PARAMETER OSField
    The OS field from a config entry (e.g. a Modules[] item), such as "Windows",
    "MacOS,Linux", or "All".
.EXAMPLE
    Test-PSProfileOSMatch -OSField 'Windows,MacOS'
.OUTPUTS
    System.Boolean
#>
function Test-PSProfileOSMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$OSField
    )

    if ([string]::IsNullOrWhiteSpace($OSField) -or $OSField -eq 'All') { return $true }
    $osList = $OSField -split '\s*,\s*'
    if ($IsWindows -and $osList -contains 'Windows') { return $true }
    if ($IsMacOS -and $osList -contains 'MacOS') { return $true }
    if ($IsLinux -and $osList -contains 'Linux') { return $true }
    return $false
}

$PSProfileConfig = Get-PSProfileConfig
$PSProfileSettings = $PSProfileConfig.settings

#- Set constants
$MaximumHistoryCount = if ($PSProfileSettings.MaximumHistoryCount) { $PSProfileSettings.MaximumHistoryCount } else { 8192 }

if ($PSProfileSettings.DefaultParameterValues) {
    foreach ($property in $PSProfileSettings.DefaultParameterValues.PSObject.Properties) {
        $PSDefaultParameterValues[$property.Name] = $property.Value
    }
}
Add-PSProfileTrace -Section 'Config'

#---------------------------------------------------------------
# Functions
#---------------------------------------------------------------
# Exposed so functions dot-sourced from assets\public\* (whose own $PSScriptRoot
# points at their own file, not this one) can still find the install root - e.g.
# Update-Profile's git pull.
Set-Variable -Name PSProfileRoot -Value $PSScriptRoot -Scope Global

$OSFolder = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' }

<#
.SYNOPSIS
    Lists the function folders the profile loads, lowest precedence first.
.DESCRIPTION
    assets/<public|private>/shared (functions common to every OS), if it exists, followed by
    assets/<public|private>/<os>. Loading in this order lets an OS-specific function override
    a shared one of the same name.
.PARAMETER Root
    The install directory.
.PARAMETER Kind
    'public' or 'private'.
.PARAMETER OSFolder
    'windows', 'macos' or 'linux'.
.EXAMPLE
    Get-PSProfileFunctionFolders -Root $PSScriptRoot -Kind public -OSFolder windows
.OUTPUTS
    System.Management.Automation.PSCustomObject (Name, Path)
#>
function Get-PSProfileFunctionFolders {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][ValidateSet('public', 'private')][string]$Kind,
        [Parameter(Mandatory)][string]$OSFolder
    )

    $kindPath = Join-Path (Join-Path $Root 'assets') $Kind
    foreach ($name in 'shared', $OSFolder) {
        $path = Join-Path $kindPath $name
        if ([System.IO.Directory]::Exists($path)) { [PSCustomObject]@{ Name = $name; Path = $path } }
    }
}

<#
.SYNOPSIS
    Returns the path of a profile cache file, outside the install directory.
.DESCRIPTION
    Caches live under $env:LOCALAPPDATA\PSProfile\cache on Windows and
    $env:XDG_CACHE_HOME/PSProfile (default ~/.cache/PSProfile) on macOS/Linux, so replacing the
    install directory (e.g. a zip update) can't leave a mismatched cache inside it. The file
    name includes a key derived from the install path, so separate installs don't collide.
    The folder isn't created here; writers create it.
.PARAMETER Root
    The install directory.
.PARAMETER Name
    Base name of the cache file.
.PARAMETER Extension
    File extension, including the dot.
.EXAMPLE
    Get-PSProfileCachePath -Root $PSScriptRoot -Name 'functions.windows' -Extension '.ps1'
.OUTPUTS
    System.String
#>
function Get-PSProfileCachePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Extension
    )

    $cacheRoot = if ($IsLinux -or $IsMacOS) {
        $base = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
        Join-Path $base 'PSProfile'
    }
    else {
        Join-Path (Join-Path $env:LOCALAPPDATA 'PSProfile') 'cache'
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $key = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Root.TrimEnd('\', '/').ToLowerInvariant()))).Replace('-', '').Substring(0, 12) }
    finally { $sha.Dispose() }
    Join-Path $cacheRoot "$Name.$key$Extension"
}

<#
.SYNOPSIS
    Fingerprints the .ps1 files in a set of function folders (names, sizes, modification times).
.DESCRIPTION
    Written to the function index's first line; a different value means a file was added,
    removed or changed since the index was generated, so it needs rebuilding.
.PARAMETER Folder
    Folders as returned by Get-PSProfileFunctionFolders.
.EXAMPLE
    Get-PSProfileFunctionSignature -Folder (Get-PSProfileFunctionFolders -Root $PSScriptRoot -Kind public -OSFolder windows)
.OUTPUTS
    System.String
#>
function Get-PSProfileFunctionSignature {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Folder
    )

    # Bump the format number when the placeholders' calling convention changes, so an index
    # written by an older version is rebuilt even though no function file changed.
    $entries = [System.Collections.Generic.List[string]]::new()
    $entries.Add('format 1')
    foreach ($entry in $Folder) {
        foreach ($file in [System.IO.DirectoryInfo]::new($entry.Path).GetFiles('*.ps1')) {
            $entries.Add(('{0}/{1}|{2}|{3}' -f $entry.Name, $file.Name, $file.Length, $file.LastWriteTimeUtc.Ticks))
        }
    }
    $entries.Sort([System.StringComparer]::Ordinal)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($entries -join "`n"))).Replace('-', '') }
    finally { $sha.Dispose() }
}

<#
.SYNOPSIS
    Dot-sources a script so what it defines ends up global, from inside a function.
.DESCRIPTION
    Dot-sourcing inside a function defines everything in that function's scope, where it
    disappears when the function returns. This dot-sources the script, then copies every
    function, alias and variable it defined to the global scope - the same result as the
    profile dot-sourcing it at load.
.PARAMETER LiteralPath
    The script to load.
.EXAMPLE
    Import-PSProfileScript -LiteralPath $path
.OUTPUTS
    None
#>
function Import-PSProfileScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LiteralPath
    )

    # Locals are __psp-prefixed so the script can't clobber them, and all exist before the
    # "before" snapshots so none is mistaken for something the script defined. A placeholder
    # called with -WhatIf/-Confirm passes those preferences down; loading must still happen.
    $WhatIfPreference = $false
    $ConfirmPreference = 'None'
    $__pspPath = $LiteralPath
    $__pspItem = $null
    $__pspFunctions = @{}
    $__pspAliases = @{}
    $__pspVariables = @{}
    foreach ($__pspItem in Get-ChildItem -Path Function:) { $__pspFunctions[$__pspItem.Name] = $__pspItem.ScriptBlock }
    foreach ($__pspItem in Get-ChildItem -Path Alias:) { $__pspAliases[$__pspItem.Name] = $__pspItem.Definition }
    foreach ($__pspItem in Get-Variable -Scope 0) { $__pspVariables[$__pspItem.Name] = $true }

    . $__pspPath

    foreach ($__pspItem in Get-ChildItem -Path Function:) {
        if (-not [object]::ReferenceEquals($__pspFunctions[$__pspItem.Name], $__pspItem.ScriptBlock)) {
            Set-Item -Path "Function:global:$($__pspItem.Name)" -Value $__pspItem.ScriptBlock -Force -WhatIf:$false
        }
    }
    foreach ($__pspItem in Get-ChildItem -Path Alias:) {
        if ($__pspAliases[$__pspItem.Name] -ne $__pspItem.Definition) {
            Set-Alias -Name $__pspItem.Name -Value $__pspItem.Definition -Scope Global -Force -WhatIf:$false
        }
    }
    foreach ($__pspItem in Get-Variable -Scope 0) {
        if (-not $__pspVariables.ContainsKey($__pspItem.Name) -and
            $__pspItem.Name -notmatch '^(__psp.*|_|PSItem|Matches|foreach|switch|input)$') {
            Set-Variable -Name $__pspItem.Name -Value $__pspItem.Value -Scope Global -Force -WhatIf:$false
        }
    }
}

<#
.SYNOPSIS
    Returns a lazily-loaded public function, loading its file first if needed.
.DESCRIPTION
    Called by a function's placeholder (see Update-PSProfileCache). Loads the file the
    function lives in, once, and returns the real function so the placeholder can hand its
    call over.
.PARAMETER Folder
    Function folder name under assets/public ('shared', 'windows', ...).
.PARAMETER File
    File name of the function's .ps1 in that folder.
.PARAMETER Name
    Name of the function.
.EXAMPLE
    Resolve-PSProfileLazyFunction -Folder windows -File 'gs.ps1' -Name 'gs'
.OUTPUTS
    System.Management.Automation.FunctionInfo
#>
function Resolve-PSProfileLazyFunction {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.FunctionInfo])]
    param(
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Name
    )

    $path = Join-Path (Join-Path $Global:PSProfilePublicRoot $Folder) $File
    $command = $ExecutionContext.InvokeCommand.GetCommand($Name, [System.Management.Automation.CommandTypes]::Function)
    if (-not $command -or $command.ScriptBlock.File -ne $path) {
        Import-PSProfileScript -LiteralPath $path
        $null = $Global:PSProfileLazyFunctionFiles.Remove("$Folder|$File")
        $command = $ExecutionContext.InvokeCommand.GetCommand($Name, [System.Management.Automation.CommandTypes]::Function)
    }
    if (-not $command -or $command.ScriptBlock.File -ne $path) {
        throw "Loading $path didn't define the function $Name."
    }
    $command
}

<#
.SYNOPSIS
    Loads not-yet-loaded public function files for ~40 ms, then queues itself again.
.DESCRIPTION
    Queued as deferred startup work in interactive shells, so a few seconds after the prompt
    appears every placeholder has been replaced by its real function - without ever blocking
    input for more than a moment at a time.
.EXAMPLE
    Import-PSProfileLazyFunctionBatch
.OUTPUTS
    None
#>
function Import-PSProfileLazyFunctionBatch {
    [CmdletBinding()]
    param()

    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    while ($Global:PSProfileLazyFunctionFiles.Count -gt 0 -and $clock.ElapsedMilliseconds -lt 40) {
        $folder, $file = $Global:PSProfileLazyFunctionFiles[0] -split '\|', 2
        $Global:PSProfileLazyFunctionFiles.RemoveAt(0)
        Import-PSProfileScript -LiteralPath (Join-Path (Join-Path $Global:PSProfilePublicRoot $folder) $file)
    }
    if ($Global:PSProfileLazyFunctionFiles.Count -gt 0) {
        Add-PSProfileDeferredTask -Name 'Preload functions' -Action ${function:Import-PSProfileLazyFunctionBatch}
    }
}

#- Public Functions (assets\public\<shared|windows|macos|linux>\*.ps1)
# Lazy-loaded by default: one generated index (see Update-PSProfileCache) defines a placeholder
# per function carrying the real one's help and parameters, and the real file is dot-sourced on
# first call - or, in an interactive shell, a little at a time once the prompt is idle. The index
# is rebuilt whenever it's missing or a function file changed; if that fails, or
# settings.LazyLoadFunctions is false in config.json, every file is dot-sourced as before.
$Global:PSProfilePublicRoot = Join-Path (Join-Path $PSScriptRoot 'assets') 'public'
$Global:PSProfileLazyFunctionFiles = [System.Collections.Generic.List[string]]::new()
$publicFolders = @(Get-PSProfileFunctionFolders -Root $PSScriptRoot -Kind public -OSFolder $OSFolder)
$publicFunctionsLoaded = $false
if ($PSProfileSettings.LazyLoadFunctions -ne $false) {
    try {
        $functionIndexPath = Get-PSProfileCachePath -Root $PSScriptRoot -Name "functions.$OSFolder" -Extension '.ps1'
        $functionIndexHeader = "# PSProfile function index: $(Get-PSProfileFunctionSignature -Folder $publicFolders)"
        $readHeader = {
            if (-not [System.IO.File]::Exists($functionIndexPath)) { return $null }
            $reader = [System.IO.StreamReader]::new($functionIndexPath)
            try { $reader.ReadLine() } finally { $reader.Dispose() }
        }
        if ((& $readHeader) -ne $functionIndexHeader) {
            $updateCacheScript = $publicFolders | ForEach-Object { Join-Path $_.Path 'Update-PSProfileCache.ps1' } |
                Where-Object { Test-Path -Path $_ } | Select-Object -Last 1
            . $updateCacheScript
            Update-PSProfileCache -Cache Functions
        }
        if ((& $readHeader) -eq $functionIndexHeader) {
            . $functionIndexPath
            $publicFunctionsLoaded = $true
        }
    }
    catch { Write-Warning "Couldn't use the profile's function index, so loading every function file directly instead: $_" }
}
if (-not $publicFunctionsLoaded) {
    foreach ($folder in $publicFolders) {
        foreach ($function in Get-ChildItem -Path $folder.Path -Filter '*.ps1') {
            try { . $function.FullName }
            Catch { Write-Error -Message "Failed to import $($function.Name)" }
        }
    }
}
Add-PSProfileTrace -Section 'Public functions'

#- Dot Source Private Functions (assets\private\<shared|windows|macos|linux>\*.ps1)
# An OS folder's file replaces a shared one of the same name. history.ps1 is PSReadLine
# key-handler setup, not functions - it's loaded in the PSReadLine section below, only for
# interactive shells.
$privateFiles = [ordered]@{}
foreach ($folder in Get-PSProfileFunctionFolders -Root $PSScriptRoot -Kind private -OSFolder $OSFolder) {
    foreach ($function in Get-ChildItem -Path $folder.Path -Filter '*.ps1') { $privateFiles[$function.Name] = $function }
}
$privateFiles.Remove('history.ps1')
Foreach ($function in $privateFiles.Values) {
    try { . $function.FullName }
    Catch { Write-Error -Message "Failed to import $($function.Name)" }
}
Add-PSProfileTrace -Section 'Private functions'

Enable-Tls12
Initialize-HomebrewPath
$IsInteractiveShell = Test-InteractiveShell

<#
.SYNOPSIS
    Tests whether a module is installed, without a full Get-Module -ListAvailable scan.
.DESCRIPTION
    Get-Module -ListAvailable reads the manifest of every module on $env:PSModulePath
    (15-30 ms per call here). A module that's imported, or has a folder of its name directly
    under a PSModulePath entry (how Install-Module lays modules out), is found with a few
    directory checks; only a miss falls back to the full scan, which also catches unusual
    layouts and folder-name case differences on case-sensitive filesystems.
.PARAMETER Name
    Module name.
.EXAMPLE
    Test-PSProfileModuleAvailable -Name Terminal-Icons
.OUTPUTS
    System.Boolean
#>
function Test-PSProfileModuleAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (Get-Module -Name $Name) { return $true }
    foreach ($modulePath in $env:PSModulePath -split [System.IO.Path]::PathSeparator) {
        if ($modulePath -and [System.IO.Directory]::Exists([System.IO.Path]::Combine($modulePath, $Name))) { return $true }
    }
    return [bool](Get-Module -Name $Name -ListAvailable -ErrorAction Ignore)
}

# Whether PSReadLine is usable: needed for its key handlers and options below, and because it is
# what raises the idle event that deferred startup work runs on.
$hasPSReadLine = $IsInteractiveShell -and (Test-PSProfileModuleAvailable -Name PSReadLine)

#---------------------------------------------------------------
# Deferred startup work
#---------------------------------------------------------------
# Work that only matters once someone is at the prompt (e.g. Terminal-Icons' file formatting) is
# queued with Add-PSProfileDeferredTask and run one task per PowerShell.OnIdle event, which
# PSReadLine raises while it waits for input - so the prompt appears first. Without PSReadLine,
# or when pwsh was started to run a command and exit (no prompt ever appears), the queue runs at
# the end of this profile instead, the same as if nothing had been deferred.

<#
.SYNOPSIS
    Tests whether this process was started only to run a command or script and exit.
.DESCRIPTION
    True when the process command line has -Command/-c, -CommandWithArgs/-cwa, -File/-f or
    -EncodedCommand/-e/-ec (or an unambiguous prefix of one) without an earlier -NoExit. Such a
    process never shows a prompt, so PSReadLine never goes idle to run deferred startup work.
.EXAMPLE
    Test-PSProfileCommandOnlyHost
.OUTPUTS
    System.Boolean
#>
function Test-PSProfileCommandOnlyHost {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # -NoExit has to come before -Command/-File, since those consume the rest of the line.
    foreach ($arg in [Environment]::GetCommandLineArgs() | Select-Object -Skip 1) {
        if ($arg -notmatch '^[-/](\w+)') { continue }
        $name = $Matches[1].ToLowerInvariant()
        if ($name.Length -ge 3 -and 'noexit'.StartsWith($name)) { return $false }
        foreach ($option in 'command', 'commandwithargs', 'cwa', 'file', 'encodedcommand', 'ec') {
            if ($option.StartsWith($name)) { return $true }
        }
    }
    return $false
}

<#
.SYNOPSIS
    Queues profile work to run once the prompt is idle.
.DESCRIPTION
    See "Deferred startup work" in profile2.0.ps1. Tasks run in the order they were added, one
    per idle event. A task's errors and warnings are written to the console when it runs.
.PARAMETER Name
    Label for the task, shown in $Global:PSProfileTrace and in any failure message.
.PARAMETER Action
    Script block to run. Runs in its own scope, so it should define anything meant to outlive it
    globally (Import-Module -Global, Set-Item function:global:..., etc.).
.PARAMETER Argument
    Optional single argument passed to Action.
.EXAMPLE
    Add-PSProfileDeferredTask -Name 'Import Terminal-Icons' -Action ${function:Import-PSProfileModule} -Argument 'Terminal-Icons'
.OUTPUTS
    None
#>
function Add-PSProfileDeferredTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        [object]$Argument
    )

    $Global:PSProfileDeferredTasks.Enqueue([PSCustomObject]@{ Name = $Name; Action = $Action; Argument = $Argument })
}

<#
.SYNOPSIS
    Runs the next queued deferred task.
.DESCRIPTION
    Called from the PowerShell.OnIdle event (Phase 'Deferred'), or in a loop at the end of the
    profile when nothing can be deferred (Phase 'Load'). When deferred, the task's error and
    warning streams are captured and written straight to the console - an event action's own
    output never reaches it - and the prompt is redrawn below them.
.PARAMETER Phase
    'Deferred' when called from the idle event, 'Load' when called during profile load.
.EXAMPLE
    while (Invoke-PSProfileDeferredTask -Phase Load) { }
.OUTPUTS
    System.Boolean. True if more tasks remain queued.
#>
function Invoke-PSProfileDeferredTask {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('Load', 'Deferred')][string]$Phase = 'Deferred'
    )

    if ($Global:PSProfileDeferredTasks.Count -eq 0) { return $false }
    $task = $Global:PSProfileDeferredTasks.Dequeue()
    $clock = [System.Diagnostics.Stopwatch]::StartNew()

    if ($Phase -eq 'Load') {
        try { $null = & $task.Action $task.Argument }
        catch { Write-Error "Profile step '$($task.Name)' failed: $_" }
    }
    else {
        $printed = $false
        try {
            foreach ($record in (& $task.Action $task.Argument 2>&1 3>&1)) {
                if ($record -is [System.Management.Automation.ErrorRecord]) { $Host.UI.WriteErrorLine("$record"); $printed = $true }
                elseif ($record -is [System.Management.Automation.WarningRecord]) { $Host.UI.WriteWarningLine("$record"); $printed = $true }
            }
        }
        catch { $Host.UI.WriteErrorLine("Profile step '$($task.Name)' failed: $_"); $printed = $true }
        if ($printed) {
            try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } catch { Write-Verbose "Could not redraw the prompt: $_" }
        }
    }

    Add-PSProfileTrace -Section $task.Name -Phase $Phase -Milliseconds $clock.Elapsed.TotalMilliseconds
    return $Global:PSProfileDeferredTasks.Count -gt 0
}

$Global:PSProfileDeferredTasks = [System.Collections.Generic.Queue[PSCustomObject]]::new()
$PSProfileDeferStartupWork = $hasPSReadLine -and -not (Test-PSProfileCommandOnlyHost)

#---------------------------------------------------------------
# Document Roots
#---------------------------------------------------------------
Set-Variable -Name MyDocs -Value ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) -Scope Global

$configuredOneDrivePath = $PSProfileSettings.OneDrivePath
if ($configuredOneDrivePath -and (Test-Path -Path $configuredOneDrivePath -ErrorAction SilentlyContinue)) {
    [string]$OneDriveRoot = $configuredOneDrivePath
}
elseif ($IsWindows -and (Test-Path -Path $env:USERPROFILE\OneDrive -ErrorAction SilentlyContinue)) {
    [string]$OneDriveRoot = "$env:USERPROFILE\OneDrive"
}
elseif (-not $IsWindows -and (Test-Path -Path "$env:HOME/OneDrive" -ErrorAction SilentlyContinue)) {
    [string]$OneDriveRoot = "$env:HOME/OneDrive"
}
else {
    [string]$OneDriveRoot = "OneDrive is not configured"
}
Add-PSProfileTrace -Section 'Environment and document roots'

#---------------------------------------------------------------
# Modules
#---------------------------------------------------------------
<#
.SYNOPSIS
    Imports one installed module from config.json's Modules list.
.DESCRIPTION
    Terminal-Icons re-exports its theme cache on every import with a non-atomic Export-Clixml,
    so two shells starting at once can read a half-written file ("Root element is missing").
    A named mutex makes concurrent profile loads take turns importing. Imports with -Global so
    the module lands in the session whether this runs during load or as deferred startup work.
.PARAMETER Name
    Name of the module to import.
.EXAMPLE
    Import-PSProfileModule -Name Terminal-Icons
.OUTPUTS
    None
#>
function Import-PSProfileModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $hasImportMutex = $false
    $importMutex = [System.Threading.Mutex]::new($false, 'PSProfile-ModuleImport')
    try {
        # A shell that died mid-import abandons the mutex; ownership still passes to us.
        try { $hasImportMutex = $importMutex.WaitOne(10000) }
        catch [System.Threading.AbandonedMutexException] { $hasImportMutex = $true }
        try { Import-Module -Name $Name -Global -ErrorAction Stop }
        catch {
            if ($Name -ne 'Terminal-Icons') { throw }
            # A shell closed mid-write still leaves a truncated theme file, and the module stops
            # before rewriting it, so every later load fails too. Drop unreadable files and retry
            # once; the module regenerates its built-in themes on import.
            $themeCacheBase = if ($IsLinux -or $IsMacOS) {
                if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { [IO.Path]::Combine($HOME, '.local', 'share') }
            }
            else { $env:APPDATA }
            $themeCachePath = [IO.Path]::Combine($themeCacheBase, 'powershell', 'Community', 'Terminal-Icons')
            foreach ($themeFile in Get-ChildItem -Path $themeCachePath -Filter '*.xml' -ErrorAction SilentlyContinue) {
                try { $null = Import-Clixml -Path $themeFile.FullName -ErrorAction Stop }
                catch { Remove-Item -LiteralPath $themeFile.FullName -Force }
            }
            Import-Module -Name $Name -Global -ErrorAction Stop
        }
    }
    catch { Write-Error "Unable to import $Name module: $($_.Exception.Message)" }
    finally {
        if ($hasImportMutex) { $importMutex.ReleaseMutex() }
        $importMutex.Dispose()
    }
}

# Modules that only matter once someone is at the prompt, imported after it appears (see
# "Deferred startup work" above). A config.json Modules entry can override this either way
# with "DeferImport": true/false.
$modulesDeferredByDefault = @('Terminal-Icons', 'Microsoft.WinGet.CommandNotFound')
$PSProfileMissingModules = [System.Collections.Generic.List[string]]::new()
foreach ($module in $PSProfileConfig.Modules) {
    if (-not (Test-PSProfileOSMatch -OSField $module.OS)) { continue }
    if ($module.PSVersionMajor -and $PSVersionTable.PSVersion.Major -lt [int]$module.PSVersionMajor) { continue }
    if ($module.PSVersionMajorMax -and $PSVersionTable.PSVersion.Major -gt [int]$module.PSVersionMajorMax) { continue }

    if (Test-PSProfileModuleAvailable -Name $module.Name) {
        $deferImport = if ($null -ne $module.DeferImport) { [System.Convert]::ToBoolean($module.DeferImport) }
        else { $modulesDeferredByDefault -contains $module.Name }
        if ($deferImport -and -not (Get-Module -Name $module.Name)) {
            Add-PSProfileDeferredTask -Name "Import $($module.Name)" -Action ${function:Import-PSProfileModule} -Argument $module.Name
        }
        else { Import-PSProfileModule -Name $module.Name }
    }
    else {
        # Installing is setup.ps1's / Update-Profile's job; startup only reports it (see the
        # update notice at the end of this file).
        $PSProfileMissingModules.Add($module.Name)
    }
}
Add-PSProfileTrace -Section 'Modules'

$IsElevated = if ($IsWindows) {
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
else {
    try { (id -u) -eq '0' } catch { $false }
}

#---------------------------------------------------------------
# Packages
#---------------------------------------------------------------
# config.json Packages are installed by setup.ps1 and Update-Profile, never at startup: probing
# each one with Get-Command on every load cost time, and package managers can prompt or hang.
# The background update check below detects missing packages instead.

#---------------------------------------------------------------
# Aliases
#---------------------------------------------------------------
foreach ($alias in $PSProfileConfig.Aliases) {
    New-Alias -Name $alias.Name -Value $alias.Value -Description $alias.Description -Force
}
Add-PSProfileTrace -Section 'Elevation check, packages and aliases'

#---------------------------------------------------------------
# PSReadLine
#---------------------------------------------------------------

# Key handlers. Loaded only here, not with the other private files: every Set-PSReadLine* call
# in it imports PSReadLine (~150 ms), which scripts, CI runners and editor hosts that dot-source
# this profile never use. Loaded before the config-driven options below so config.json wins.
if ($hasPSReadLine) {
    try { . "$PSScriptRoot\assets\private\$OSFolder\history.ps1" }
    catch { Write-Error -Message "Failed to import history.ps1: $_" }
}

$readlineConfig = $PSProfileSettings.PSReadLine
if ($hasPSReadLine -and $readlineConfig) {
    # Wrapped in try/catch: PredictionSource/PredictionViewStyle throw when the host
    # doesn't support virtual terminal processing (redirected output, some remote/CI shells).
    try {
        if ($readlineConfig.PredictionSource) { Set-PSReadLineOption -PredictionSource $readlineConfig.PredictionSource -ErrorAction Stop }
        if ($readlineConfig.PredictionViewStyle) { Set-PSReadLineOption -PredictionViewStyle $readlineConfig.PredictionViewStyle -ErrorAction Stop }
        if ($readlineConfig.EditMode) { Set-PSReadLineOption -EditMode $readlineConfig.EditMode -ErrorAction Stop }
        if ($readlineConfig.HistorySearchArrowKeys) {
            Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction Stop
            Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction Stop
        }
        if ($readlineConfig.FilterSecretsFromHistory) {
            # Keeps lines that look like they contain a secret out of PSReadLine's
            # plaintext on-disk history file. Doesn't stop the command from running.
            Set-PSReadLineOption -AddToHistoryHandler {
                param([string]$line)
                $line -notmatch '(?i)(password|secret|token|apikey|connectionstring)'
            } -ErrorAction Stop
        }
        if ($readlineConfig.Colors) {
            $colorTable = @{}
            foreach ($colorProperty in $readlineConfig.Colors.PSObject.Properties) { $colorTable[$colorProperty.Name] = $colorProperty.Value }
            Set-PSReadLineOption -Colors $colorTable -ErrorAction Stop
        }
    }
    catch { Write-Verbose "Skipping PSReadLine configuration: $_" }
}
Add-PSProfileTrace -Section 'PSReadLine'

#---------------------------------------------------------------
# Windows Section
#---------------------------------------------------------------
if ($IsWindows -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }
    Add-PSProfileTrace -Section 'Window title'

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Windows
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction Ignore)) {
            Invoke-Expression $splashCommand
        }
    }
    Add-PSProfileTrace -Section 'Splash screen'

    if ($PSProfileSettings.ShowElevatedWarning -and $IsElevated) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS CONSOLE IS AN ELEVATED CONSOLE.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated -and $IsElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
    Add-PSProfileTrace -Section 'Banners'

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
    Add-PSProfileTrace -Section 'oh-my-posh'
}
#---------------------------------------------------------------
# macOS Section
#---------------------------------------------------------------
ElseIf ($IsMacOS -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }
    Add-PSProfileTrace -Section 'Window title'

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.MacOS
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction Ignore)) {
            Invoke-Expression $splashCommand
        }
    }
    Add-PSProfileTrace -Section 'Splash screen'

    if ($PSProfileSettings.ShowElevatedWarning -and $IsElevated) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS SHELL IS RUNNING AS ROOT.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated -and $IsElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
    Add-PSProfileTrace -Section 'Banners'

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
    Add-PSProfileTrace -Section 'oh-my-posh'
}
#---------------------------------------------------------------
# Linux Section
#---------------------------------------------------------------
ElseIf ($IsLinux -and $IsInteractiveShell) {
    if ($PSProfileSettings.ShowWindowTitle) {
        Set-ProfileWindowTitle
    }
    Add-PSProfileTrace -Section 'Window title'

    if ($PSProfileSettings.ShowSplashScreen) {
        $splashCommand = $PSProfileSettings.SplashCommand.Linux
        if ($splashCommand -and (Get-Command -Name ($splashCommand -split '\s+')[0] -ErrorAction Ignore)) {
            Invoke-Expression $splashCommand
        }
    }
    Add-PSProfileTrace -Section 'Splash screen'

    if ($PSProfileSettings.ShowElevatedWarning -and $IsElevated) {
        Write-Host "--------------------------------------------" -ForegroundColor Red
        Write-Host "  THIS SHELL IS RUNNING AS ROOT.  " -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
    }

    if ($PSProfileSettings.RunUpdateHelpOnElevated -and $IsElevated) {
        Start-Job -Name "UpdateHelp" -ScriptBlock { Update-Help -Force -ErrorAction SilentlyContinue } -ErrorAction SilentlyContinue | Out-Null
    }

    if ($PSProfileSettings.ShowPSVersionBanner) {
        Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) - ExecutionPolicy: $(Get-ExecutionPolicy)" -ForegroundColor Yellow
    }
    Add-PSProfileTrace -Section 'Banners'

    if ($PSProfileSettings.PoshTheme -and (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
        $themePath = Resolve-PoshTheme -PoshTheme $PSProfileSettings.PoshTheme
        if ($themePath) {
            oh-my-posh init pwsh --config $themePath | Invoke-Expression
        }
        else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    }
    Add-PSProfileTrace -Section 'oh-my-posh'
}

#---------------------------------------------------------------
# Start deferred startup work
#---------------------------------------------------------------
# Swap the public function placeholders for the real functions while the prompt is idle, so
# nothing waits on loading a file later. Only when deferring: a shell that runs one command and
# exits is better off loading just the functions it calls.
if ($PSProfileDeferStartupWork -and $Global:PSProfileLazyFunctionFiles.Count -gt 0) {
    Add-PSProfileDeferredTask -Name 'Preload functions' -Action ${function:Import-PSProfileLazyFunctionBatch}
}

if ($Global:PSProfileDeferredTasks.Count -gt 0) {
    if ($PSProfileDeferStartupWork) {
        # -SupportEvent keeps this out of Get-EventSubscriber/Get-Job; the subscription removes
        # itself once the queue is empty.
        $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
            if (-not (Invoke-PSProfileDeferredTask -Phase Deferred)) {
                Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
            }
        }
    }
    else {
        while (Invoke-PSProfileDeferredTask -Phase Load) { }
    }
}

if ($Global:PSProfileTrace) {
    Add-PSProfileTrace -Section 'Total (load)' -Milliseconds $Global:PSProfileTraceClock.Elapsed.TotalMilliseconds
    $Global:PSProfileTrace | Format-Table -AutoSize | Out-Host
}

#---------------------------------------------------------------
# Update notice and background update check
#---------------------------------------------------------------
# Prints one line if the last background check found a newer version or missing dependencies.
# If that check is older than UpdateCheckIntervalHours (default 24, 0 turns it off), a new one
# starts in a background runspace: it never blocks the prompt, and its result shows on the next
# shell start. The check writes its verdict as a ready-to-print line (update-notice.txt), so this
# block parses nothing; the check itself lives in assets/lib/PSProfile.Lifecycle.ps1 and is only
# loaded inside that runspace. State lives outside the install dir, next to the other caches.
$updateCheckHours = if ($null -ne $PSProfileSettings.UpdateCheckIntervalHours) { [double]$PSProfileSettings.UpdateCheckIntervalHours } else { 24 }
if ($IsInteractiveShell -and -not $env:PSPROFILE_NO_UPDATE_CHECK) {
    # PSEdition Desktop = Windows PowerShell 5.1, which has no $IsWindows.
    $stateBase = if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { $env:LOCALAPPDATA } elseif ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
    $stateDir = [System.IO.Path]::Combine($stateBase, 'PSProfile')

    $updateNotices = [System.Collections.Generic.List[string]]::new()
    $noticePath = [System.IO.Path]::Combine($stateDir, 'update-notice.txt')
    if ($updateCheckHours -gt 0 -and [System.IO.File]::Exists($noticePath)) {
        $updateNotices.Add([System.IO.File]::ReadAllText($noticePath).Trim())
    }
    if ($PSProfileMissingModules.Count) { $updateNotices.Add("missing module(s) $($PSProfileMissingModules -join ', ')") }
    if ($updateNotices.Count) { Write-Host "PSProfile: $($updateNotices -join '; '). Run Update-Profile." -ForegroundColor Yellow }

    # A missing file reports 1601-01-01, so the first shell after install runs a check.
    $lastUpdateCheck = [System.IO.File]::GetLastWriteTimeUtc([System.IO.Path]::Combine($stateDir, 'update-state.json'))
    if ($updateCheckHours -gt 0 -and ([datetime]::UtcNow - $lastUpdateCheck).TotalHours -ge $updateCheckHours) {
        $updateCheck = [powershell]::Create()
        [void]$updateCheck.AddScript({
                param($Lifecycle, $InstallPath)
                . $Lifecycle
                $null = Test-PSProfileUpdate -InstallPath $InstallPath
            }).AddArgument([System.IO.Path]::Combine($PSScriptRoot, 'assets', 'lib', 'PSProfile.Lifecycle.ps1')).AddArgument($PSScriptRoot)
        $null = $updateCheck.BeginInvoke()
    }
}
