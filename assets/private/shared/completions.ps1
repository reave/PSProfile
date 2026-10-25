##- Registering Auto-Completion for Windows Terminal
#
# Each tool's completer lives in its own file under completions\ (named after the tool) in
# assets\private\shared or assets\private\<os>, plus config.json's NativeCompletions cached under
# assets\private\<os>\completions\native\ by Update-Completions. Tools with neither are answered
# by carapace (https://carapace.sh) when it is installed and knows the tool.
#
# None of the completer files is loaded here. Loading them all cost ~400 ms per shell (op.ps1
# alone is ~200 ms), and even checking which tools were installed cost a Get-Command per tool.
# Instead one dispatcher, Invoke-PSProfileNativeCompleter, answers the first Tab after a tool's
# name: it loads that tool's file, which registers the real completer, and answers with it. From
# then on the real completer is used directly.
#
# How the dispatcher is reached depends on the PowerShell version:
#   - 7.6+: one Register-ArgumentCompleter -NativeFallback, the catch-all PowerShell consults for
#     any native command that has no completer of its own. Nothing is enumerated at startup; the
#     list of completer files is built on the first Tab.
#   - 5.1 and 7.4/7.5: no catch-all exists, so the dispatcher is registered for every known tool
#     name in a single call (one call with N names costs ~1 ms; N calls cost ~0.3 ms each).
#     carapace only covers the tools Update-Completions found installed.

<#
.SYNOPSIS
    Returns the completer file for each tool, built once per session.
.DESCRIPTION
    Hand-written completers in assets/private/shared/completions and assets/private/<os>/
    completions (folders come lowest precedence first, so an OS file wins), plus whichever
    NativeCompletions caches Update-Completions has written. A NativeCompletions entry with no
    cache yet is skipped. Update-Completions resets the cache so new files are picked up.
.EXAMPLE
    (Get-PSProfileCompleterFile)['op']
.OUTPUTS
    System.Collections.Hashtable
#>
function Get-PSProfileCompleterFile {
    # A plain function, not [CmdletBinding()]: before 7.6 it runs at startup, and an advanced
    # function's first call costs ~3 ms more.
    param()

    if ($null -ne $Global:PSProfileLazyCompleterFiles) { return $Global:PSProfileLazyCompleterFiles }

    $files = @{}
    foreach ($folder in @(Get-PSProfileFunctionFolders -Root $Global:PSProfileRoot -Kind private -OSFolder $Global:PSProfileOSFolder)) {
        # [IO.Directory] rather than Get-ChildItem: this runs at startup before 7.6, and the
        # provider round trip costs ~20 ms more there.
        $dir = Join-Path $folder.Path 'completions'
        if (-not [IO.Directory]::Exists($dir)) { continue }
        foreach ($file in [IO.Directory]::GetFiles($dir, '*.ps1')) {
            $files[[IO.Path]::GetFileNameWithoutExtension($file)] = $file
        }
    }
    # config.json's NativeCompletions: tools with their own `completion powershell`-style
    # generator, whose output Update-Completions caches (running the generators here would mean
    # shelling out to each tool, e.g. a daemon-backed docker, on every load).
    foreach ($nc in $Global:PSProfileNativeCompletions) {
        $cache = [IO.Path]::Combine($Global:PSProfileNativeCompletionDir, "$($nc.Name).ps1")
        if ([IO.File]::Exists($cache)) { $files[$nc.Name] = $cache }
    }
    $Global:PSProfileLazyCompleterFiles = $files
    $files
}


<#
.SYNOPSIS
    The one native completer the profile registers; loads the completion code on first use.
.DESCRIPTION
    Hands each request to Invoke-PSProfileNativeCompletion (assets/lib/PSProfile.Completion.ps1),
    loading that file the first time. It routes a tool with a completer file to that file's
    completer, any other tool carapace knows to carapace, and gives no answer for anything else,
    so PowerShell's own completion (paths) runs as usual.
.PARAMETER WordToComplete
    Passed through from the completion engine.
.PARAMETER CommandAst
    Passed through from the completion engine.
.PARAMETER CursorPosition
    Passed through from the completion engine.
.EXAMPLE
    Invoke-PSProfileNativeCompleter -WordToComplete '' -CommandAst $ast -CursorPosition 3
.OUTPUTS
    System.Management.Automation.CompletionResult
#>
function Invoke-PSProfileNativeCompleter {
    param(
        [AllowEmptyString()][string]$WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    try {
        if (-not (Test-Path -Path Function:\Invoke-PSProfileNativeCompletion)) {
            Import-PSProfileScript -LiteralPath ([IO.Path]::Combine($Global:PSProfileRoot, 'assets', 'lib', 'PSProfile.Completion.ps1'))
        }
        Invoke-PSProfileNativeCompletion -WordToComplete $WordToComplete -CommandAst $CommandAst -CursorPosition $CursorPosition
    }
    catch { Write-Verbose "Native completion failed: $_" }
}

$Global:PSProfileLoadedCompleters = @{}
$Global:PSProfileLazyCompleterFiles = $null
$Global:PSProfileCarapace = $null
$Global:PSProfileOSFolder = $OSFolder
$Global:PSProfileNativeCompletionDir = [IO.Path]::Combine($Global:PSProfileRoot, 'assets', 'private', $OSFolder, 'completions', 'native')
$Global:PSProfileNativeCompletions = $PSProfileConfig.NativeCompletions
$Global:PSProfileCarapaceEnabled = $PSProfileConfig.Carapace -ne $false
$__nativeCompleter = { param($wordToComplete, $commandAst, $cursorPosition) Invoke-PSProfileNativeCompleter -WordToComplete $wordToComplete -CommandAst $commandAst -CursorPosition $cursorPosition }

if ($PSVersionTable.PSVersion -ge [version]'7.6') {
    Microsoft.PowerShell.Core\Register-ArgumentCompleter -NativeFallback -ScriptBlock $__nativeCompleter
}
else {
    # carapace's tools first, so a completer file for the same tool wins in the dispatcher's
    # lookup either way. Update-Completions keeps only the ones installed here.
    $__completerNames = (Get-PSProfileCompleterFile).Keys
    $__carapaceInstalled = [IO.Path]::Combine($Global:PSProfileNativeCompletionDir, 'carapace.installed.txt')
    if ($Global:PSProfileCarapaceEnabled -and [IO.File]::Exists($__carapaceInstalled)) {
        $__completerNames = @([IO.File]::ReadAllLines($__carapaceInstalled)) + @($__completerNames) | Where-Object { $_ }
    }
    if ($__completerNames) {
        Microsoft.PowerShell.Core\Register-ArgumentCompleter -Native -CommandName ([string[]]@($__completerNames)) -ScriptBlock $__nativeCompleter
    }
}
Remove-Variable -Name __nativeCompleter, __completerNames, __carapaceInstalled -ErrorAction Ignore
