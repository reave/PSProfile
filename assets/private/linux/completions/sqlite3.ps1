# sqlite3's CLI flags and interactive dot-commands, from the SQLite CLI docs
# (sqlite.org/cli.html - stable across recent 3.x releases). No `completion
# powershell` generator of its own. Dot-commands only make sense once you're
# already inside the sqlite3 REPL, not on the initial command line - offered
# here when the word being completed starts with '.', flags when it starts
# with '-', so both work from the same completer depending on context.
$__sqlite3Flags = @(
    '-A', '-append', '-ascii', '-bail', '-batch', '-box', '-column', '-cmd',
    '-csv', '-deserialize', '-echo', '-init', '-header', '-noheader', '-help',
    '-html', '-interactive', '-json', '-line', '-list', '-lookaside',
    '-markdown', '-maxsize', '-memtrace', '-mmap', '-newline', '-nofollow',
    '-nonce', '-nullvalue', '-pagecache', '-pcachetrace', '-quote', '-readonly',
    '-safe', '-separator', '-stats', '-table', '-tabs', '-unsafe-testing',
    '-version', '-vfs', '-vfstrace', '-zip'
)
$__sqlite3DotCommands = @(
    '.archive', '.auth', '.backup', '.bail', '.binary', '.cd', '.changes',
    '.check', '.clone', '.columns', '.connection', '.databases', '.dbconfig',
    '.dbinfo', '.dump', '.echo', '.eqp', '.excel', '.exit', '.expert',
    '.filectrl', '.fullschema', '.headers', '.help', '.import', '.indexes',
    '.limit', '.lint', '.load', '.log', '.mode', '.nonce', '.nullvalue',
    '.once', '.open', '.output', '.parameter', '.print', '.progress',
    '.prompt', '.quit', '.read', '.recover', '.restore', '.save', '.scanstats',
    '.schema', '.selftest', '.separator', '.session', '.sha3sum', '.shell',
    '.show', '.stats', '.system', '.tables', '.testcase', '.timeout', '.timer',
    '.trace', '.vfsinfo', '.vfslist', '.vfsname', '.width'
)

Register-ArgumentCompleter -Native -CommandName sqlite3 -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $candidates = if ($wordToComplete -like '.*') { $__sqlite3DotCommands }
    elseif ($wordToComplete -like '-*') { $__sqlite3Flags }
    else { return }

    $candidates | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
