##- Registering Auto-Completion for Windows Terminal
#
# Each tool's completer lives in its own file under completions\ (named after the tool) in
# assets\private\shared or assets\private\<os>, plus config.json's NativeCompletions cached under
# assets\private\<os>\completions\native\ by Update-Completions.
#
# None of them is loaded here. Loading them all cost ~400 ms per shell (op.ps1 alone is ~200 ms),
# and even checking which tools were installed cost a Get-Command per tool. Instead each tool
# gets a tiny native completer right away - harmless for a tool that isn't installed, since it
# only runs when that tool is being completed - and the first Tab after the tool's name loads
# its real completer file and answers with it. From then on the real completer is used.

<#
.SYNOPSIS
    Loads a tool's completer file and returns the completer script block it registers.
.DESCRIPTION
    There's no API to read back a registered native completer, so while the file loads,
    Register-ArgumentCompleter is shadowed by a function that records each script block
    registered for a command (and still registers it for real). Functions and variables the
    file defines are made global (see Import-PSProfileScript), as when it was dot-sourced from
    the profile. Results are cached in $Global:PSProfileLoadedCompleters.
.PARAMETER CommandName
    The tool being completed.
.EXAMPLE
    Import-PSProfileCompleter -CommandName op
.OUTPUTS
    System.Management.Automation.ScriptBlock
#>
function Import-PSProfileCompleter {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)][string]$CommandName
    )

    if ($Global:PSProfileLoadedCompleters.ContainsKey($CommandName)) { return $Global:PSProfileLoadedCompleters[$CommandName] }

    $captured = @{}
    function Register-ArgumentCompleter {
        [CmdletBinding()]
        param(
            [string[]]$CommandName,
            [string]$ParameterName,
            [scriptblock]$ScriptBlock,
            [switch]$Native
        )
        if (-not $ParameterName) { foreach ($name in $CommandName) { $captured[$name] = $ScriptBlock } }
        Microsoft.PowerShell.Core\Register-ArgumentCompleter @PSBoundParameters
    }

    Import-PSProfileScript -LiteralPath $Global:PSProfileLazyCompleterFiles[$CommandName]
    foreach ($name in $captured.Keys) { $Global:PSProfileLoadedCompleters[$name] = $captured[$name] }
    $Global:PSProfileLoadedCompleters[$CommandName]
}

<#
.SYNOPSIS
    The native completer registered up front for each tool; loads the real one on first use.
.PARAMETER CommandName
    The tool being completed.
.PARAMETER WordToComplete
    Passed through from the completion engine.
.PARAMETER CommandAst
    Passed through from the completion engine.
.PARAMETER CursorPosition
    Passed through from the completion engine.
.EXAMPLE
    Invoke-PSProfileLazyCompleter -CommandName op -WordToComplete '' -CommandAst $ast -CursorPosition 3
.OUTPUTS
    System.Management.Automation.CompletionResult
#>
function Invoke-PSProfileLazyCompleter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [AllowEmptyString()][string]$WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    try {
        $completer = Import-PSProfileCompleter -CommandName $CommandName
        if ($completer) { & $completer $WordToComplete $CommandAst $CursorPosition }
    }
    catch { Write-Verbose "Completer for $CommandName failed: $_" }
}

$Global:PSProfileLoadedCompleters = @{}
$Global:PSProfileLazyCompleterFiles = @{}
# Completer files live in assets/private/shared/completions, plus OS-only ones (e.g. wsl) in
# assets/private/<os>/completions; folders come lowest precedence first, so an OS file wins.
$__completerFolders = @(Get-PSProfileFunctionFolders -Root $Global:PSProfileRoot -Kind private -OSFolder $OSFolder)
foreach ($__folder in $__completerFolders) {
    foreach ($__completerFile in Get-ChildItem -Path (Join-Path $__folder.Path 'completions') -Filter '*.ps1' -File -ErrorAction Ignore) {
        $Global:PSProfileLazyCompleterFiles[$__completerFile.BaseName] = $__completerFile.FullName
    }
}
# config.json's NativeCompletions: tools with their own `completion powershell`-style generator,
# whose output Update-Completions caches (running the generators here would mean shelling out to
# each tool, e.g. a daemon-backed docker, on every load). A tool with no cache yet is skipped
# until Update-Completions has run.
foreach ($__nc in $PSProfileConfig.NativeCompletions) {
    $__ncCache = [IO.Path]::Combine($Global:PSProfileRoot, 'assets', 'private', $OSFolder, 'completions', 'native', "$($__nc.Name).ps1")
    if (Test-Path -Path $__ncCache) { $Global:PSProfileLazyCompleterFiles[$__nc.Name] = $__ncCache }
}
foreach ($__completerName in $Global:PSProfileLazyCompleterFiles.Keys) {
    $__quotedName = "'" + $__completerName.Replace("'", "''") + "'"
    Microsoft.PowerShell.Core\Register-ArgumentCompleter -Native -CommandName $__completerName -ScriptBlock ([scriptblock]::Create(
            "param(`$wordToComplete, `$commandAst, `$cursorPosition) Invoke-PSProfileLazyCompleter -CommandName $__quotedName -WordToComplete `$wordToComplete -CommandAst `$commandAst -CursorPosition `$cursorPosition"))
}
Remove-Variable -Name __completerFolders, __folder, __completerFile, __nc, __ncCache, __completerName, __quotedName -ErrorAction Ignore
