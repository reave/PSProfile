##- Registering Auto-Completion for Windows Terminal
#- Register Winget Completer
$wingetCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $tokens = $commandAst.Extent.Text.Trim() -split '\s+'
    $completions = switch ($tokens[1]) {
        'install' {
            "-q", "-m", "-v", "-s", "-e", "-i", "-h", "-o", "-l",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--interactive",
            "--silent", "--log", "--override", "--location", "--help"; break
        }
        'add' {
            "-q", "-m", "-v", "-s", "-e", "-i", "-h", "-o", "-l",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--interactive",
            "--silent", "--log", "--override", "--location", "--help"; break
        }
        'search' {
            "-q", "-s", "-n", "-e", "-?",
            "--query", "--id", "--name", "--moniker", "--tag", "--command", "--source", "--count", "--exact", "--help"
            break
        }
        'find' {
            "-q", "-s", "-n", "-e", "-?",
            "--query", "--id", "--name", "--moniker", "--tag", "--command", "--source", "--count", "--exact", "--help"
            break
        }
        'show' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help"
            break
        }
        'view' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help"
            break
        }
        'upgrade' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help",
            "--all", "--interactive", "--silent", "--log", "--override", "--location", "--help"
            break
        }
        'update' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help",
            "--all", "--interactive", "--silent", "--log", "--override", "--location", "--help"
            break
        }
        'list' {
            "-q", "-s", "-n", "-e", "-?",
            "--query", "--id", "--name", "--moniker", "--tag", "--command", "--source", "--count", "--exact", "--help"
            break
        }
        'ls' {
            "-q", "-s", "-n", "-e", "-?",
            "--query", "--id", "--name", "--moniker", "--tag", "--command", "--source", "--count", "--exact", "--help"
            break
        }
        'uninstall' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help",
            "--all", "--interactive", "--silent", "--log", "--override", "--location", "--help"
            break
        }
        'remove' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help",
            "--all", "--interactive", "--silent", "--log", "--override", "--location", "--help"
            break
        }
        'rm' {
            "-q", "-m", "-v", "-s", "-e", "-?",
            "--query", "--manifest", "--id", "--name", "--moniker", "--version", "--source", "--exact", "--versions", "--help",
            "--all", "--interactive", "--silent", "--log", "--override", "--location", "--help"
            break
        }
        'source' {
            "-q", "-s", "-n", "-e", "-?",
            "--query", "--id", "--name", "--moniker", "--tag", "--command", "--source", "--count", "--exact", "--help"
            break
        }
        'hash' { "-?", "--manifest", "--help"; break }
        'settings' {
            "export", "set", "reset",
            "-?", "--help", "--enable", "--disable", "--wait", "--logs", "--verbose", "--nowarn", "--disable-interactivity",
            "--proxy", "--no-proxy"
            break
        }
        'features' {
            "-?", "--help", "--verbose", "--nowarn", "--disable-interactivity"
            break
        }
        'export' { "-?", "--manifest", "--help"; break }
        'import' { "-?", "--manifest", "--help"; break }
        'pin' { "-?", "--manifest", "--help"; break }
        'configure' { "-?", "--manifest", "--help"; break }
        'download' { "-?", "--manifest", "--help"; break }
        'repair' { "-?", "--manifest", "--help"; break }
        'validate' { "-?", "--manifest", "--help"; break }

        default { "install", "show", "source", "search", "list", "upgrade", "uninstall", "hash", "validate", "settings", "features", "export", "import", "pin", "configure", "download", "repair", "-v", "--version", "--info", "-?", "--help" }
    }

    $completions | Where-Object { $_ -like "${wordToComplete}*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -CommandName winget -Native -ScriptBlock $wingetCompleter

# PowerShell parameter completion shim for the winget
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
