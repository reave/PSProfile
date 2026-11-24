# pwsh's own CLI parameters (pwsh -File/-Command/-NoProfile/...), from
# `pwsh -?` / the about_PowerShell_exe help topic - stable across PS7.x. No
# `completion powershell` generator of its own (pwsh completes commands typed
# *inside* a session natively; this is for completing flags to the pwsh.exe
# launcher itself, e.g. `pwsh -NoP<TAB>` on a command line).
$__pwshFlags = @(
    '-File', '-Command', '-c', '-EncodedCommand', '-ec', '-ExecutionPolicy', '-ep',
    '-InputFormat', '-if', '-OutputFormat', '-of', '-Interactive', '-i', '-Login', '-l',
    '-MTA', '-NoExit', '-noe', '-NoLogo', '-nol', '-NonInteractive', '-noni',
    '-NoProfile', '-nop', '-NoProfileLoadTime', '-SettingsFile', '-settings',
    '-SSHServerMode', '-sshs', '-STA', '-Version', '-v', '-WindowStyle', '-w',
    '-WorkingDirectory', '-wd', '-ConfigurationName', '-config', '-CustomPipeName',
    '-Help', '-h', '-?'
)

Register-ArgumentCompleter -Native -CommandName pwsh -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    if ($wordToComplete -notlike '-*') { return }
    $__pwshFlags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
