# wsl.exe's flags, transcribed from `wsl --help` (Windows 11, WSL 2.x). No
# `completion powershell` generator of its own. Top-level flags always complete;
# a handful of them (--install, --manage, --mount, --export, --import, --list,
# --update) take their own sub-options, offered once that parent flag appears
# earlier on the command line - same idea as winget.ps1's per-subcommand switch.
$__wslTopLevel = @(
    '--help', '--exec', '-e', '--shell-type', '--cd', '--distribution', '-d',
    '--distribution-id', '--user', '-u', '--system', '--debug-shell',
    '--install', '--manage', '--mount', '--set-default-version', '--shutdown',
    '--status', '--unmount', '--uninstall', '--update', '--export', '--import',
    '--import-in-place', '--list', '-l', '--set-default', '-s', '--set-version',
    '--terminate', '-t', '--unregister', '--version', '-v'
)
$__wslSubOptions = @{
    '--install' = '--enable-wsl1', '--fixed-vhd', '--from-file', '--legacy', '--location', '--name', '--no-distribution', '--no-launch', '-n', '--version', '--vhd-size', '--web-download'
    '--manage'  = '--move', '--set-sparse', '-s', '--set-default-user', '--resize'
    '--mount'   = '--vhd', '--bare', '--name', '--type', '--options', '--partition'
    '--export'  = '--format'
    '--import'  = '--version', '--vhd'
    '--list'    = '--all', '--running', '--quiet', '-q', '--verbose', '-v', '--online', '-o'
    '-l'        = '--all', '--running', '--quiet', '-q', '--verbose', '-v', '--online', '-o'
    '--update'  = '--pre-release'
}

Register-ArgumentCompleter -Native -CommandName wsl -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $tokens = $commandAst.CommandElements.Extent.Text
    $candidates = $__wslTopLevel
    foreach ($t in $tokens) {
        if ($__wslSubOptions.ContainsKey($t)) {
            $candidates = $__wslSubOptions[$t]
            break
        }
    }

    $candidates | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object -Unique | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
