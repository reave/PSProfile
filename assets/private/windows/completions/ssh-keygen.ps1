# ssh-keygen's flags, from the OpenSSH manual (stable across recent OpenSSH
# releases; no `completion powershell` generator of its own, and no dynamic
# subcommands to query - unlike this repo's other completers, this one is never
# invoked to discover its own options, since running ssh-keygen with no/wrong
# arguments can drop straight into an interactive "Generating key pair..."
# prompt rather than printing help.
$__sshKeygenFlags = @(
    '-A', '-a', '-B', '-b', '-C', '-c', '-D', '-E', '-e', '-F', '-f', '-G',
    '-g', '-H', '-h', '-I', '-i', '-J', '-j', '-K', '-k', '-L', '-l', '-M',
    '-m', '-N', '-n', '-O', '-o', '-P', '-p', '-Q', '-q', '-R', '-r', '-s',
    '-T', '-U', '-u', '-V', '-v', '-W', '-w', '-X', '-x', '-y', '-Z'
)
$__sshKeygenTypes = 'dsa', 'ecdsa', 'ecdsa-sk', 'ed25519', 'ed25519-sk', 'rsa'

Register-ArgumentCompleter -Native -CommandName ssh-keygen -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $tokens = $commandAst.CommandElements.Extent.Text
    if ($tokens[-1] -eq '-t') {
        $__sshKeygenTypes | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }

    if ($wordToComplete -notlike '-*') { return }
    $__sshKeygenFlags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
