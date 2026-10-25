<#
.SYNOPSIS
    Rebuilds the caches the profile uses to start faster.
.DESCRIPTION
    The profile keeps generated files under a per-user cache folder - $env:LOCALAPPDATA\PSProfile\cache
    on Windows, $env:XDG_CACHE_HOME/PSProfile (default ~/.cache/PSProfile) on macOS/Linux - not
    in the install directory, so an update that replaces the install directory can't leave a
    half-matching cache behind. File names include a key derived from the install path, so
    two installs on one machine don't share caches.

    Every cache is checked on each load and rebuilt automatically when out of date, so this
    rarely needs running by hand; setup.ps1 and Update-Profile run it after an install or
    update so the first shell doesn't pay for the rebuild. It works without the profile loaded.

    Functions
        Dot-sourcing a file costs a fixed 6-9 ms on Windows whatever is in it (script-file
        checks such as antivirus scanning), so dot-sourcing ~120 public function files cost
        about a second per shell. Instead the profile dot-sources one generated index holding
        a placeholder per function, keyed on the function names found by parsing each file
        (nothing is run). A placeholder carries the real function's help and parameters - so
        Get-Help, syntax and tab completion work - and on its first call loads the real file
        and hands the call, arguments and pipeline input, over to it.

        Covers assets/public/<os> and, if present, assets/public/shared; on a function name
        clash the OS folder wins. Also in the index:
        - [Alias()] attributes on a function, registered so the alias works before first call.
        - Top-level alias statements (Remove-Item alias:\..., New-Alias, Set-Alias), copied as
          is so they still take effect at load: PowerShell resolves aliases before functions,
          so a function overriding a built-in alias needs the alias gone before its first call.
        - Files with any other top-level code, a script-level param block, dynamicparam
          blocks, filters or parse errors are dot-sourced as before, in case that code matters.
        Default parameter values and [ValidateScript()] are left off placeholders; the real
        function applies both once it runs.

    OhMyPosh
        What `oh-my-posh init pwsh` prints for the configured theme, so a shell can start the
        prompt without running oh-my-posh (~80 ms). Keyed on the oh-my-posh executable and
        theme file, and re-checked once a day. Also rewrites the theme copy that has
        PoshThemeOverrides applied, if those changed.

    The splash screen cache is not rebuilt here: it has to be captured in a console, so the
    profile refreshes it itself (see SplashCacheHours).

    ExecutionPolicy
        The effective execution policy shown in the version banner. Looking it up costs
        50-70 ms per shell; the banner shows the cached value and refreshes it once idle.

    Zoxide, Atuin
        The script `zoxide init powershell` / `atuin init powershell` prints, dot-sourced at
        startup instead of starting the tool. Keyed on the executable (path and modification
        time) and the init arguments, so updating the tool or changing its settings rebuilds
        it. Skipped when the tool isn't installed or is turned off in settings.
.PARAMETER Cache
    Which caches to rebuild. Default: all of them.
.EXAMPLE
    Update-PSProfileCache
.EXAMPLE
    Update-PSProfileCache -Cache Functions
.OUTPUTS
    None
#>
function Update-PSProfileCache {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Functions', 'OhMyPosh', 'ExecutionPolicy', 'Zoxide', 'Atuin')]
        [string[]]$Cache = @('Functions', 'OhMyPosh', 'ExecutionPolicy', 'Zoxide', 'Atuin')
    )

    # This file lives in <install>/assets/public/<os|shared>/.
    $root = if ($Global:PSProfileRoot) { $Global:PSProfileRoot } else { Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent }
    $osFolder = if ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' } else { 'windows' }

    # Standalone (e.g. from setup.ps1, without the profile loaded), borrow the profile's own
    # helpers from profile2.0.ps1 rather than keeping a second copy here that could drift.
    $helpers = 'Get-PSProfileCachePath', 'Get-PSProfileFunctionSignature', 'Get-PSProfileFunctionFolders',
    'Get-PSProfileOhMyPoshKey', 'Update-PSProfileOhMyPoshCache', 'Update-PSProfileExecutionPolicyCache',
    'Resolve-PSProfilePoshTheme',
    'Find-PSProfileExecutable', 'Get-PSProfileInitArguments', 'Get-PSProfileInitCacheHeader', 'Update-PSProfileInitCache'
    $missing = @($helpers | Where-Object { -not (Get-Command -Name $_ -CommandType Function -ErrorAction Ignore) })
    if ($missing) {
        $profileAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'profile2.0.ps1'), [ref]$null, [ref]$null)
        $definitions = $profileAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $missing -contains $node.Name
            }, $false)
        foreach ($definition in $definitions) { . ([scriptblock]::Create($definition.Extent.Text)) }
    }

    if ($Cache -contains 'ExecutionPolicy' -and $PSCmdlet.ShouldProcess('execution policy', 'Rebuild cache')) {
        $null = Update-PSProfileExecutionPolicyCache -Root $root
    }

    $config = $null
    if ($Cache -contains 'OhMyPosh' -or $Cache -contains 'Zoxide' -or $Cache -contains 'Atuin') {
        $config = if (Get-Command -Name Get-PSProfileConfig -CommandType Function -ErrorAction Ignore) { Get-PSProfileConfig }
        else {
            # Same lookup as the profile's Get-PSProfileConfig, which relies on its own location.
            $configPath = Join-Path (Join-Path (Join-Path $root 'assets') 'config') 'config.json'
            if (-not (Test-Path -Path $configPath)) { $configPath = Join-Path (Join-Path (Join-Path $root 'assets') 'config') 'sample-config.json' }
            if (Test-Path -Path $configPath) { Get-Content -Path $configPath -Raw | ConvertFrom-Json }
        }
    }

    foreach ($tool in 'zoxide', 'atuin') {
        if ($Cache -notcontains $tool) { continue }
        $arguments = Get-PSProfileInitArguments -Tool $tool -Settings $config.settings
        # Found the way the profile finds it, so the path in the cache matches what it looks for.
        $executable = Find-PSProfileExecutable -Name $tool
        if ($arguments -and $executable -and $PSCmdlet.ShouldProcess("$tool init", 'Rebuild cache')) {
            $null = Update-PSProfileInitCache -Root $root -Name $tool -Executable $executable -Arguments $arguments
        }
    }

    if ($Cache -contains 'OhMyPosh' -and (Get-Command -Name oh-my-posh -CommandType Application -ErrorAction Ignore) -and
        $PSCmdlet.ShouldProcess('oh-my-posh init', 'Rebuild cache')) {
        if ($config.settings.PoshTheme) {
            if (-not (Get-Command -Name Resolve-PoshTheme -CommandType Function -ErrorAction Ignore)) {
                $resolver = Get-PSProfileFunctionFolders -Root $root -Kind private -OSFolder $osFolder |
                    ForEach-Object { Join-Path $_.Path 'Resolve-PoshTheme.ps1' } | Where-Object { Test-Path -Path $_ } | Select-Object -Last 1
                if ($resolver) { . $resolver }
            }
            $null = Update-PSProfileOhMyPoshCache -Root $root -ThemePath (Resolve-PSProfilePoshTheme -Root $root -Settings $config.settings)
        }
    }

    if ($Cache -contains 'Functions') {
        $folders = Get-PSProfileFunctionFolders -Root $root -Kind public -OSFolder $osFolder
        $cachePath = Get-PSProfileCachePath -Root $root -Name "functions.$osFolder" -Extension '.ps1'
        $signature = Get-PSProfileFunctionSignature -Folder $folders
        if ($PSCmdlet.ShouldProcess($cachePath, 'Rebuild function index')) {
            $text = New-PSProfileFunctionIndex -Folder $folders -Signature $signature
            $cacheDir = Split-Path -Path $cachePath -Parent
            if (-not (Test-Path -Path $cacheDir)) { $null = New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction Stop }
            # Written to a temporary file and moved into place, so a shell starting at the same
            # moment never dot-sources a half-written index.
            $tempPath = "$cachePath.$PID.tmp"
            try {
                [System.IO.File]::WriteAllText($tempPath, $text, [System.Text.UTF8Encoding]::new($true))
                Move-Item -LiteralPath $tempPath -Destination $cachePath -Force -ErrorAction Stop
            }
            finally { Remove-Item -LiteralPath $tempPath -ErrorAction Ignore }
        }
    }
}

<#
.SYNOPSIS
    Generates the function index script for Update-PSProfileCache.
.DESCRIPTION
    See Update-PSProfileCache. Folders are processed in order, so a later folder's function
    wins a name clash with an earlier one's: its placeholder is defined last, and the earlier
    folder's placeholder for that name is left out.
.PARAMETER Folder
    Folders to index, as objects with Name (e.g. 'shared', 'windows') and Path, lowest
    precedence first.
.PARAMETER Signature
    Fingerprint of the folders' files, written to the index's first line.
.EXAMPLE
    New-PSProfileFunctionIndex -Folder (Get-PSProfileFunctionFolders -Root $root -Kind public -OSFolder windows) -Signature $signature
.OUTPUTS
    System.String
#>
function New-PSProfileFunctionIndex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][object[]]$Folder,
        [Parameter(Mandatory)][string]$Signature
    )

    $language = 'System.Management.Automation.Language'
    $aliasCommands = 'Remove-Item', 'New-Alias', 'Set-Alias'

    # Parse everything first, so precedence across folders is known before writing anything.
    $records = foreach ($entry in $Folder) {
        foreach ($file in Get-ChildItem -LiteralPath $entry.Path -Filter '*.ps1' | Sort-Object -Property Name) {
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
            $statements = @($ast.EndBlock.Statements)
            $functions = @($statements | Where-Object { $_ -is "$language.FunctionDefinitionAst" })
            $aliasStatements = @($statements | Where-Object {
                    $_ -is "$language.PipelineAst" -and $_.PipelineElements.Count -eq 1 -and
                    $_.PipelineElements[0] -is "$language.CommandAst" -and
                    $aliasCommands -contains $_.PipelineElements[0].GetCommandName() -and
                    ($_.PipelineElements[0].GetCommandName() -ne 'Remove-Item' -or $_.Extent.Text -match '(?i)alias:')
                })
            [PSCustomObject]@{
                Folder          = $entry.Name
                File            = $file.Name
                Functions       = $functions
                AliasStatements = $aliasStatements
                Eager           = $parseErrors.Count -gt 0 -or $ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or
                $ast.DynamicParamBlock -or ($functions.Count + $aliasStatements.Count) -ne $statements.Count -or
                @($functions | Where-Object { $_.IsFilter -or $_.Body.DynamicParamBlock }).Count -gt 0
            }
        }
    }

    $owner = @{}
    foreach ($record in $records) { foreach ($function in $record.Functions) { $owner[$function.Name] = $record } }

    $out = [System.Text.StringBuilder]::new()
    $null = $out.AppendLine("# PSProfile function index: $Signature")
    $null = $out.AppendLine('# Generated by Update-PSProfileCache - do not edit; rebuilt automatically when out of date.')
    $null = $out.AppendLine('$Global:PSProfileLazyFunctionFiles = [System.Collections.Generic.List[string]]::new()')

    foreach ($record in $records) {
        $quotedFolder = "'" + $record.Folder.Replace("'", "''") + "'"
        $quotedFile = "'" + $record.File.Replace("'", "''") + "'"
        $null = $out.AppendLine()
        $null = $out.AppendLine("#region $($record.Folder)/$($record.File)")
        if ($record.Eager) {
            $null = $out.AppendLine(". (Join-Path (Join-Path `$Global:PSProfilePublicRoot $quotedFolder) $quotedFile)")
            $null = $out.AppendLine('#endregion')
            continue
        }

        $functions = @($record.Functions | Where-Object { $owner[$_.Name] -eq $record })
        if ($functions.Count -eq 0) {
            $null = $out.AppendLine("# Every function here is overridden by a later folder's.")
            $null = $out.AppendLine('#endregion')
            continue
        }

        foreach ($statement in $record.AliasStatements) { $null = $out.AppendLine($statement.Extent.Text) }
        $null = $out.AppendLine("`$Global:PSProfileLazyFunctionFiles.Add('$($record.Folder.Replace("'", "''"))|$($record.File.Replace("'", "''"))')")

        foreach ($function in $functions) {
            $paramBlock = $function.Body.ParamBlock
            $parameters = if ($paramBlock) { @($paramBlock.Parameters) } else { @($function.Parameters) }
            $blockAttributes = if ($paramBlock) { @($paramBlock.Attributes) } else { @() }
            $isAdvanced = @($blockAttributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }).Count -gt 0 -or
                @($parameters | ForEach-Object { $_.Attributes } | Where-Object { $_.TypeName.Name -eq 'Parameter' }).Count -gt 0
            $functionAliases = @($blockAttributes | Where-Object { $_.TypeName.Name -eq 'Alias' } |
                    ForEach-Object { $_.PositionalArguments } | ForEach-Object { $_.SafeGetValue() })

            $parameterText = foreach ($parameter in $parameters) {
                $attributes = foreach ($attribute in $parameter.Attributes) {
                    if ($attribute.TypeName.Name -eq 'ValidateScript') { continue }
                    $attribute.Extent.Text
                }
                '        ' + ((@($attributes) + $parameter.Name.Extent.Text) -join ' ')
            }

            $quotedName = "'" + $function.Name.Replace("'", "''") + "'"
            $null = $out.AppendLine("function global:$($function.Name) {")
            $help = $function.GetHelpContent()
            if ($help) { $null = $out.AppendLine($help.GetCommentBlock().TrimEnd()) }
            foreach ($attribute in $blockAttributes) { $null = $out.AppendLine("    $($attribute.Extent.Text)") }
            if ($parameterText) {
                $null = $out.AppendLine('    param(')
                $null = $out.AppendLine((@($parameterText) -join ",`n"))
                $null = $out.AppendLine('    )')
            }
            elseif ($isAdvanced -or $paramBlock) { $null = $out.AppendLine('    param()') }

            $resolve = "Resolve-PSProfileLazyFunction -Folder $quotedFolder -File $quotedFile -Name $quotedName"
            if ($isAdvanced) {
                # The proxy-command pattern. The steppable pipeline has to be built here, in the
                # placeholder's own scope: built inside a helper function, the real function runs
                # under that helper's already-exited scope and can't resolve commands.
                $null = $out.AppendLine('    begin {')
                $null = $out.AppendLine("        `$__pspCommand = $resolve")
                $null = $out.AppendLine('        $__pspStub = { & $__pspCommand @PSBoundParameters }.GetSteppablePipeline($MyInvocation.CommandOrigin)')
                $null = $out.AppendLine('        $__pspStub.Begin($PSCmdlet)')
                $null = $out.AppendLine('    }')
                $null = $out.AppendLine('    process { $__pspStub.Process($_) }')
                $null = $out.AppendLine('    end { $__pspStub.End() }')
            }
            else {
                $null = $out.AppendLine("    `$__pspCommand = $resolve")
                $null = $out.AppendLine('    if ($MyInvocation.ExpectingInput) { $input | & $__pspCommand @PSBoundParameters @args } else { & $__pspCommand @PSBoundParameters @args }')
            }
            $null = $out.AppendLine('}')
            foreach ($alias in $functionAliases) {
                $null = $out.AppendLine("Set-Alias -Name '$("$alias".Replace("'", "''"))' -Value $quotedName -Scope Global -Force")
            }
        }
        $null = $out.AppendLine('#endregion')
    }
    $out.ToString()
}
