#- Native command completion: everything the completion dispatcher in
#- assets/private/shared/completions.ps1 needs once someone presses Tab. Kept out of that file so
#- startup doesn't parse it; Invoke-PSProfileNativeCompleter loads it on the first Tab after a
#- native command, and Update-Completions loads it for Get-PSProfileCarapaceName.

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

    Import-PSProfileScript -LiteralPath (Get-PSProfileCompleterFile)[$CommandName]
    foreach ($name in $captured.Keys) { $Global:PSProfileLoadedCompleters[$name] = $captured[$name] }
    $Global:PSProfileLoadedCompleters[$CommandName]
}

<#
.SYNOPSIS
    Loads a tool's real completer on first use and answers with it.
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

<#
.SYNOPSIS
    Returns the carapace executable and the tools it completes, or $null without carapace.
.DESCRIPTION
    Resolved on first use and cached in $Global:PSProfileCarapace. The tool list comes from
    carapace.names.txt, which Update-Completions writes; without that file it is read from
    `carapace --list --names` once per session. Set "Carapace": false in config.json to turn
    carapace off even when it is installed.
.EXAMPLE
    Get-PSProfileCarapace
.OUTPUTS
    System.Collections.Hashtable
#>
function Get-PSProfileCarapace {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if ($null -ne $Global:PSProfileCarapace) {
        if ($Global:PSProfileCarapace.Path) { return $Global:PSProfileCarapace }
        return $null
    }

    $Global:PSProfileCarapace = @{ Path = $null; Names = $null }
    if (-not $Global:PSProfileCarapaceEnabled) { return $null }
    $command = Get-Command -Name carapace -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $command) { return $null }

    $listPath = Join-Path $Global:PSProfileNativeCompletionDir 'carapace.names.txt'
    $names = if (Test-Path -LiteralPath $listPath) { Get-Content -LiteralPath $listPath } else { Get-PSProfileCarapaceName -Path $command.Source }
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $names) { if ($name) { [void]$set.Add($name.Trim()) } }

    $Global:PSProfileCarapace = @{ Path = $command.Source; Names = $set }
    $Global:PSProfileCarapace
}

<#
.SYNOPSIS
    Lists the tools a carapace executable has completers for.
.DESCRIPTION
    Uses `carapace --list --names`, falling back to `carapace --list` for releases without
    --names (JSON keyed by tool in newer releases, one "name  description" line per tool in
    older ones).
.PARAMETER Path
    The carapace executable.
.EXAMPLE
    Get-PSProfileCarapaceName -Path (Get-Command carapace).Source
.OUTPUTS
    System.String
#>
function Get-PSProfileCarapaceName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $names = @(& $Path --list --names 2>$null)
    if ($LASTEXITCODE -eq 0 -and $names.Count -gt 0) { return $names | Where-Object { $_ } }

    $text = (& $Path --list 2>$null | Out-String).Trim()
    if (-not $text) { return }
    if ($text.StartsWith('{')) { return ($text | ConvertFrom-Json).PSObject.Properties.Name }
    foreach ($line in $text -split "`r?`n") { ($line.Trim() -split '\s+')[0] }
}

<#
.SYNOPSIS
    Answers a completion request with carapace's completions for a tool.
.DESCRIPTION
    The same request carapace's own `carapace _carapace powershell` snippet makes, minus the
    snippet's per-Tab Get-Command/Get-Alias/Get-Variable dump into CARAPACE_SHELL_* variables
    (only used to complete shell builtins, and it costs hundreds of ms in a loaded session).
    Returns nothing when carapace fails, so PowerShell falls back to path completion, and an
    empty string when carapace answers with no candidates, as carapace's snippet does, so a flag
    that takes free text doesn't offer file names.
.PARAMETER CommandName
    The tool being completed.
.PARAMETER WordToComplete
    Passed through from the completion engine.
.PARAMETER CommandAst
    Passed through from the completion engine.
.PARAMETER CursorPosition
    Passed through from the completion engine.
.EXAMPLE
    Invoke-PSProfileCarapaceCompleter -CommandName git -WordToComplete 'che' -CommandAst $ast -CursorPosition 7
.OUTPUTS
    System.Management.Automation.CompletionResult
#>
function Invoke-PSProfileCarapaceCompleter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [AllowEmptyString()][string]$WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    $carapace = Get-PSProfileCarapace
    if (-not $carapace) { return }

    # Before 7.3, in Legacy mode, and for batch files in Windows mode (a carapace.cmd shim), an
    # '' argument is dropped instead of passed as empty.
    $legacyArgs = $PSVersionTable.PSVersion -lt [version]'7.3' -or $PSNativeCommandArgumentPassing -eq 'Legacy' -or
        ($PSNativeCommandArgumentPassing -eq 'Windows' -and $carapace.Path -match '\.(cmd|bat)$')
    $emptyArg = if ($legacyArgs) { '""' } else { '' }

    # The words up to the cursor, unquoted the same way carapace's snippet does.
    $words = [System.Collections.Generic.List[string]]::new()
    foreach ($element in $CommandAst.CommandElements) {
        if ($element.Extent.StartOffset -gt $CursorPosition) { break }
        $text = $element.Extent.Text
        if ($element.Extent.EndOffset -gt $CursorPosition) {
            $text = $text.Substring(0, $text.Length - ($element.Extent.EndOffset - $CursorPosition))
        }
        if ($text.StartsWith("'")) { $text = $text.Substring(1) }
        if ($text.EndsWith("'")) { $text = $text.Substring(0, $text.Length - 1) }
        if (-not $text) { $text = $emptyArg }
        $words.Add($text.Replace('`,', ','))
    }
    if ($words.Count -eq 0) { return }
    $words[0] = $CommandName
    if (-not $WordToComplete) { $words.Add($emptyArg) }

    $saved = @{}
    foreach ($name in 'CARAPACE_SHELL', 'CARAPACE_COLOR') { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    try {
        $env:CARAPACE_SHELL = 'powershell'
        # Windows PowerShell's console host doesn't render the ANSI styling carapace adds.
        if ($PSVersionTable.PSEdition -eq 'Desktop' -and $null -eq $saved['CARAPACE_COLOR']) { $env:CARAPACE_COLOR = '0' }
        $json = & $carapace.Path $CommandName powershell @words 2>$null | Out-String
        if ($LASTEXITCODE -ne 0 -or -not $json.Trim()) { return }
        # Not @(...): Windows PowerShell's ConvertFrom-Json emits a JSON array as one object,
        # and foreach enumerates either shape.
        $items = $json | ConvertFrom-Json
    }
    catch {
        Write-Verbose "carapace failed for ${CommandName}: $_"
        return
    }
    finally {
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }

    $esc = [string][char]27
    $results = foreach ($item in $items) {
        $completionText = [string]$item.CompletionText
        if (-not $completionText) { continue }
        $listItemText = [string]$item.ListItemText
        if (-not $listItemText.Trim()) { $listItemText = $completionText }
        $toolTip = [string]$item.ToolTip
        if (-not $toolTip) { $toolTip = ' ' }
        [System.Management.Automation.CompletionResult]::new(
            $completionText, $listItemText.Replace('`e[', "$esc["), 'ParameterValue', $toolTip.Replace('`e[', "$esc["))
    }
    if ($results) { $results } else { '' }
}

<#
.SYNOPSIS
    Works out which tool a native completion request is for.
.DESCRIPTION
    Follows an alias to its target (so `k` aliased to kubectl completes as kubectl), drops any
    directory, and drops a Windows executable extension, so ./tools/op.exe completes as op.
.PARAMETER CommandAst
    The command being completed.
.EXAMPLE
    Resolve-PSProfileCompleterName -CommandAst $ast
.OUTPUTS
    System.String
#>
function Resolve-PSProfileCompleterName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $CommandAst
    )

    $name = $CommandAst.GetCommandName()
    if (-not $name) { return }
    $alias = $ExecutionContext.InvokeCommand.GetCommand($name, [System.Management.Automation.CommandTypes]::Alias)
    if ($alias -and $alias.Definition) { $name = $alias.Definition }
    $name = [IO.Path]::GetFileName($name)
    $name -replace '\.(exe|cmd|bat|com)$', ''
}

<#
.SYNOPSIS
    Routes a native completion request to the right completer.
.DESCRIPTION
    A tool with a completer file (hand-written, or a cached NativeCompletions generator) gets that
    file's completer, loaded on first use. Any other tool carapace knows gets carapace. Anything
    else gets no answer, so PowerShell's own completion (paths) runs as usual.
.PARAMETER WordToComplete
    Passed through from the completion engine.
.PARAMETER CommandAst
    Passed through from the completion engine.
.PARAMETER CursorPosition
    Passed through from the completion engine.
.EXAMPLE
    Invoke-PSProfileNativeCompletion -WordToComplete '' -CommandAst $ast -CursorPosition 3
.OUTPUTS
    System.Management.Automation.CompletionResult
#>
function Invoke-PSProfileNativeCompletion {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    try {
        $name = Resolve-PSProfileCompleterName -CommandAst $CommandAst
        if (-not $name) { return }
        if ((Get-PSProfileCompleterFile).ContainsKey($name)) {
            Invoke-PSProfileLazyCompleter -CommandName $name -WordToComplete $WordToComplete -CommandAst $CommandAst -CursorPosition $CursorPosition
            return
        }
        $carapace = Get-PSProfileCarapace
        if ($carapace -and $carapace.Names.Contains($name)) {
            Invoke-PSProfileCarapaceCompleter -CommandName $name -WordToComplete $WordToComplete -CommandAst $CommandAst -CursorPosition $CursorPosition
        }
    }
    catch { Write-Verbose "Native completion failed: $_" }
}
