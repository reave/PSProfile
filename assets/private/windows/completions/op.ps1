# PowerShell completion for 1Password CLI
Register-ArgumentCompleter -Native -CommandName 'op' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commandElements = $commandAst.CommandElements
    $command = @(
        'op'
        for ($i = 1; $i -lt $commandElements.Count; $i++) {
            $element = $commandElements[$i]
            if ($element -isnot [StringConstantExpressionAst] -or
                $element.StringConstantType -ne [StringConstantType]::BareWord -or
                $element.Value.StartsWith('-')) {
                break
            }
            $element.Value
        }
    ) -join ';'
    $completions = @(switch ($command) {
            'op' {
                [CompletionResult]::new('--account', 'account', [CompletionResultType]::ParameterName, 'Select the `account` to execute the command by account shorthand, sign-in address, account ID, or user ID. For a list of available accounts, run ''op account list''. Can be set as the OP_ACCOUNT environment variable.')
                [CompletionResult]::new('--cache', 'cache', [CompletionResultType]::ParameterName, 'Store and use cached information. Cache is enabled by default. The cache is not available on Windows.')
                [CompletionResult]::new('--config', 'config', [CompletionResultType]::ParameterName, 'Use this configuration `directory`.')
                [CompletionResult]::new('--debug', 'debug', [CompletionResultType]::ParameterName, 'Enable debug mode. Can also be enabled by setting the OP_DEBUG environment variable to true.')
                [CompletionResult]::new('--encoding', 'encoding', [CompletionResultType]::ParameterName, 'Use this character encoding `type`. Default: UTF-8. Supported: SHIFT_JIS, gbk.')
                [CompletionResult]::new('--format', 'format', [CompletionResultType]::ParameterName, 'Use this output format. Can be ''human-readable'' or ''json''. Can be set as the OP_FORMAT environment variable.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help for op.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help for op.')
                [CompletionResult]::new('--iso-timestamps', 'iso-timestamps', [CompletionResultType]::ParameterName, 'Format timestamps according to ISO 8601 / RFC 3339. Can be set as the OP_ISO_TIMESTAMPS environment variable.')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Print output without color.')
                [CompletionResult]::new('--session', 'session', [CompletionResultType]::ParameterName, 'Authenticate with this session `token`. 1Password CLI outputs session tokens for successful ''op signin'' commands when 1Password app integration is not enabled.')
                [CompletionResult]::new('account', 'account', [CompletionResultType]::ParameterValue, 'Manage your locally configured 1Password accounts')
                [CompletionResult]::new('completion', 'completion', [CompletionResultType]::ParameterValue, 'Generate shell completion information')
                [CompletionResult]::new('connect', 'connect', [CompletionResultType]::ParameterValue, 'Manage Connect instances and Connect tokens in your 1Password account')
                [CompletionResult]::new('document', 'document', [CompletionResultType]::ParameterValue, 'Perform CRUD operations on Document items in your vaults')
                [CompletionResult]::new('env', 'env', [CompletionResultType]::ParameterValue, 'Environment-related commands')
                [CompletionResult]::new('events-api', 'events-api', [CompletionResultType]::ParameterValue, 'Manage Events API integrations in your 1Password account')
                [CompletionResult]::new('group', 'group', [CompletionResultType]::ParameterValue, 'Manage the groups in your 1Password account')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Get help for a command')
                [CompletionResult]::new('inject', 'inject', [CompletionResultType]::ParameterValue, 'Inject secrets into a config file')
                [CompletionResult]::new('item', 'item', [CompletionResultType]::ParameterValue, 'Perform CRUD operations on the 1Password items in your vaults')
                [CompletionResult]::new('plugin', 'plugin', [CompletionResultType]::ParameterValue, 'Manage the shell plugins you use to authenticate third-party CLIs')
                [CompletionResult]::new('read', 'read', [CompletionResultType]::ParameterValue, 'Read a secret using the secrets reference syntax')
                [CompletionResult]::new('run', 'run', [CompletionResultType]::ParameterValue, 'Pass secrets as environment variables to a process')
                [CompletionResult]::new('signin', 'signin', [CompletionResultType]::ParameterValue, 'Sign in to a 1Password account')
                [CompletionResult]::new('signout', 'signout', [CompletionResultType]::ParameterValue, 'Sign out of a 1Password account')
                [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Check for and download updates.')
                [CompletionResult]::new('user', 'user', [CompletionResultType]::ParameterValue, 'Manage users within this 1Password account')
                [CompletionResult]::new('vault', 'vault', [CompletionResultType]::ParameterValue, 'Manage permissions and perform CRUD operations on your 1Password vaults')
                [CompletionResult]::new('whoami', 'whoami', [CompletionResultType]::ParameterValue, 'Get information about a signed-in account')
                break
            }
            'op;account' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with account.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with account.')
                [CompletionResult]::new('add', 'add', [CompletionResultType]::ParameterValue, 'Add an account to sign in to for the first time')
                [CompletionResult]::new('forget', 'forget', [CompletionResultType]::ParameterValue, 'Remove a 1Password account from this device')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get details about your account')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List users and accounts set up on this device')
                break
            }
            'op;account;add' {
                [CompletionResult]::new('--address', 'address', [CompletionResultType]::ParameterName, 'The sign-in address for your account.')
                [CompletionResult]::new('--email', 'email', [CompletionResultType]::ParameterName, 'The email address associated with your account.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with account add.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with account add.')
                [CompletionResult]::new('--raw', 'raw', [CompletionResultType]::ParameterName, 'Only return the session token.')
                [CompletionResult]::new('--shorthand', 'shorthand', [CompletionResultType]::ParameterName, 'Set the short account name.')
                [CompletionResult]::new('--signin', 'signin', [CompletionResultType]::ParameterName, 'Directly sign in to the added account.')
                break
            }
            'op;account;forget' {
                [CompletionResult]::new('--all', 'all', [CompletionResultType]::ParameterName, 'Forget all authenticated accounts.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with account forget.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with account forget.')
                break
            }
            'op;account;get' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with account get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with account get.')
                break
            }
            'op;account;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with account list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with account list.')
                break
            }
            'op;completion' {
                [CompletionResult]::new('--account', 'account', [CompletionResultType]::ParameterName, 'Select the `account` to execute the command by account shorthand, sign-in address, account ID, or user ID. For a list of available accounts, run ''op account list''. Can be set as the OP_ACCOUNT environment variable.')
                [CompletionResult]::new('--cache', 'cache', [CompletionResultType]::ParameterName, 'Store and use cached information. Cache is enabled by default. The cache is not available on Windows.')
                [CompletionResult]::new('--config', 'config', [CompletionResultType]::ParameterName, 'Use this configuration `directory`.')
                [CompletionResult]::new('--debug', 'debug', [CompletionResultType]::ParameterName, 'Enable debug mode. Can also be enabled by setting the OP_DEBUG environment variable to true.')
                [CompletionResult]::new('--encoding', 'encoding', [CompletionResultType]::ParameterName, 'Use this character encoding `type`. Default: UTF-8. Supported: SHIFT_JIS, gbk.')
                [CompletionResult]::new('--format', 'format', [CompletionResultType]::ParameterName, 'Use this output format. Can be ''human-readable'' or ''json''. Can be set as the OP_FORMAT environment variable.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with completion.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with completion.')
                [CompletionResult]::new('--iso-timestamps', 'iso-timestamps', [CompletionResultType]::ParameterName, 'Format timestamps according to ISO 8601 / RFC 3339. Can be set as the OP_ISO_TIMESTAMPS environment variable.')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Print output without color.')
                [CompletionResult]::new('--session', 'session', [CompletionResultType]::ParameterName, 'Authenticate with this session `token`. 1Password CLI outputs session tokens for successful ''op signin'' commands when 1Password app integration is not enabled.')
                break
            }
            'op;connect' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect.')
                [CompletionResult]::new('group', 'group', [CompletionResultType]::ParameterValue, 'Manage group access to Secrets Automation')
                [CompletionResult]::new('server', 'server', [CompletionResultType]::ParameterValue, 'Manage Connect servers')
                [CompletionResult]::new('token', 'token', [CompletionResultType]::ParameterValue, 'Manage Connect tokens')
                [CompletionResult]::new('vault', 'vault', [CompletionResultType]::ParameterValue, 'Manage connect server vault access')
                break
            }
            'op;connect;group' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect group.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect group.')
                [CompletionResult]::new('grant', 'grant', [CompletionResultType]::ParameterValue, 'Grant a group access to manage Secrets Automation')
                [CompletionResult]::new('revoke', 'revoke', [CompletionResultType]::ParameterValue, 'Revoke a group''s access to manage Secrets Automation')
                break
            }
            'op;connect;group;grant' {
                [CompletionResult]::new('--all-servers', 'all-servers', [CompletionResultType]::ParameterName, 'Grant access to all current and future servers in the authenticated account.')
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'The `group` to receive access.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect group grant.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect group grant.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'The `server` to grant access to.')
                break
            }
            'op;connect;group;revoke' {
                [CompletionResult]::new('--all-servers', 'all-servers', [CompletionResultType]::ParameterName, 'Revoke access to all current and future servers in the authenticated account.')
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'The `group` to revoke access from.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect group revoke.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect group revoke.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'The `server` to revoke access to.')
                break
            }
            'op;connect;server' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect server.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect server.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Set up a Connect server')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Remove a Connect server')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Rename a Connect server')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get a Connect server')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List Connect servers')
                break
            }
            'op;connect;server;create' {
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation when overwriting credential files.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation when overwriting credential files.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect server create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect server create.')
                [CompletionResult]::new('--vaults', 'vaults', [CompletionResultType]::ParameterName, 'Grant the Connect server access to these vaults.')
                break
            }
            'op;connect;server;delete' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect server delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect server delete.')
                break
            }
            'op;connect;server;edit' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect server edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect server edit.')
                [CompletionResult]::new('--name', 'name', [CompletionResultType]::ParameterName, 'Change the server''s `name`.')
                break
            }
            'op;connect;server;get' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect server get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect server get.')
                break
            }
            'op;connect;server;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect server list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect server list.')
                break
            }
            'op;connect;token' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect token.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect token.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Issue a token for a 1Password Connect server')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Revoke a token for a Connect server')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Rename a Connect token')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Get a list of tokens')
                break
            }
            'op;connect;token;create' {
                [CompletionResult]::new('--expires-in', 'expires-in', [CompletionResultType]::ParameterName, 'Set how long the Connect token is valid for in (s)econds, (m)inutes, or (h)ours.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect token create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect token create.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'Issue a token for this server.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Issue a token on these vaults.')
                break
            }
            'op;connect;token;delete' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect token delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect token delete.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'Only look for tokens for this 1Password Connect server.')
                break
            }
            'op;connect;token;edit' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect token edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect token edit.')
                [CompletionResult]::new('--name', 'name', [CompletionResultType]::ParameterName, 'Change the token''s name.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'Only look for tokens for this 1Password Connect server.')
                break
            }
            'op;connect;token;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect token list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect token list.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'Only list tokens for this Connect `server`.')
                break
            }
            'op;connect;vault' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect vault.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect vault.')
                [CompletionResult]::new('grant', 'grant', [CompletionResultType]::ParameterValue, 'Grant a Connect server access to a vault')
                [CompletionResult]::new('revoke', 'revoke', [CompletionResultType]::ParameterValue, 'Revoke a Connect server''s access to a vault')
                break
            }
            'op;connect;vault;grant' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect vault grant.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect vault grant.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'The server to be granted access.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'The vault to grant access to.')
                break
            }
            'op;connect;vault;revoke' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with connect vault revoke.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with connect vault revoke.')
                [CompletionResult]::new('--server', 'server', [CompletionResultType]::ParameterName, 'The `server` to revoke access from.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'The `vault` to revoke a server''s access to.')
                break
            }
            'op;document' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with document.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with document.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Create a document item')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Delete or archive a document item')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a document item')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Download a document')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Get a list of documents')
                break
            }
            'op;document;create' {
                [CompletionResult]::new('--file-name', 'file-name', [CompletionResultType]::ParameterName, 'Set the file''s `name`.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with document create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with document create.')
                [CompletionResult]::new('--tags', 'tags', [CompletionResultType]::ParameterName, 'Set the tags to the specified (comma-separated) values.')
                [CompletionResult]::new('--title', 'title', [CompletionResultType]::ParameterName, 'Set the document item''s `title`.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Save the document in this `vault`. Default: Private.')
                break
            }
            'op;document;delete' {
                [CompletionResult]::new('--archive', 'archive', [CompletionResultType]::ParameterName, 'Move the document to the Archive.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with document delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with document delete.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Delete the document in this `vault`.')
                break
            }
            'op;document;edit' {
                [CompletionResult]::new('--file-name', 'file-name', [CompletionResultType]::ParameterName, 'Set the file''s `name`.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with document edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with document edit.')
                [CompletionResult]::new('--tags', 'tags', [CompletionResultType]::ParameterName, 'Set the tags to the specified (comma-separated) values. An empty value will remove all tags.')
                [CompletionResult]::new('--title', 'title', [CompletionResultType]::ParameterName, 'Set the document item''s `title`.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Look up document in this `vault`.')
                break
            }
            'op;document;get' {
                [CompletionResult]::new('--file-mode', 'file-mode', [CompletionResultType]::ParameterName, 'Set filemode for the output file. It is ignored without the --out-file flag.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Forcibly print an unintelligible document to an interactive terminal. If --out-file is specified, save the document to a file without prompting for confirmation.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with document get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with document get.')
                [CompletionResult]::new('--include-archive', 'include-archive', [CompletionResultType]::ParameterName, 'Include document items in the Archive. Can also be set using OP_INCLUDE_ARCHIVE environment variable.')
                [CompletionResult]::new('-o', 'o', [CompletionResultType]::ParameterName, 'Save the document to the file `path` instead of stdout.')
                [CompletionResult]::new('--out-file', 'out-file', [CompletionResultType]::ParameterName, 'Save the document to the file `path` instead of stdout.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Look for the document in this `vault`.')
                break
            }
            'op;document;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with document list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with document list.')
                [CompletionResult]::new('--include-archive', 'include-archive', [CompletionResultType]::ParameterName, 'Include document items in the Archive. Can also be set using OP_INCLUDE_ARCHIVE environment variable.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Only list documents in this `vault`.')
                break
            }
            'op;env' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with env.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with env.')
                [CompletionResult]::new('ls', 'ls', [CompletionResultType]::ParameterValue, 'List environment variables that reference 1Password secrets using the op://<vault>/<item>[/<section>]/field format')
                break
            }
            'op;env;ls' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with env ls.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with env ls.')
                break
            }
            'op;events-api' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with events-api.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with events-api.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Set up an integration with the Events API')
                break
            }
            'op;events-api;create' {
                [CompletionResult]::new('--expires-in', 'expires-in', [CompletionResultType]::ParameterName, 'Set how the long the events-api token is valid for in (s)econds, (m)inutes, or (h)ours.')
                [CompletionResult]::new('--features', 'features', [CompletionResultType]::ParameterName, 'Set the comma-separated list of `features` the integration token can be used for. Options: ''signinattempts'', ''itemusages'', ''auditevents''.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with events-api create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with events-api create.')
                break
            }
            'op;group' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Create a group')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Remove a group')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a group''s name or description')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get details about a group')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List groups')
                [CompletionResult]::new('user', 'user', [CompletionResultType]::ParameterValue, 'Manage group membership')
                break
            }
            'op;group;create' {
                [CompletionResult]::new('--description', 'description', [CompletionResultType]::ParameterName, 'Set the group''s description.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group create.')
                break
            }
            'op;group;delete' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group delete.')
                break
            }
            'op;group;edit' {
                [CompletionResult]::new('--description', 'description', [CompletionResultType]::ParameterName, 'Change the group''s `description`.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group edit.')
                [CompletionResult]::new('--name', 'name', [CompletionResultType]::ParameterName, 'Change the group''s `name`.')
                break
            }
            'op;group;get' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group get.')
                break
            }
            'op;group;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group list.')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'List groups that a `user` belongs to.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'List groups that have direct access to a `vault`.')
                break
            }
            'op;group;user' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group user.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group user.')
                [CompletionResult]::new('grant', 'grant', [CompletionResultType]::ParameterValue, 'Add a user to a group')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Retrieve users that belong to a group')
                [CompletionResult]::new('revoke', 'revoke', [CompletionResultType]::ParameterValue, 'Remove a user from a group')
                break
            }
            'op;group;user;grant' {
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'Specify the group to add the user to.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group user grant.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group user grant.')
                [CompletionResult]::new('--role', 'role', [CompletionResultType]::ParameterName, 'Specify the user''s role as a member or manager. Default: member.')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'Specify the user to add to the group.')
                break
            }
            'op;group;user;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group user list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group user list.')
                break
            }
            'op;group;user;revoke' {
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'Specify the group to remove the user from.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with group user revoke.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with group user revoke.')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'Specify the user to remove from the group.')
                break
            }
            'op;help' {
                break
            }
            'op;inject' {
                [CompletionResult]::new('--file-mode', 'file-mode', [CompletionResultType]::ParameterName, 'Set filemode for the output file. It is ignored without the --out-file flag.')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with inject.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with inject.')
                [CompletionResult]::new('-i', 'i', [CompletionResultType]::ParameterName, 'The filename of a template file to inject.')
                [CompletionResult]::new('--in-file', 'in-file', [CompletionResultType]::ParameterName, 'The filename of a template file to inject.')
                [CompletionResult]::new('-o', 'o', [CompletionResultType]::ParameterName, 'Write the injected template to a file instead of stdout.')
                [CompletionResult]::new('--out-file', 'out-file', [CompletionResultType]::ParameterName, 'Write the injected template to a file instead of stdout.')
                break
            }
            'op;item' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Create an item')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Delete or archive an item')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit an item''s details')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get an item''s details')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List items')
                [CompletionResult]::new('share', 'share', [CompletionResultType]::ParameterValue, 'Share an item')
                [CompletionResult]::new('template', 'template', [CompletionResultType]::ParameterValue, 'Manage templates')
                break
            }
            'op;item;create' {
                [CompletionResult]::new('--category', 'category', [CompletionResultType]::ParameterName, 'Set the item''s `category`.')
                [CompletionResult]::new('--dry-run', 'dry-run', [CompletionResultType]::ParameterName, 'Perform a dry run of the command and output a preview of the resulting item.')
                [CompletionResult]::new('--generate-password', 'generate-password', [CompletionResultType]::ParameterName, 'Give the item a randomly generated password.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item create.')
                [CompletionResult]::new('--tags', 'tags', [CompletionResultType]::ParameterName, 'Set the tags to the specified (comma-separated) values.')
                [CompletionResult]::new('--template', 'template', [CompletionResultType]::ParameterName, 'Specify the filepath to read an item template from.')
                [CompletionResult]::new('--title', 'title', [CompletionResultType]::ParameterName, 'Set the item''s `title`.')
                [CompletionResult]::new('--url', 'url', [CompletionResultType]::ParameterName, 'Set the `URL` associated with the item')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Save the item in this `vault`. Default: Private.')
                break
            }
            'op;item;delete' {
                [CompletionResult]::new('--archive', 'archive', [CompletionResultType]::ParameterName, 'Move the item to the Archive.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item delete.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Look for the item in this vault.')
                break
            }
            'op;item;edit' {
                [CompletionResult]::new('--dry-run', 'dry-run', [CompletionResultType]::ParameterName, 'Perform a dry run of the command and output a preview of the resulting item.')
                [CompletionResult]::new('--generate-password', 'generate-password', [CompletionResultType]::ParameterName, 'Give the item a randomly generated password.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item edit.')
                [CompletionResult]::new('--tags', 'tags', [CompletionResultType]::ParameterName, 'Set the tags to the specified (comma-separated) values. An empty value will remove all tags.')
                [CompletionResult]::new('--title', 'title', [CompletionResultType]::ParameterName, 'Set the item''s `title`.')
                [CompletionResult]::new('--url', 'url', [CompletionResultType]::ParameterName, 'Set the `URL` associated with the item')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Edit the item in this `vault`.')
                break
            }
            'op;item;get' {
                [CompletionResult]::new('--fields', 'fields', [CompletionResultType]::ParameterName, 'Only return data from these `fields`. Use ''label='' to get the field by name or ''type='' to filter fields by type.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item get.')
                [CompletionResult]::new('--include-archive', 'include-archive', [CompletionResultType]::ParameterName, 'Include items in the Archive. Can also be set using OP_INCLUDE_ARCHIVE environment variable.')
                [CompletionResult]::new('--otp', 'otp', [CompletionResultType]::ParameterName, 'Output the primary one-time password for this item.')
                [CompletionResult]::new('--share-link', 'share-link', [CompletionResultType]::ParameterName, 'Get a shareable link for the item.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Look for the item in this `vault`.')
                break
            }
            'op;item;list' {
                [CompletionResult]::new('--categories', 'categories', [CompletionResultType]::ParameterName, 'Only list items in these `categories` (comma-separated).')
                [CompletionResult]::new('--favorite', 'favorite', [CompletionResultType]::ParameterName, 'Only list favorite items')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item list.')
                [CompletionResult]::new('--include-archive', 'include-archive', [CompletionResultType]::ParameterName, 'Include items in the Archive. Can also be set using OP_INCLUDE_ARCHIVE environment variable.')
                [CompletionResult]::new('--long', 'long', [CompletionResultType]::ParameterName, 'Output a more detailed item list.')
                [CompletionResult]::new('--tags', 'tags', [CompletionResultType]::ParameterName, 'Only list items with these `tags` (comma-separated).')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Only list items in this `vault`.')
                break
            }
            'op;item;share' {
                [CompletionResult]::new('--emails', 'emails', [CompletionResultType]::ParameterName, 'Email addresses to share with.')
                [CompletionResult]::new('--expiry', 'expiry', [CompletionResultType]::ParameterName, 'Link expiring after the specified duration in (s)econds, (m)inutes, or (h)ours (default 7h).')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item share.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item share.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'Look for the item in this vault.')
                [CompletionResult]::new('--view-once', 'view-once', [CompletionResultType]::ParameterName, 'Expire link after a single view.')
                break
            }
            'op;item;template' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item template.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item template.')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get an item template')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Get a list of templates')
                break
            }
            'op;item;template;get' {
                [CompletionResult]::new('--file-mode', 'file-mode', [CompletionResultType]::ParameterName, 'Set filemode for the output file. It is ignored without the --out-file flag.')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item template get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item template get.')
                [CompletionResult]::new('-o', 'o', [CompletionResultType]::ParameterName, 'Write the template to a file instead of stdout.')
                [CompletionResult]::new('--out-file', 'out-file', [CompletionResultType]::ParameterName, 'Write the template to a file instead of stdout.')
                break
            }
            'op;item;template;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with item template list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with item template list.')
                break
            }
            'op;plugin' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin.')
                [CompletionResult]::new('clear', 'clear', [CompletionResultType]::ParameterValue, 'Clear shell plugin configuration')
                [CompletionResult]::new('credential', 'credential', [CompletionResultType]::ParameterValue, 'Manage credentials for shell plugins')
                [CompletionResult]::new('init', 'init', [CompletionResultType]::ParameterValue, 'Get started with 1Password Shell Plugins')
                [CompletionResult]::new('inspect', 'inspect', [CompletionResultType]::ParameterValue, 'Inspect your existing shell plugin configurations')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List all available shell plugins')
                [CompletionResult]::new('run', 'run', [CompletionResultType]::ParameterValue, 'Provision credentials from 1Password and run this command')
                break
            }
            'op;plugin;clear' {
                [CompletionResult]::new('--all', 'all', [CompletionResultType]::ParameterName, 'Clear all configurations for this plugin that apply to this directory and/or terminal session, including the global default.')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Apply immediately without asking for confirmation.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Apply immediately without asking for confirmation.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin clear.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin clear.')
                break
            }
            'op;plugin;credential' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin credential.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin credential.')
                [CompletionResult]::new('import', 'import', [CompletionResultType]::ParameterValue, 'Import credentials for a shell plugin')
                break
            }
            'op;plugin;credential;import' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin credential import.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin credential import.')
                break
            }
            'op;plugin;init' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin init.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin init.')
                break
            }
            'op;plugin;inspect' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin inspect.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin inspect.')
                break
            }
            'op;plugin;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin list.')
                break
            }
            'op;plugin;run' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with plugin run.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with plugin run.')
                break
            }
            'op;read' {
                [CompletionResult]::new('--file-mode', 'file-mode', [CompletionResultType]::ParameterName, 'Set filemode for the output file. It is ignored without the --out-file flag.')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Do not prompt for confirmation.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with read.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with read.')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Do not print a new line after the secret.')
                [CompletionResult]::new('--no-newline', 'no-newline', [CompletionResultType]::ParameterName, 'Do not print a new line after the secret.')
                [CompletionResult]::new('-o', 'o', [CompletionResultType]::ParameterName, 'Write the secret to a file instead of stdout.')
                [CompletionResult]::new('--out-file', 'out-file', [CompletionResultType]::ParameterName, 'Write the secret to a file instead of stdout.')
                break
            }
            'op;run' {
                [CompletionResult]::new('--env-file', 'env-file', [CompletionResultType]::ParameterName, 'Enable Dotenv integration with specific Dotenv files to parse. For example: --env-file=.env.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with run.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with run.')
                [CompletionResult]::new('--no-masking', 'no-masking', [CompletionResultType]::ParameterName, 'Disable masking of secrets on stdout and stderr.')
                break
            }
            'op;signin' {
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Ignore warnings and print raw output from this command.')
                [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Ignore warnings and print raw output from this command.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with signin.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with signin.')
                [CompletionResult]::new('--raw', 'raw', [CompletionResultType]::ParameterName, 'Only return the session token.')
                break
            }
            'op;signout' {
                [CompletionResult]::new('--all', 'all', [CompletionResultType]::ParameterName, 'Sign out of all signed-in accounts.')
                [CompletionResult]::new('--forget', 'forget', [CompletionResultType]::ParameterName, 'Remove the details for a 1Password account from this device.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with signout.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with signout.')
                break
            }
            'op;update' {
                [CompletionResult]::new('--channel', 'channel', [CompletionResultType]::ParameterName, 'Look for updates from a specific channel. allowed: stable, beta')
                [CompletionResult]::new('--directory', 'directory', [CompletionResultType]::ParameterName, 'Download the update to this ''''path''''.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with update.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with update.')
                break
            }
            'op;user' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user.')
                [CompletionResult]::new('confirm', 'confirm', [CompletionResultType]::ParameterValue, 'Confirm a user')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Remove a user and all their data from the account')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a user''s name or Travel Mode status')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get details about a user')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List users')
                [CompletionResult]::new('provision', 'provision', [CompletionResultType]::ParameterValue, 'Provision a user in the authenticated account')
                [CompletionResult]::new('reactivate', 'reactivate', [CompletionResultType]::ParameterValue, 'Reactivate a suspended user')
                [CompletionResult]::new('suspend', 'suspend', [CompletionResultType]::ParameterValue, 'Suspend a user')
                break
            }
            'op;user;confirm' {
                [CompletionResult]::new('--all', 'all', [CompletionResultType]::ParameterName, 'Confirm all unconfirmed users.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user confirm.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user confirm.')
                break
            }
            'op;user;delete' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user delete.')
                break
            }
            'op;user;edit' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user edit.')
                [CompletionResult]::new('--name', 'name', [CompletionResultType]::ParameterName, 'Set the user''s name.')
                [CompletionResult]::new('--travel-mode', 'travel-mode', [CompletionResultType]::ParameterName, 'Turn Travel Mode on or off for the user.')
                break
            }
            'op;user;get' {
                [CompletionResult]::new('--fingerprint', 'fingerprint', [CompletionResultType]::ParameterName, 'Get the user''s public key fingerprint.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user get.')
                [CompletionResult]::new('--me', 'me', [CompletionResultType]::ParameterName, 'Get the authenticated user''s details.')
                [CompletionResult]::new('--public-key', 'public-key', [CompletionResultType]::ParameterName, 'Get the user''s public key.')
                break
            }
            'op;user;list' {
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'List users who belong to a `group`.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user list.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'List users who have direct access to `vault`.')
                break
            }
            'op;user;provision' {
                [CompletionResult]::new('--email', 'email', [CompletionResultType]::ParameterName, 'Provide the user''s email address.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user provision.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user provision.')
                [CompletionResult]::new('--language', 'language', [CompletionResultType]::ParameterName, 'Provide the user''s account language.')
                [CompletionResult]::new('--name', 'name', [CompletionResultType]::ParameterName, 'Provide the user''s name.')
                break
            }
            'op;user;reactivate' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user reactivate.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user reactivate.')
                break
            }
            'op;user;suspend' {
                [CompletionResult]::new('--deauthorize-devices-after', 'deauthorize-devices-after', [CompletionResultType]::ParameterName, 'Deauthorize the user''s devices after a time (rounded down to seconds).')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with user suspend.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with user suspend.')
                break
            }
            'op;vault' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault.')
                [CompletionResult]::new('create', 'create', [CompletionResultType]::ParameterValue, 'Create a new vault')
                [CompletionResult]::new('delete', 'delete', [CompletionResultType]::ParameterValue, 'Remove a vault')
                [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a vault''s name, description, icon or Travel Mode status')
                [CompletionResult]::new('get', 'get', [CompletionResultType]::ParameterValue, 'Get details about a vault')
                [CompletionResult]::new('group', 'group', [CompletionResultType]::ParameterValue, 'Manage group vault access')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List all vaults in the account')
                [CompletionResult]::new('user', 'user', [CompletionResultType]::ParameterValue, 'Manage user vault access')
                break
            }
            'op;vault;create' {
                [CompletionResult]::new('--allow-admins-to-manage', 'allow-admins-to-manage', [CompletionResultType]::ParameterName, 'Set whether administrators can manage the vault. If not provided, the default policy for the account applies.')
                [CompletionResult]::new('--description', 'description', [CompletionResultType]::ParameterName, 'Set the group''s `description`.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault create.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault create.')
                [CompletionResult]::new('--icon', 'icon', [CompletionResultType]::ParameterName, 'Set the vault icon.')
                break
            }
            'op;vault;delete' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault delete.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault delete.')
                break
            }
            'op;vault;edit' {
                [CompletionResult]::new('--description', 'description', [CompletionResultType]::ParameterName, 'Change the vault''s `description`.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault edit.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault edit.')
                [CompletionResult]::new('--icon', 'icon', [CompletionResultType]::ParameterName, 'Change the vault''s `icon`.')
                [CompletionResult]::new('--name', 'name', [CompletionResultType]::ParameterName, 'Change the vault''s `name`.')
                [CompletionResult]::new('--travel-mode', 'travel-mode', [CompletionResultType]::ParameterName, 'Turn Travel Mode on or off for the vault. Only vaults with Travel Mode enabled will be accessible while a user has Travel Mode turned on.')
                break
            }
            'op;vault;get' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault get.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault get.')
                break
            }
            'op;vault;group' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault group.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault group.')
                [CompletionResult]::new('grant', 'grant', [CompletionResultType]::ParameterValue, 'Grant a group permissions to a vault')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List all the groups that have access to the given vault')
                [CompletionResult]::new('revoke', 'revoke', [CompletionResultType]::ParameterValue, 'Revoke a portion or the entire access of a group to a vault')
                break
            }
            'op;vault;group;grant' {
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'The `group` to receive access.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault group grant.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault group grant.')
                [CompletionResult]::new('--no-input', 'no-input', [CompletionResultType]::ParameterName, 'Do not prompt for `input` on interactive terminal.')
                [CompletionResult]::new('--permissions', 'permissions', [CompletionResultType]::ParameterName, 'The `permissions` to grant to the group.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'The `vault` to grant group permissions to.')
                break
            }
            'op;vault;group;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault group list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault group list.')
                break
            }
            'op;vault;group;revoke' {
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'The `group` to revoke access from.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault group revoke.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault group revoke.')
                [CompletionResult]::new('--no-input', 'no-input', [CompletionResultType]::ParameterName, 'Do not prompt for `input` on interactive terminal.')
                [CompletionResult]::new('--permissions', 'permissions', [CompletionResultType]::ParameterName, 'The `permissions` to revoke from the group.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'The `vault` to revoke access to.')
                break
            }
            'op;vault;list' {
                [CompletionResult]::new('--group', 'group', [CompletionResultType]::ParameterName, 'List vaults a group has access to.')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault list.')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'List vaults that a given user has access to.')
                break
            }
            'op;vault;user' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault user.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault user.')
                [CompletionResult]::new('grant', 'grant', [CompletionResultType]::ParameterValue, 'Grant a user access to a vault')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List all users with access to the vault and their permissions')
                [CompletionResult]::new('revoke', 'revoke', [CompletionResultType]::ParameterValue, 'Revoke a portion or the entire access of a user to a vault')
                break
            }
            'op;vault;user;grant' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault user grant.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault user grant.')
                [CompletionResult]::new('--no-input', 'no-input', [CompletionResultType]::ParameterName, 'Do not prompt for `input` on interactive terminal.')
                [CompletionResult]::new('--permissions', 'permissions', [CompletionResultType]::ParameterName, 'The `permissions` to grant to the user.')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'The `user` to receive access.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'The `vault` to grant access to.')
                break
            }
            'op;vault;user;list' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault user list.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault user list.')
                break
            }
            'op;vault;user;revoke' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with vault user revoke.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with vault user revoke.')
                [CompletionResult]::new('--no-input', 'no-input', [CompletionResultType]::ParameterName, 'Do not prompt for `input` on interactive terminal.')
                [CompletionResult]::new('--permissions', 'permissions', [CompletionResultType]::ParameterName, 'The `permissions` to revoke from the user.')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'The `user` to revoke access from.')
                [CompletionResult]::new('--vault', 'vault', [CompletionResultType]::ParameterName, 'The `vault` to revoke access to.')
                break
            }
            'op;whoami' {
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Get help with whoami.')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Get help with whoami.')
                break
            }
        })
    $completions.Where{ $_.CompletionText -like "$wordToComplete*" } |
    Sort-Object -Property ListItemText
}
