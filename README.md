# PSProfile

A cross-platform PowerShell profile for Windows, macOS and Linux. One script (`profile2.0.ps1`) reads a layered JSON config and sets up the prompt, PSReadLine, tab completion, history search, modules and aliases. It also adds 120+ helper functions for networking, diagnostics, files, git and Windows administration.

It runs on Windows PowerShell 5.1 and PowerShell 7. Functions load on first use, and slow work is cached or deferred until the prompt is idle, so new shells open quickly.

- [Install](#install)
- [What a new shell shows](#what-a-new-shell-shows)
- [Lifecycle: update, roll back, uninstall](#lifecycle-update-roll-back-uninstall)
- [Configuration](#configuration)
- [Prompt and theme](#prompt-and-theme)
- [Tab completion](#tab-completion)
- [History, navigation and key bindings](#history-navigation-and-key-bindings)
- [Secrets](#secrets)
- [Command reference](#command-reference)
- [Troubleshooting](#troubleshooting)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [Credits](#credits) · [License](#license)

## Install

```powershell
irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex
```

Run it from Windows PowerShell 5.1 or PowerShell 7 on any OS. It's safe to re-run. Setup:

1. Puts the repo in `~/.config/powershell/PSProfile`, with `git clone` if git is available or a zip download otherwise.
2. Creates a near-empty `assets/config/config.json` for your settings, if you don't have one. Existing configs are never touched.
3. Adds a line to `$PROFILE.CurrentUserAllHosts` that loads `profile2.0.ps1`. An existing profile is backed up to `<profile>.bak-<timestamp>`, and its content is kept below the new line.
4. On Windows, sets the current user's execution policy to `RemoteSigned` if the effective policy is `Restricted` (Windows PowerShell 5.1's default, which blocks profiles).
5. Installs missing [Modules](#modules) and [Packages](#packages) from your config, plus the modules the profile always needs: PSReadLine 2.4.5+ on Windows PowerShell 5.1, and `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore` everywhere. When it installs anything, it also registers SecretStore as the default secret vault if you have none. On Linux, `apt`/`dnf`/`yum`/`pacman` run through `sudo`, so expect a password prompt.
6. Loads the profile once in a separate process to check it and build its caches.

Example output:

```text
==> Cloning https://github.com/reave/PSProfile to /home/user/.config/powershell/PSProfile
==> Creating personal config at .../assets/config/config.json (add only the settings you want to change)
==> Linking /home/user/.config/powershell/profile.ps1 to .../profile2.0.ps1
==> Installing configured modules and packages that are missing
Installed module PSFzf
Installed package fzf via brew
Registered SecretStore as the default secret vault. Store API keys with Set-Secret.
==> Loading the profile once to check it and build its caches

PSProfile installed at /home/user/.config/powershell/PSProfile
Restart your shell (or run ". $PROFILE") to load it.
```

### Setup options

Pass parameters by running the script as a script block:

```powershell
&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -InstallPath 'C:\PSProfile' -Branch 'develop'
```

| Parameter | Effect |
|---|---|
| `-InstallPath <path>` | Install somewhere other than `~/.config/powershell/PSProfile`. |
| `-Branch <name>` | Install another branch. Applies to a fresh clone or a zip install; re-running over a git install pulls whatever branch is checked out. |
| `-SkipProfileLink` | Don't touch `$PROFILE`. Dot-source `profile2.0.ps1` yourself. |
| `-SkipDependencies` | Don't install modules or packages. |
| `-Uninstall` | Remove PSProfile. See [Uninstall](#uninstall). |
| `-Force` | With `-Uninstall`, skip the confirmation prompt. |

### Manual install

```powershell
git clone https://github.com/reave/PSProfile.git ~/.config/powershell/PSProfile
# then add this line to $PROFILE.CurrentUserAllHosts:
. "$HOME/.config/powershell/PSProfile/profile2.0.ps1"
```

Then run `Update-Profile` once to install dependencies.

## What a new shell shows

In an interactive terminal, depending on [settings](#settings):

```text
<splash screen from winfetch / fastfetch / screenfetch>
--------------------------------------------
  THIS CONSOLE IS AN ELEVATED CONSOLE.
---------------------------------------------
PowerShell Version: 7.6.1 - ExecutionPolicy: RemoteSigned
PSProfile: 3 new commit(s) available; missing package(s) speedtest. Run Update-Profile.
<oh-my-posh prompt>
```

- The splash runs only if its command is installed. Its output is cached (see `SplashCacheHours`).
- The elevated banner shows only when running as Administrator or root. On macOS/Linux it reads `THIS SHELL IS RUNNING AS ROOT.`
- The yellow `PSProfile:` line appears only when there's something to act on: an update, a missing package, or a missing module.
- The window title becomes `PowerShell <version>`, with `[ADMIN]` or `[ROOT]` when elevated.

Scripts, CI runners, `pwsh -Command`, and editor-hosted shells (the VS Code extension) get none of the above, and no zoxide, Atuin or update check. They still get config, functions, modules, aliases, completion, and `DefaultParameterValues`, so functions behave the same in scripts. A shell counts as interactive when the host is `ConsoleHost` and neither stdin nor stdout is redirected.

## Lifecycle: update, roll back, uninstall

### Update notice

Once every `UpdateCheckIntervalHours` (default 24), a new shell starts a background check: `git fetch` for a git install, one GitHub API call for a zip install. It also looks for missing modules and packages. It never delays the prompt. The result appears as the yellow `PSProfile:` line in the next shell. Set the interval to `0` to turn it off.

### Update-Profile

| Command | What it does |
|---|---|
| `Update-Profile` | Update, validate, rebuild caches, install missing dependencies. |
| `Update-Profile -CheckOnly` | Report whether an update is available and what's missing. Changes nothing. |
| `Update-Profile -Rollback` | Return to the version before the last update. |
| `Update-Profile -SkipDependencies` | Update without installing modules or packages. |
| `Update-Profile -SkipValidation` | Skip the test load (files are still parse-checked). |

`Update-Profile` also supports `-WhatIf`. An update:

1. Pulls the new version: `git pull --ff-only` for a git install, or a download into a staging folder next to the install for a zip install.
2. Checks that every `.ps1` parses and that `profile2.0.ps1` loads without error in a separate, profile-less PowerShell process.
3. If that check fails, resets a git install to the previous commit (`git reset --keep`, which never discards local edits) or leaves the zip download unused, and reports what failed.
4. Rebuilds caches with the new code in that same process (`Update-PSProfileCache`, `Update-Completions`).
5. Installs missing modules and packages.

Your `config.json`, `config.local.json`, uncommitted `config.<MACHINE>.json`, and cached completions are kept across updates. A zip install keeps the previous version as `.PSProfile.previous` next to the install, for `-Rollback`.

Example output:

```text
PS> Update-Profile -CheckOnly
PSProfile update available: 3 new commit(s). Run Update-Profile to install it.
Missing dependencies: speedtest. Run Update-Profile to install them.

PS> Update-Profile
Updating 613a736..9f2c1d0
Fast-forward
...
PSProfile updated 613a736 -> 9f2c1d0.
Installed package ookla.speedtest.cli via winget
Open a new shell, or run `. $PROFILE`, to load the new version. Undo with Update-Profile -Rollback.

PS> Update-Profile -Rollback
Rolled back to the previous PSProfile version. Open a new shell to load it.
```

After a rollback, the update notice stays quiet until something newer than the version you rolled away from is published.

### Updating PowerShell itself

`Update-PowerShell` upgrades PowerShell 7 to the newest patch of the 7.6 LTS line, using winget on Windows, brew or the signed `.pkg` on macOS, and apt or dnf/yum on Linux. Run from Windows PowerShell 5.1, it checks the `pwsh` on PATH and installs PowerShell 7 if there's none.

```text
PS> Update-PowerShell -CheckOnly
PowerShell 7.6.0 can be updated to 7.6.1.
```

`-TargetVersion 7.7` tracks another line. brew, apt and dnf install whatever their repository calls latest; only winget is pinned to the exact target.

### Caches

Generated files live outside the install folder: `%LOCALAPPDATA%\PSProfile\cache` on Windows, `$XDG_CACHE_HOME/PSProfile` (default `~/.cache/PSProfile`) elsewhere. They hold the function index, oh-my-posh init, zoxide and Atuin init, splash output, and the execution policy. Update state (`update-state.json`, `update-notice.txt`) lives in the `PSProfile` folder itself.

Every cache is checked on load and rebuilt when stale. Deleting them is always safe.

| Command | What it does |
|---|---|
| `Update-PSProfileCache` | Rebuild all startup caches now. |
| `Update-Completions` | Regenerate `NativeCompletions` scripts and carapace's tool lists. Run it after installing a new CLI. |

### Uninstall

```powershell
&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -Uninstall
```

It asks first (add `-Force` to skip), then:

- Restores `$PROFILE.CurrentUserAllHosts` to its pre-PSProfile content, or deletes it if setup created it.
- Backs up your `config*.json` files next to `$PROFILE` as `PSProfile-<name>.bak-<timestamp>.json`.
- Deletes the install folder, its `.PSProfile.*` side folders, and the cache and state folder.

Installed modules and packages are left alone.

## Configuration

Settings come from up to four files in `assets/config/`, merged in order, later files winning:

| Layer | File | In git? | Use it for |
|---|---|---|---|
| Default | `sample-config.json` | Yes | Repo defaults. Don't edit; updates replace it. |
| User | `config.json` | Ignored | Your settings. |
| Machine | `config.<MACHINE>.json` | Committable | One computer's settings, named after `[Environment]::MachineName` (e.g. `config.WORKSTATION01.json`). |
| Local | `config.local.json` | Ignored | Temporary overrides on one install. |

Objects merge key by key, so a layer only needs the keys it changes:

```json
{
    "$schema": "./psprofile.schema.json",
    "settings": { "PoshTheme": "atomic" }
}
```

Arrays (`Aliases`, `Modules`, `Packages`, `NativeCompletions`) are replaced whole: a layer that sets `Modules` owns the full list. A file with a JSON error is skipped with a warning naming it. Changes apply to new shells.

```text
PS> Get-PSProfileConfig -ListLayers

Layer   Path
-----   ----
Default C:\Users\user\.config\powershell\PSProfile\assets\config\sample-config.json
User    C:\Users\user\.config\powershell\PSProfile\assets\config\config.json
Machine C:\Users\user\.config\powershell\PSProfile\assets\config\config.WORKSTATION01.json

PS> (Get-PSProfileConfig).settings.PoshTheme
M365Princess
```

`assets/config/psprofile.schema.json` describes every key. With `"$schema": "./psprofile.schema.json"` at the top of a file, VS Code offers completion and type checks.

### settings

| Key | Type | Sample default | Description |
|---|---|---|---|
| `MaximumHistoryCount` | number | `8192` | Session command history size. |
| `OneDrivePath` | string | auto | OneDrive folder, exposed as `$OneDriveRoot`. If unset or missing, the profile tries `$env:OneDriveConsumer`, `$env:OneDrive`, then `~/OneDrive`. |
| `PoshTheme` | string | `M365Princess` | oh-my-posh theme name or path to a `.omp.json`. See [Prompt and theme](#prompt-and-theme). |
| `PoshThemeOverrides` | object | `{ "shell_integration": true }` | oh-my-posh [general settings](https://ohmyposh.dev/docs/configuration/general) applied on top of the theme. |
| `ShowWindowTitle` | bool | `true` | Set the window title to the PowerShell version, plus `[ADMIN]`/`[ROOT]`. |
| `ShowSplashScreen` | bool | `true` | Show a system-info splash at startup. |
| `SplashCommand` | object | `winfetch` / `screenfetch -E` | Splash command per OS: `Windows`, `MacOS`, `Linux` keys. Skipped if the command isn't installed. |
| `SplashCacheHours` | number | `24` | Replay the cached splash until it's this old, the machine reboots, the window width changes, or the command changes. `0` runs it every time. |
| `ShowElevatedWarning` | bool | `true` | Red banner when running elevated. |
| `ShowPSVersionBanner` | bool | `true` | Print the PowerShell version and execution policy. |
| `RunUpdateHelpOnElevated` | bool | `true` | In elevated shells, run `Update-Help` at most weekly, inside the background update check. |
| `UpdateCheckIntervalHours` | number | `24` | Hours between background update checks. `0` turns the check and notice off. |
| `LazyLoadFunctions` | bool | `true` | Load each function's file on first use. `false` loads every file at startup. |
| `DefaultParameterValues` | object | CSV and help defaults | Merged into `$PSDefaultParameterValues`, e.g. `"Export-Csv:NoTypeInformation": true`. Don't put API keys here; use [Secrets](#secrets). |
| `PSReadLine` | object | see below | PSReadLine options. |
| `Zoxide` | object | `Enabled: true`, `Command: "z"` | Start zoxide if installed. `Command` names the jump command; `<Command>i` is the picker. |
| `Atuin` | object | `Enabled: false` | Start Atuin for synced history. |
| `Secrets` | object | `{}` | Where each named secret comes from. See [Secrets](#secrets). |
| `SecretVault` | string | unset | Vault for secret lookups. Unset uses your default vault. |

Every setting is optional. A setting missing from every layer is skipped, or uses the default shown where the profile has one built in (`MaximumHistoryCount`, `SplashCacheHours`, `UpdateCheckIntervalHours`, `LazyLoadFunctions`, `Zoxide`, `Atuin`).

#### settings.PSReadLine

| Key | Type | Description |
|---|---|---|
| `PredictionSource` | string | `History`, `Plugin`, `HistoryAndPlugin` (sample default) or `None`. Plugin sources need PowerShell 7.2+; older versions fall back to `History`. |
| `PredictionViewStyle` | string | `ListView` (sample default) or `InlineView`. |
| `EditMode` | string | `Windows` (sample default), `Emacs` or `Vi`. |
| `HistorySearchArrowKeys` | bool | Up/Down search history for lines starting with what you've typed. |
| `FilterSecretsFromHistory` | bool | Keep lines matching `password`, `secret`, `token`, `apikey` or `connectionstring` out of the on-disk history file. The command still runs. |
| `Colors` | object | Any keys `Set-PSReadLineOption -Colors` accepts, e.g. `"Command": "#87CEEB"`. |

These apply only in interactive shells. If the host can't apply one (for example, no virtual terminal support), the remaining options are skipped quietly.

### Aliases

```json
"Aliases": [
    { "Name": "edit", "Value": "Edit-File", "Description": "Edit a file" }
]
```

Created with `New-Alias -Force`.

### Modules

```json
"Modules": [
    { "Name": "PSFzf", "OS": "All", "PSVersionMajor": "5", "RequiresCommand": "fzf" }
]
```

Each entry that applies to this machine is imported at startup if it's installed. Missing ones are listed in the startup notice and installed by `setup.ps1` or `Update-Profile` (`Install-Module -Scope CurrentUser`), never at startup.

| Field | Description |
|---|---|
| `Name` | Module name. |
| `Description` | Free text. |
| `OS` | `Windows`, `MacOS`, `Linux`, `All`, or a comma-separated list. |
| `PSVersionMajor` | Minimum PowerShell major version. |
| `PSVersionMajorMax` | Maximum PowerShell major version (e.g. `5` for a 5.1-only module). |
| `DeferImport` | `true` imports just after the prompt appears. `Microsoft.WinGet.CommandNotFound`, `PSFzf` and `CompletionPredictor` default to `true`. Don't defer a module your prompt depends on. |
| `RequiresCommand` | Skip the import when this executable isn't on PATH. |

The sample config imports `TabExpansionPlusPlus` (5.1 only), `Microsoft.WinGet.CommandNotFound` (Windows), `PSFzf`, and `CompletionPredictor` (7.2+).

### Packages

```json
"Packages": [
    { "Name": "fzf", "Id": "junegunn.fzf", "Source": "winget" },
    { "Name": "fzf", "Id": "fzf",          "Source": "brew" }
]
```

| Field | Description |
|---|---|
| `Name` | Command used to check whether it's installed. |
| `Id` | Package identifier for the package manager. |
| `Source` | `winget`, `brew`, `apt`, `yum` (uses `dnf` when present) or `pacman`. |

An entry only applies where its package manager exists, so one list can hold an entry per manager. Packages are installed by `setup.ps1` and `Update-Profile` only. The sample config installs `speedtest`, `fzf` and `zoxide`.

### NativeCompletions

```json
"NativeCompletions": [
    { "Name": "docker", "GenerateCommand": "docker completion powershell" }
]
```

For CLIs that print their own PowerShell completion script. `Update-Completions` runs each `GenerateCommand` for installed tools and caches the output; tools that aren't installed are skipped. The sample lists `docker`, `kubectl`, `gh` and `helm`.

```text
PS> Update-Completions
Updated completion: docker
Updated completion: gh
Updated carapace completions: 41 installed tools of 702
```

### Carapace

A top-level `"Carapace": false` stops the profile from using [carapace](https://carapace.sh) even when it's installed. Default `true`.

## Prompt and theme

oh-my-posh draws the prompt when it's installed and `PoshTheme` is set. `PoshTheme` takes a theme name (looked up under `$env:POSH_THEMES_PATH`) or a path to a `.omp.json` file. If the theme can't be found, oh-my-posh's default theme is used, with a warning. The Homebrew package doesn't set `POSH_THEMES_PATH`, so on macOS/Linux use a full path or set the variable yourself.

`PoshThemeOverrides` changes oh-my-posh general settings without editing the theme; the profile writes an overridden copy of the theme to its cache folder. Only JSON themes can be overridden. The sample turns on `shell_integration`, which gives Windows Terminal, VS Code, WezTerm and iTerm2 command marks: jump between commands, select a command's output, and see exit-code marks in the scrollbar.

Two oh-my-posh settings slow startup and are off by default:

- `"streaming": <ms>` fills slow segments (git in a large repo) in after the prompt appears, but starts a background `oh-my-posh serve` process in every shell.
- `"async": true` shows a plain `PS>` for the first prompt of each shell.

## Tab completion

Pressing Tab after a native command is answered by the first of these that applies:

1. A hand-written completer: `dotnet`, `ffmpeg`, `npx`, `oh-my-posh`, `op`, `pwsh`, `sqlite3`, `ssh-keygen`, `winget`, `yt-dlp`, and `wsl` on Windows.
2. A cached [NativeCompletions](#nativecompletions) script.
3. carapace, if it's installed and knows the tool.
4. PowerShell's normal file path completion.

Completers load on the first Tab for that tool, so they add nothing to startup. A completer registered by a module, or by you, takes priority.

On PowerShell 7.6+, one catch-all handles every native command, including aliases (`k` aliased to `kubectl` completes as `kubectl`) and CLIs installed after the shell started. On 5.1 and 7.4/7.5 the profile registers each known tool by name at startup, so run `Update-Completions` after installing a new CLI there.

To add carapace: `winget install rsteube.Carapace`, `brew install carapace`, or your distro's package (or add it to `Packages`), then run `Update-Completions`.

## History, navigation and key bindings

| Key / command | What it does | Needs |
|---|---|---|
| `Ctrl+R` | Fuzzy-search history; the pick goes on the command line. | `PSFzf` + `fzf` |
| `Ctrl+T` | Fuzzy-pick a file or folder and insert it. | `PSFzf` + `fzf` |
| `Alt+C` | Fuzzy-pick a subfolder and `cd` to it. | `PSFzf` + `fzf` |
| `F7` | History list filtered by what's typed: `Out-GridView` on Windows, `fzf` elsewhere (`Tab` selects several). | `fzf` on macOS/Linux |
| `z <words>` / `zi` | Jump to a frequent folder matching the words / pick one interactively. | `zoxide` (`zi` also needs `fzf`) |
| Inline suggestions | History and tab-completion results as you type. | `CompletionPredictor`, PowerShell 7.2+ |

The sample config installs all of these. Anything missing leaves PSReadLine's default for that key. The fzf keys arrive a moment after the prompt appears. zoxide learns folders as you `cd`, so `z` gets useful after a few days of use.

**Atuin** records history into its own database and syncs it between machines. Turn it on with `settings.Atuin.Enabled: true` and install it (`winget install Atuinsh.Atuin`, `brew install atuin`). It doesn't take any keys: `Ctrl+R` stays with PSFzf and the arrows with `HistorySearchArrowKeys`. Use `atuin search -i` for its search UI.

### Other key bindings

| Key | What it does |
|---|---|
| `F1` | Help for the command under the cursor. |
| `RightArrow` | At the end of the line, accept the next word of the suggestion. |
| `Alt+a` | Select the next argument on the line (repeat to cycle). |
| `Alt+w` | Save the line to history without running it. |
| `Ctrl+Shift+v` | Paste the clipboard as a here-string. |
| `Alt+(` | Wrap the selection, or the whole line, in parentheses. |
| `Alt+'` | Toggle quotes on the argument under the cursor. |
| `Alt+%` | Expand aliases on the line to full command names. |
| `Ctrl+Shift+j`, then a key | Mark the current folder under that key. |
| `Ctrl+j`, then the key | Jump to the marked folder. |
| `Alt+j` | List folder marks. |
| Quotes and brackets | Typed and deleted in pairs. |
| `Alt+d`, `Alt+Backspace`, `Alt+b`, `Alt+f` | Shell-style word delete and move (`Alt+B`/`Alt+F` select). |
| `Ctrl+d, Ctrl+c` | Select lines of screen output and copy them. |
| `Ctrl+Shift+b` / `Ctrl+Shift+t` | Run `dotnet build` / `dotnet test`. |

`git cmt` is corrected to `git commit` when you press Enter. `Get-PSReadLineKeyHandler -Bound` lists every binding in a live shell.

## Secrets

Functions that need an API key read it when called, through `Get-PSProfileSecret`, never at startup and never from a config file. By default it reads [SecretManagement](https://learn.microsoft.com/powershell/utility-modules/secretmanagement/overview) under the same name. Store a key once:

```powershell
Set-Secret -Name OpenWeatherMapApiKey   # prompts for the value; the first use creates a SecretStore password
```

If no vault is registered (`Get-SecretVault` shows nothing), register one:

```powershell
Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

`settings.Secrets` can point a name elsewhere:

```json
"Secrets": {
    "OpenWeatherMapApiKey": "op://Personal/OpenWeatherMap/credential",
    "SomeOtherKey": { "Name": "other-name", "Vault": "Work" }
}
```

| Value | Read from |
|---|---|
| `"op://vault/item/field"` | 1Password, via `op read`. |
| `"SomeName"` | That secret in SecretManagement. |
| `{ "Name": ..., "Vault": ... }` | That secret in that vault. |

`Get-PSProfileSecret -Name <name>` returns the value as a string, or nothing if it can't be found (add `-Verbose` to see why). A parameter passed directly (`Get-Weather -APIKey ...`) always wins. A `*:APIKey` entry in `DefaultParameterValues` still works but prints a startup warning explaining how to move it.

## Command reference

Every function has `Get-Help <name> -Full` for parameters and examples. Functions load on first call; `Get-Help` and tab completion work before that. Example outputs below are illustrative; values vary.

### Built into the profile

| Name | Description |
|---|---|
| `Get-PSProfileConfig` | The merged config object. `-ListLayers` lists the files it came from. |
| `FileSizeBelow` / `FileSizeAbove` / `FileSizeBetween` | Pipeline filters: `Get-ChildItem -Recurse \| FileSizeAbove 100MB`. |
| `$PSProfileRoot` | Install folder. |
| `$OneDriveRoot` | Resolved OneDrive folder, or `OneDrive is not configured`. |
| `$MyDocs` | Documents folder. |
| `$IsElevated` | `$true` when running as Administrator or root. |

### Profile management (all OSes)

| Function | Description |
|---|---|
| `Update-Profile` | Update, check, or roll back PSProfile. See [Lifecycle](#lifecycle-update-roll-back-uninstall). |
| `Update-PowerShell` | Upgrade PowerShell 7 to the newest 7.6 LTS patch. |
| `Update-PSProfileCache` | Rebuild startup caches. |
| `Update-Completions` | Regenerate native and carapace completions. |
| `Get-PSProfileSecret` | Look up a named secret. |
| `Edit-Profile` | Open the profile in an editor. |
| `Open-HistoryFile` | Open the PSReadLine history file. |

### Diagnostics (all OSes)

| Function | Description |
|---|---|
| `Test-Port` | Is a TCP port reachable? Short timeout; several hosts and ports at once. |
| `Get-ProcessByPort` | Which process owns a local port, or connects to a remote one. |
| `Test-TlsCertificate` | A TLS endpoint's certificate: expiry, SANs, issuer, chain. |
| `ConvertFrom-Jwt` | Decode a JWT offline and show when it expires. Doesn't verify the signature. |
| `Get-PathReport` | PATH entries in order, flagging missing and duplicate folders. |
| `Invoke-Retry` | Run a script block with retries and exponential backoff. |
| `Get-LastBootTime` | When a computer last booted. |
| `Resolve-Error` | Expand an error record's full details. |

```text
PS> Test-Port -ComputerName github.com -Port 443, 8080

ComputerName Port  Open LatencyMs Error
------------ ----  ---- --------- -----
github.com    443  True      21.4
github.com   8080 False           Timed out after 1000 ms

PS> Get-PathReport | Where-Object { -not $_.Exists -or $_.Duplicate }

Order Path                     Expanded Exists Duplicate DuplicateOf Empty
----- ----                     -------- ------ --------- ----------- -----
    7 C:\Program Files\OldTool            False     False             False
   12 C:\Windows\system32                  True      True           2 False

PS> ConvertFrom-Jwt -Token $token

Algorithm     : HS256
Issuer        :
Subject       : 1234567890
Audience      :
IssuedAt      : 01/18/2018 01:30:22
NotBefore     :
Expires       : 03/17/2030 17:46:40
Expired       : False
TimeRemaining : 1237.21:40:12
Header        : @{alg=HS256; typ=JWT}
Payload       : @{sub=1234567890; name=John Doe; iat=1516239022; exp=1900000000}
Signed        : True

PS> Invoke-Retry -MaxAttempts 5 -DelaySeconds 2 -ScriptBlock { Invoke-RestMethod https://api.example.com/health }
```

`Test-TlsCertificate` returns `ComputerName`, `Port`, `ServerName`, `Subject`, `Issuer`, `NotBefore`, `NotAfter`, `DaysRemaining`, `Expiring`, `Valid`, `PolicyErrors`, `ChainStatus`, `Chain`, `SANs`, `Protocol`, `KeyAlgorithm`, `Thumbprint` and `SerialNumber`. `Get-ProcessByPort` returns `Protocol`, `LocalAddress`, `LocalPort`, `RemoteAddress`, `RemotePort`, `State`, `ProcessId`, `ProcessName` and `Path`.

### Networking and IP math (all OSes)

| Function | Description |
|---|---|
| `Get-IPv4Subnet` | Network, broadcast and host count for an IP with a CIDR or mask. |
| `Split-IPv4Subnet` | Split a subnet into smaller ones. |
| `Convert-Subnetmask` | Mask to CIDR and back. |
| `Convert-IPv4Address` | IPv4 address to Int64 and back. |
| `Invoke-IPv4NetworkScan` | Find live hosts in a range, with DNS names (and MAC vendors with `-EnableMACResolving`). |
| `Invoke-IPv4PortScan` | Scan a host's TCP ports. |
| `Get-MACVendor` | Vendor for a MAC address. |
| `Send-WakeOnLan` / `Send-MagicPacket` | Wake a computer by MAC address. |
| `Test-DHCPPxe` | Discover DHCP/PXE servers. |
| `Test-WebSiteStatus` | HTTP status of a URL. |
| `Resolve-ShortURL` | Follow a short URL to its target. |
| `Update-GoogleDNS` | Update a Google dynamic DNS record. |
| `Search-Google` | Open a Google search in the default browser. |

```text
PS> Get-IPv4Subnet -IPv4Address 192.168.10.42 -CIDR 26

NetworkID    Broadcast     IPs Hosts
---------    ---------     --- -----
192.168.10.0 192.168.10.63  64    62

PS> Split-IPv4Subnet -IPv4Address 10.0.0.0 -CIDR 24 -NewCIDR 26

NetworkID  Broadcast  IPs Hosts
---------  ---------  --- -----
10.0.0.0   10.0.0.63   64    62
10.0.0.64  10.0.0.127  64    62
10.0.0.128 10.0.0.191  64    62
10.0.0.192 10.0.0.255  64    62

PS> Convert-Subnetmask -CIDR 22

Mask          CIDR
----          ----
255.255.252.0   22
```

### Files, text and data (all OSes)

| Function | Description |
|---|---|
| `Find-StringInFile` / `Update-StringInFile` | Search or replace text across files. |
| `Test-IsFileBinary` | Is a file binary? |
| `Get-IniContent` | Read an INI file into a hashtable. |
| `ConvertTo-Base64` / `ConvertFrom-Base64` | Base64 encode a file; decode a string. |
| `Convert-ROT13` / `Convert-ROT47` | Caesar-cipher rotation. |
| `ConvertTo-StringList` | Join an array with a delimiter. |
| `Get-Time` | Convert a time to other formats. |
| `Get-ConsoleColor` | Show the console colors. |
| `Get-Weather` | Current weather by city, ZIP code, or your IP's location. Needs an OpenWeatherMap key ([Secrets](#secrets)). |
| `Get-QuoteOfTheDay` | A quote of the day. |

### Passwords and random values (all OSes)

| Function | Description |
|---|---|
| `Get-RandomPassword` | Random password of a given length. |
| `Get-RandomPIN` | Random numeric PIN. |
| `Get-RandomString` | Random alphanumeric string. |
| `New-Password` | Password without look-alike characters (`1`, `l`, `0`, `O`, `\|`). |

`-CopyToClipboard` on `Get-RandomPassword` and `Get-RandomPIN` uses `Set-Clipboard` on Windows, `pbcopy` on macOS, and `xclip`, `xsel` or `wl-copy` on Linux.

### Git shortcuts (all OSes)

| Function | Runs |
|---|---|
| `gs` | `git status` |
| `ga` | `git add .` |
| `gc <message>` | `git commit -m` (replaces the `gc` alias for `Get-Content`; `cat` still works) |
| `gcom <message>` | `git add .`, then commit |
| `lazyg <message>` | `git add .`, commit, push |
| `gpush` / `gpull` | `git push` / `git pull` |
| `gcl <url>` | `git clone` |

### Unix-style commands (all OSes)

| Function | Description |
|---|---|
| `cd` (`Set-LocationAndList`) | Change folder and list it. Replaces the built-in `cd` alias. |
| `Set-LocationCustom` | Change folder and list it, without replacing `cd`. |
| `head` / `tail` | First or last lines of a file; `tail -f` follows new lines. |
| `pgrep` / `pkill` | Find or kill processes by name. |
| `unzip` | Extract a zip into the current folder. |
| `sudo` | Elevate: the real `sudo` on macOS/Linux, a `RunAs` process on Windows. |

### Windows only

**System and hardware:** `Get-DeviceInfo`, `Get-OSInfo`, `Show-Sysinfo`, `Get-Uptime`, `Get-PendingReboot`, `Get-BatteryStatus`, `Get-DiskInfo`, `Get-DiskSize`, `Get-DriveInfo`, `Get-DriveSpace`, `Get-FolderSizes`, `Get-InstalledSoftware`, `Get-NetFramework`, `Get-WindowsProductKey`.

**Users and sessions:** `Get-UserSession`, `Get-LoggedOnUsers`, `Get-LastLogon`, `Get-LocalUser`, `Get-LocalGroup`, `Get-LocalGroupMember`, `Get-LocalAdministratorBuiltin`, `Test-IsAdmin`.

**Networking and remoting:** `Get-ARPCache`, `Clear-ARPCache`, `Get-MACAddress`, `Get-Netstat`, `Get-WLANProfile`, `Invoke-DNSCacheFlush`, `Enable-PSRemotingRemote`, `Get-TrustedHost`, `Add-TrustedHost`, `Set-TrustedHost`, `Remove-TrustedHost`, `Enable-RemoteDesktop`, `Disable-RemoteDesktop`.

**Active Directory:** `Get-ADCertificateInformation`, `Get-ADComputersNoDesc`, `Get-InactiveADComputers`.

**Security and credentials:** `Get-BitLockerRecoveryKeyId`, `Get-CodeSignCert`, `Get-CredentialFromWindowsCredentialManager`, `New-RandomPassword`.

**Files:** `Edit-File` (opens a file in the best available editor; aliased as `edit`), `Get-FileMetaData`, `Get-ImageInformation`, `Get-EncodedFile`, `New-ISOFile`, `New-ZipFile`, `New-Shortcut`, `Get-PublicDesktopShortcuts`.

**Desktop and system changes:** `Lock-Computer`, `Lock-Workstation`, `New-Explorer` (restart Explorer), `Set-ScreenResolution`, `Set-Console`, `Set-PathVariable`, `Set-RegValue`, `Start-Elevated`, `Start-PSElevated`, `Send-VoiceMessage` (text to speech), `Write-Log` (CMTrace format), `Invoke-IvantiInventoryScan`, `ConvertTo-NatoAlphabet`.

## Troubleshooting

**See where startup time goes.** Start a shell with `PSPROFILE_TRACE` set:

```powershell
$env:PSPROFILE_TRACE = 1; pwsh
```

A table of per-section timings prints when the profile finishes loading. The rows stay in `$Global:PSProfileTrace`; look again a second later to see deferred work (Phase `Deferred`). Example, trimmed:

```text
Phase    Section             Ms
-----    -------             --
Load     Config            12.4
Load     Public functions   8.1
Load     Private functions 21.7
Load     Modules            9.3
Load     PSReadLine        61.0
Load     oh-my-posh        14.2
Load     Total (load)     168.9
Deferred Import PSFzf      48.5
Deferred Preload functions 39.8
```

**Environment variables:**

| Variable | Effect |
|---|---|
| `PSPROFILE_TRACE` | Print the timing table. |
| `PSPROFILE_NO_UPDATE_CHECK` | Skip the update notice and background check for that shell. |

**Common fixes:**

- **A setting has no effect.** Run `Get-PSProfileConfig -ListLayers` to see which files load; a later layer may override yours. A file with a JSON error is skipped with a warning at startup.
- **"PSProfile: missing module(s) ..." at startup.** Run `Update-Profile`.
- **A function behaves like an old version.** The function index rebuilds itself when files change. If it doesn't, run `Update-PSProfileCache`, or set `LazyLoadFunctions` to `false`.
- **`brew` isn't found in pwsh on macOS/Linux.** The profile adds Homebrew's standard locations (`/opt/homebrew`, `/usr/local`, `/home/linuxbrew/.linuxbrew`, `~/.linuxbrew`) to PATH. Add other locations yourself.
- **No tab completion for a newly installed CLI on 5.1 or 7.4.** Run `Update-Completions`.
- **An update broke something.** Run `Update-Profile -Rollback`.

## Requirements

- Windows PowerShell 5.1, or PowerShell 7 on Windows, macOS or Linux. Tested on 5.1, 7.4 and 7.6.
- PowerShell 7.2+ for inline predictions from `CompletionPredictor`; 7.6+ for the catch-all completer.
- `git` is recommended. Without it, setup and updates use zip downloads.
- Optional tools, installed from your config by setup and `Update-Profile`: oh-my-posh, fzf, zoxide, carapace, Atuin, and a splash command.

### Security

- **Execution policy:** left at PowerShell's default (`RemoteSigned` for pwsh 7 on Windows). Setup changes it only when it's `Restricted`, and never touches `AllSigned` or Group Policy.
- **History:** `FilterSecretsFromHistory` (on in the sample) keeps likely secrets out of the history file.
- **Credentials:** never stored in config. See [Secrets](#secrets).
- **TLS:** the profile enables TLS 1.2 for web requests on Windows PowerShell 5.1.

## Contributing

### Repository layout

```text
profile2.0.ps1               The profile.
setup.ps1                    Installer and uninstaller.
assets/
  config/                    Config layers and psprofile.schema.json.
  lib/
    PSProfile.Lifecycle.ps1  Install, update, rollback and dependency logic (not loaded at startup).
    PSProfile.Completion.ps1 Completion routing (loaded on first Tab).
  public/
    shared/                  User-facing functions for every OS, one per file.
    windows/                 Windows-only functions.
  private/
    shared/                  Profile internals: helpers, completions.ps1, history.ps1 (key bindings).
      completions/           Hand-written completers.
    windows/completions/     Windows-only completers.
    <os>/completions/native/ Generated completion caches (gitignored).
tests/                       Pester suites, Invoke-Tests.ps1, Measure-Startup.ps1.
.github/workflows/tests.yml  CI.
```

### Adding a function

1. Add `<FunctionName>.ps1` to `assets/public/shared/`, or to `assets/public/windows/` if it needs Windows. Create `macos/` or `linux/` only for a function that needs that OS. A same-named file in an OS folder overrides the shared one on that OS.
2. One function per file, named after the file, with comment-based help that includes `.SYNOPSIS`. Put the help inside the function or directly above it, with no other comment line directly above the help block.
3. No other top-level code apart from alias lines. Prefer `[Alias()]`. If the name clashes with a built-in alias, remove that alias first: `Remove-Item -Path alias:\<name> -Force -ErrorAction Ignore`.
4. It must parse on Windows PowerShell 5.1: no ternary `? :`, `??`, `?.`, `&&`/`||` pipeline chains, or `ForEach-Object -Parallel`. Test the OS with `$IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'`. Save as ASCII or UTF-8 with BOM.
5. If it can be tested without network or admin rights, add a case to `tests/Functions.Tests.ps1`.

Nothing needs registering: the function index picks up the new file on the next shell start.

### Tests

```powershell
Install-Module Pester -MinimumVersion 6.0 -Scope CurrentUser -SkipPublisherCheck
./tests/Invoke-Tests.ps1                                    # every suite
./tests/Invoke-Tests.ps1 -Path ./tests/Functions.Tests.ps1  # one suite
./tests/Measure-Startup.ps1 -Key windows-7.6                # startup budget check
```

CI runs the suites on Windows PowerShell 5.1 and PowerShell 7.4 and 7.6 across Windows, macOS and Ubuntu, plus PSScriptAnalyzer. A job also fails when profile load overhead grows more than 25% and more than 50 ms over its entry in `tests/startup-baseline.json`. Update the baseline when a change makes startup slower on purpose.

## Credits

Most functions are original. These come from other authors, credited in each file's header:

- **[BornToBeRoot/PowerShell](https://github.com/BornToBeRoot/PowerShell)** (GPL-3.0): `Add-TrustedHost`, `Clear-ARPCache`, `Convert-IPv4Address`, `Convert-ROT13`, `Convert-ROT47`, `Convert-Subnetmask`, `Find-StringInFile`, `Get-ARPCache`, `Get-ConsoleColor`, `Get-InstalledSoftware`, `Get-IPv4Subnet`, `Get-MACAddress`, `Get-MACVendor`, `Get-RandomPassword`, `Get-RandomPIN`, `Get-TrustedHost`, `Get-WindowsProductKey`, `Get-WLANProfile`, `Invoke-IPv4NetworkScan`, `Invoke-IPv4PortScan`, `Remove-TrustedHost`, `Send-WakeOnLan`, `Set-TrustedHost`, `Split-IPv4Subnet`, `Test-IsFileBinary`, `Update-StringInFile`.
- **Microsoft's [PSReadLine sample profile](https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1):** most key handlers in `history.ps1`.
- **[lipkau/PsIni](https://github.com/lipkau/PsIni):** `Get-IniContent`.
- **Chris Dent ([indented.co.uk](http://www.indented.co.uk/2010/02/17/dhcp-discovery/)):** `Test-DHCPPxe`.
- **Chris Wu:** `New-ISOFile`.
- **Stephane van Gulick ([powershellDistrict.com](http://www.powershellDistrict.com)):** `Get-BitLockerRecoveryKeyId`.
- **Brian Wilhite:** `Get-PendingReboot`, `Get-LastLogon`.
- **Boe Prox:** `Test-IsAdmin`.
- **saw-friendship** (PowerShell Gallery): `Send-MagicPacket`.
- **mjolinor** ([blog post](https://mjolinor.wordpress.com/2014/01/31/random-password-generator/)): `New-Password`.
- **[screenFetch](https://github.com/KittyKatt/screenFetch)** and **[archey](https://github.com/djmelik/archey)**: inspiration for `Show-Sysinfo`.
- A **[Stack Overflow answer](http://stackoverflow.com/questions/7162604/get-cached-credentials-in-powershell-from-windows-7-credential-manager)**: `Get-CredentialFromWindowsCredentialManager`.

## License

Public domain ([Unlicense](https://unlicense.org)), except the 26 files adapted from BornToBeRoot/PowerShell listed above, which stay under **GPL-3.0** and say so in their headers. See [LICENSE](LICENSE) for both texts and the exact file list.
