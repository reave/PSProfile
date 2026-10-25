# npx's flags, from `npx --help` (it's a thin wrapper around `npm exec`). No
# `completion powershell` generator of its own (npm's own completion support is
# bash-only). Only completes npx's own flags - the package/command name that
# usually follows isn't completed, since that would mean querying the npm
# registry or scanning node_modules, out of scope for a flag completer.
$__npxFlags = @(
    '--package', '-c', '--call', '-w', '--workspace', '--workspaces',
    '--include-workspace-root', '--allow-scripts', '--strict-allow-scripts',
    '--dangerously-allow-all-scripts', '--version', '--help', '-h'
)

Register-ArgumentCompleter -Native -CommandName npx -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    if ($wordToComplete -notlike '-*') { return }
    $__npxFlags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
