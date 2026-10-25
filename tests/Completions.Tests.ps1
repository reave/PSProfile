#- Native command completion: the dispatcher in assets/private/shared/completions.ps1, the
#- carapace hand-off in assets/lib/PSProfile.Completion.ps1, Update-Completions' carapace lists,
#- and the hand-written oh-my-posh completer. Runs in a child process against a fixture install
#- (with a stub carapace on PATH) so registered completers and PATH changes stay out of the
#- test session. 7.6+ takes the -NativeFallback path; 5.1 and 7.4 the per-name one.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $repoRoot = Get-PSProfileRepoRoot
    $isWindowsHost = $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'
    $osFolder = if ($isWindowsHost) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }

    # A fixture install: the completion code, the oh-my-posh completer, one hand-written
    # completer for a made-up tool, and carapace's lists as Update-Completions would write them.
    $root = Join-Path $TestDrive 'install'
    $completionsDir = Join-Path $root 'assets/private/shared/completions'
    $nativeDir = Join-Path $root "assets/private/$osFolder/completions/native"
    $binDir = Join-Path $TestDrive 'bin'
    foreach ($dir in (Join-Path $root 'assets/lib'), $completionsDir, $nativeDir, $binDir) { $null = New-Item -ItemType Directory -Path $dir -Force }
    Copy-Item -Path (Join-Path $repoRoot 'assets/lib/PSProfile.Completion.ps1') -Destination (Join-Path $root 'assets/lib')
    Copy-Item -Path (Join-Path $repoRoot 'assets/private/shared/completions/oh-my-posh.ps1') -Destination $completionsDir
    Set-Content -Path (Join-Path $completionsDir 'handtool.ps1') -Encoding ascii -Value @'
Register-ArgumentCompleter -Native -CommandName handtool -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [System.Management.Automation.CompletionResult]::new('from-file')
}
'@
    Set-Content -Path (Join-Path $nativeDir 'carapace.names.txt') -Value 'faketool' -Encoding ascii
    Set-Content -Path (Join-Path $nativeDir 'carapace.installed.txt') -Value 'faketool' -Encoding ascii

    # A stub carapace: lists one tool, logs its arguments, and answers with two candidates.
    $json = '[{"CompletionText":"checkout ","ListItemText":"checkout","ToolTip":"switch branches"},{"CompletionText":"commit ","ListItemText":"commit","ToolTip":" "}]'
    if ($isWindowsHost) {
        Set-Content -Path (Join-Path $binDir 'carapace.cmd') -Encoding ascii -Value @(
            '@echo off'
            'if "%1"=="--list" ( echo faketool& exit /b 0 )'
            'echo %*> "%FAKE_CARAPACE_LOG%"'
            "echo $json"
        )
        foreach ($tool in 'faketool', 'handtool') { Set-Content -Path (Join-Path $binDir "$tool.cmd") -Value '@echo off' -Encoding ascii }
    }
    else {
        Set-Content -Path (Join-Path $binDir 'carapace') -Encoding ascii -Value @(
            '#!/bin/sh'
            'if [ "$1" = "--list" ]; then echo faketool; exit 0; fi'
            'printf "%s\n" "$@" > "$FAKE_CARAPACE_LOG"'
            "echo '$json'"
        )
        foreach ($tool in 'faketool', 'handtool') { Set-Content -Path (Join-Path $binDir $tool) -Value '#!/bin/sh' -Encoding ascii }
        & chmod +x (Join-Path $binDir 'carapace') (Join-Path $binDir 'faketool') (Join-Path $binDir 'handtool')
    }

    $lines = @(
        'oh-my-posh ini', 'oh-my-posh init ', 'oh-my-posh init pwsh --p', 'oh-my-posh config export ',
        'oh-my-posh config export --format ', 'oh-my-posh print primary --pwd ',
        'handtool x', 'faketool ch', 'faketool ', 'nocompletertool ', 'fkt ch'
    )

    # Single-quoted on purpose: expanded by the child, with paths passed via env vars.
    $childScript = @'
$ErrorActionPreference = 'Stop'
$result = [ordered]@{ Errors = @(); Completions = [ordered]@{}; Logs = [ordered]@{}; Lists = [ordered]@{} }
try {
    # The two profile helpers completions.ps1 relies on, taken from the profile itself.
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($env:PSP_PROFILE, [ref]$null, [ref]$null)
    $helpers = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -in 'Get-PSProfileFunctionFolders', 'Import-PSProfileScript' }, $false)
    foreach ($helper in $helpers) { . ([scriptblock]::Create($helper.Extent.Text)) }

    $Global:PSProfileRoot = $env:PSP_ROOT
    $OSFolder = $env:PSP_OS
    $PSProfileConfig = [PSCustomObject]@{ NativeCompletions = @() }
    $env:PATH = $env:PSP_BIN + [IO.Path]::PathSeparator + $env:PATH
    . $env:PSP_COMPLETIONS
    Set-Alias -Name fkt -Value faketool

    # Not @(...): Windows PowerShell's ConvertFrom-Json emits a JSON array as one object,
    # and foreach enumerates either shape.
    foreach ($line in ($env:PSP_LINES | ConvertFrom-Json)) {
        $log = Join-Path $env:PSP_LOGS ([guid]::NewGuid().ToString('N') + '.log')
        $env:FAKE_CARAPACE_LOG = $log
        $found = (TabExpansion2 -inputScript $line -cursorColumn $line.Length).CompletionMatches
        $result.Completions[$line] = [string[]]@($found | ForEach-Object { $_.CompletionText })
        $result.Logs[$line] = if (Test-Path -LiteralPath $log) { [string[]]@(Get-Content -LiteralPath $log) } else { [string[]]@() }
    }

    # Update-Completions rewrites carapace's lists from the stub.
    function Get-PSProfileConfig { [PSCustomObject]@{ NativeCompletions = @() } }
    . $env:PSP_UPDATE
    $nativeDir = [IO.Path]::Combine($env:PSP_ROOT, 'assets', 'private', $env:PSP_OS, 'completions', 'native')
    Remove-Item -Path (Join-Path $nativeDir 'carapace.*.txt')
    Update-Completions 6> $null
    foreach ($name in 'carapace.names.txt', 'carapace.installed.txt') {
        $path = Join-Path $nativeDir $name
        $result.Lists[$name] = if (Test-Path -LiteralPath $path) { [string[]]@(Get-Content -LiteralPath $path) } else { [string[]]@() }
    }
}
catch { $result.Errors += "$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" }
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $env:PSP_RESULT -Encoding UTF8
'@

    $logDir = Join-Path $TestDrive 'logs'
    $null = New-Item -ItemType Directory -Path $logDir -Force
    $resultPath = Join-Path $TestDrive 'result.json'
    $envOverrides = @{
        PSP_PROFILE     = Join-Path $repoRoot 'profile2.0.ps1'
        PSP_COMPLETIONS = Join-Path $repoRoot 'assets/private/shared/completions.ps1'
        PSP_UPDATE      = Join-Path $repoRoot 'assets/public/shared/Update-Completions.ps1'
        PSP_ROOT        = $root
        PSP_OS          = $osFolder
        PSP_BIN         = $binDir
        PSP_LOGS        = $logDir
        PSP_LINES       = ConvertTo-Json -InputObject $lines -Compress
        PSP_RESULT      = $resultPath
    }
    $savedEnv = @{}
    foreach ($key in $envOverrides.Keys) {
        $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key, $envOverrides[$key])
    }
    try {
        # Same executable as the test run, so the 5.1 job really runs under Windows PowerShell.
        $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript))
        $output = & $exe -NoProfile -NonInteractive -NoLogo -EncodedCommand $encoded 2>&1 | Out-String
    }
    finally {
        foreach ($key in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnv[$key]) }
    }
    if (-not (Test-Path -Path $resultPath)) { throw "Completion child process wrote no result. Output:`n$output" }
    $result = Get-Content -Path $resultPath -Raw | ConvertFrom-Json

    function Get-Completion([string]$Line) { @($result.Completions.$Line | Where-Object { $_ }) }
    $hasNativeFallback = $PSVersionTable.PSVersion -ge [version]'7.6'
}

Describe 'Native completion' {
    It 'sets up without errors' {
        $result.Errors | Should -BeNullOrEmpty
    }

    It 'loads a hand-written completer file on first Tab' {
        Get-Completion 'handtool x' | Should -Be @('from-file')
    }

    It 'hands a tool with no completer file to carapace' {
        (Get-Completion 'faketool ch') -replace ' $', '' | Should -Be @('checkout', 'commit')
        $log = @($result.Logs.'faketool ch')
        if ($isWindowsHost) { $log -join ' ' | Should -Match 'faketool powershell faketool ch' }
        else { $log | Should -Be @('faketool', 'powershell', 'faketool', 'ch') }
    }

    It 'passes carapace an empty word after a trailing space' {
        $log = @($result.Logs.'faketool ')
        if ($isWindowsHost) { $log -join ' ' | Should -Match '""\s*$' }
        else { $log[-1] | Should -BeNullOrEmpty; $log.Count | Should -Be 4 }
    }

    It 'leaves a tool neither knows to PowerShell''s path completion' {
        Get-Completion 'nocompletertool ' | Should -Not -Contain 'checkout '
        $result.Logs.'nocompletertool ' | Should -BeNullOrEmpty
    }

    It 'follows an alias to its tool (7.6+ only)' {
        if (-not $hasNativeFallback) { Set-ItResult -Skipped -Because 'needs Register-ArgumentCompleter -NativeFallback'; return }
        Get-Completion 'fkt ch' | Should -Contain 'checkout '
    }
}

Describe 'oh-my-posh completer' {
    It 'completes subcommands' {
        Get-Completion 'oh-my-posh ini' | Should -Be @('init')
        Get-Completion 'oh-my-posh config export ' | Should -Be @('data', 'image')
    }

    It 'completes a subcommand''s arguments' {
        $shells = Get-Completion 'oh-my-posh init '
        $shells | Should -Contain 'pwsh'
        $shells | Should -Not -Contain 'print'
    }

    It 'completes flags, including the global ones' {
        # '--p', not a bare '--': Windows PowerShell treats a lone '--' as end-of-parameters and
        # never asks a native completer about it.
        $flags = Get-Completion 'oh-my-posh init pwsh --p'
        $flags | Should -Contain '--print'
        $flags | Should -Contain '--plain'
    }

    It 'completes --format values' {
        Get-Completion 'oh-my-posh config export --format ' | Should -Be @('json', 'toml', 'yaml')
    }

    It 'offers no subcommands where a flag value goes' {
        Get-Completion 'oh-my-posh print primary --pwd ' | Should -Not -Contain 'init'
    }
}

Describe 'Update-Completions carapace lists' {
    It 'writes the tools carapace knows' {
        @($result.Lists.'carapace.names.txt' | ForEach-Object { $_.Trim() }) | Should -Be @('faketool')
    }

    It 'writes the ones installed here' {
        @($result.Lists.'carapace.installed.txt' | ForEach-Object { $_.Trim() }) | Should -Be @('faketool')
    }
}
