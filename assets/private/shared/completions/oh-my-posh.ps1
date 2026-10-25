# oh-my-posh's commands and flags, transcribed from its CLI source (src/cli, October 2026).
# oh-my-posh replaced cobra with its own command tree, which dropped cobra's hidden
# `__complete` command, so the cobra-generated completer this file used to hold failed with
# "unknown command __complete". There's no `completion powershell` generator any more either,
# hence a static list, same style as wsl.ps1. The hidden `serve` command and the deprecated
# root --init/--shell flags are left out.
$__ompTree = @{
    ''              = @{
        Commands = 'init', 'print', 'stream', 'config', 'cache', 'debug', 'disable', 'enable', 'font',
        'get', 'notice', 'shell', 'toggle', 'upgrade', 'version', 'auth', 'claude', 'copilot', 'antigravity'
        Flags    = @('--version')
    }
    'init'          = @{
        Args  = 'bash', 'zsh', 'fish', 'powershell', 'pwsh', 'cmd', 'nu', 'elvish', 'xonsh', 'yash'
        Flags = '--print', '-p', '--strict', '-s', '--debug', '--eval'
    }
    'print'         = @{
        Args  = 'debug', 'primary', 'secondary', 'transient', 'transient-right', 'right', 'tooltip', 'valid', 'error', 'preview', 'cursor'
        Flags = '--pwd', '--pswd', '--shell', '--shell-version', '--status', '--no-status', '--pipestatus',
        '--stack-count', '-s', '--terminal-width', '-w', '--command', '--cleared', '--eval', '--column',
        '--job-count', '--escape', '--force', '-f', '--data', '--interrupted', '--data-derive', '--data-only'
    }
    'stream'        = @{
        Flags = '--pwd', '--pswd', '--shell', '--shell-version', '--status', '--no-status', '--pipestatus',
        '--stack-count', '-s', '--terminal-width', '-w', '--cleared', '--eval', '--column', '--job-count'
    }
    'config'        = @{ Commands = 'edit', 'export', 'dsc' }
    'config export' = @{
        Commands = 'data', 'image'
        Flags    = '--format', '-f', '--output', '-o'
    }
    'config export data'  = @{ Flags = '--output', '-o', '--sanitize', '--data', '--themes' }
    'config export image' = @{
        Flags = '--output', '-o', '--font-family', '--data', '--terminal-width', '--background-color', '--data-derive', '--data-only'
    }
    'config dsc'    = @{ Args = 'get', 'set', 'test', 'schema', 'export'; Flags = @('--state') }
    'cache'         = @{ Args = 'path', 'clear', 'ttl', 'show'; Flags = '--session', '-s' }
    'debug'         = @{ Flags = @('--pwd') }
    'disable'       = @{ Args = 'notice', 'upgrade', 'reload' }
    'enable'        = @{ Args = 'notice', 'upgrade', 'reload' }
    'font'          = @{ Commands = 'list', 'install', 'dsc' }
    'font install'  = @{ Flags = @('--zip-folder') }
    'font dsc'      = @{ Args = 'get', 'set', 'test', 'schema', 'export'; Flags = @('--state') }
    'get'           = @{ Args = 'millis', 'shell', 'accent', 'toggles', 'width' }
    'shell'         = @{ Commands = 'get', 'dsc' }
    'shell dsc'     = @{ Args = 'get', 'set', 'test', 'schema', 'export'; Flags = @('--state') }
    'upgrade'       = @{ Flags = '--force', '-f', '--auto', '--debug' }
    'version'       = @{ Flags = '--verbose', '-v' }
    'auth'          = @{ Args = 'copilot', 'pear', 'ytmda' }
}
# Flags every command takes.
$__ompGlobalFlags = '--config', '-c', '--trace', '--plain', '--help', '-h'
# Flags whose value is free text or a path: PowerShell's own path completion handles those.
$__ompValueFlags = '--config', '-c', '--output', '-o', '--data', '--themes', '--pwd', '--pswd', '--shell',
'--shell-version', '--status', '--pipestatus', '--stack-count', '-s', '--terminal-width', '-w', '--command',
'--column', '--job-count', '--font-family', '--background-color', '--zip-folder', '--state'

Register-ArgumentCompleter -Native -CommandName oh-my-posh -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    # The words before the one being completed, after the command name itself.
    $words = @($commandAst.CommandElements | Select-Object -Skip 1 |
            Where-Object { $_.Extent.EndOffset -lt $cursorPosition -or ($_.Extent.EndOffset -eq $cursorPosition -and -not $wordToComplete) } |
            ForEach-Object { $_.Extent.Text })

    $path = ''
    $previous = $null
    foreach ($word in $words) {
        $next = "$path $word".Trim()
        if ($word -notlike '-*' -and $__ompTree.ContainsKey($next)) { $path = $next }
        $previous = $word
    }
    $node = $__ompTree[$path]

    # A flag needing a value was just typed: don't offer subcommands in its place.
    if ($previous -eq '--format' -or ($previous -eq '-f' -and $path -eq 'config export')) {
        $candidates = 'json', 'yaml', 'toml'
    }
    elseif ($previous -in $__ompValueFlags -and -not ($previous -eq '-s' -and $path -in 'init', 'cache')) {
        return
    }
    elseif ($wordToComplete -like '-*') {
        $candidates = @($node.Flags) + $__ompGlobalFlags
    }
    else {
        $candidates = @($node.Commands) + @($node.Args)
    }

    $candidates | Where-Object { $_ -and $_ -like "$wordToComplete*" } | Sort-Object -Unique | ForEach-Object {
        $type = if ($_ -like '-*') { 'ParameterName' } else { 'ParameterValue' }
        [System.Management.Automation.CompletionResult]::new($_, $_, $type, $_)
    }
}
