# PSProfile

A single, config-driven PowerShell profile that works the same way on Windows, macOS, and Linux — one `profile2.0.ps1`, one JSON config, and a library of 120+ helper functions organized by which OS they actually support.

## Install

```powershell
irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex
```

This is the only supported install path. It works on Windows PowerShell 5.1, PowerShell 7+ on Windows, and PowerShell 7+ on macOS/Linux. Read `setup.ps1` before running it — it's short and does exactly what's described below, nothing more.

### What it does

1. Installs (or updates) this repo to `~/.config/powershell/PSProfile` — via `git clone`/`git pull` if git is available, otherwise a zip download from GitHub. A zip download is validated in a staging folder next to the install and swapped in whole, so files removed upstream don't linger. Safe to re-run any time to update.
2. Creates a personal `assets/config/config.json` from `assets/config/sample-config.json`, but only if one doesn't already exist. Re-running never touches a config you've already customized.
3. Points `$PROFILE.CurrentUserAllHosts` at the installed `profile2.0.ps1`. If you already have a profile, it's backed up (`<profile>.bak-<timestamp>`) and its original content is preserved, appended below the new dot-source line — nothing is discarded.
4. Installs the [Modules](#modules) and [Packages](#packages) your config lists that are missing (`-SkipDependencies` to skip). `apt`/`dnf`/`yum`/`pacman` go through `sudo` when you're not root, so expect a password prompt on Linux.
5. Loads the profile once in a separate PowerShell process to check it loads cleanly and to build its caches (including cached [`NativeCompletions`](#nativecompletions)).

The profile itself never installs anything at startup. If a configured module or package is missing, it prints one line saying so and pointing at `Update-Profile`.

### Custom install path or branch

```powershell
&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -InstallPath 'C:\PSProfile' -Branch 'develop'
```

Add `-SkipProfileLink` to just get the repo on disk without touching `$PROFILE` — useful if you'd rather dot-source `profile2.0.ps1` yourself from an existing profile. Add `-SkipDependencies` to skip installing modules and packages.

### Manual install

```powershell
git clone https://github.com/reave/PSProfile.git ~/.config/powershell/PSProfile
cp ~/.config/powershell/PSProfile/assets/config/sample-config.json ~/.config/powershell/PSProfile/assets/config/config.json
# then add this line to $PROFILE.CurrentUserAllHosts:
. "$HOME/.config/powershell/PSProfile/profile2.0.ps1"
```

### Updating

Run `Update-Profile`. It works for both git and zip installs:

- **git install:** `git pull --ff-only` in the install directory.
- **zip install:** downloads the latest commit, validates it in a staging folder, and swaps it in. The previous tree is kept as `.PSProfile.previous` next to the install.

Before an update is accepted, every `.ps1` must parse and `profile2.0.ps1` must load without throwing in a separate, profile-less PowerShell process. A git update that fails either check is reset to the previous commit automatically (`git reset --keep`, so local edits are never discarded); a zip update that fails is never swapped in. That same child process then rebuilds the profile's caches with the new code (`Update-PSProfileCache` and [`Update-Completions`](#nativecompletions)). Finally, any configured modules and packages that are missing get installed (`-SkipDependencies` to skip).

The new version loads in new shells; run `. $PROFILE` to load it into the current one. Your `config.json` is never touched — it's gitignored, and zip updates carry it (and cached native completions) across.

| Command | What it does |
|---|---|
| `Update-Profile` | Update, validate, rebuild caches, install missing dependencies. |
| `Update-Profile -CheckOnly` | Just report whether an update is available and what's missing. |
| `Update-Profile -Rollback` | Go back to the version before the last update. The update notice then stays quiet until something newer than the version you rolled away from is published. |
| `Update-Profile -SkipValidation` | Skip the child-process load test (the parse check still runs). |

**Update notice.** Once a day (`UpdateCheckIntervalHours`, `0` turns it off), the profile starts a check in a background runspace: `git fetch` for a git install, one GitHub API call for a zip install. It never blocks the prompt; the result shows as one yellow line on the next shell start, e.g. `PSProfile: 3 new commit(s) available; missing package(s) speedtest. Run Update-Profile.` State lives outside the install directory, in `$env:LOCALAPPDATA\PSProfile` on Windows and `$XDG_CACHE_HOME/PSProfile` (or `~/.cache/PSProfile`) elsewhere.

### Uninstalling

```powershell
&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -Uninstall
```

Restores `$PROFILE.CurrentUserAllHosts` to its pre-PSProfile content (or deletes it, if setup.ps1 created it), backs up `config.json` next to `$PROFILE`, then deletes the install directory and the state/cache folder. Asks first; add `-Force` to skip the prompt. Installed modules and packages are left alone.

## Configuration

Everything behavioral is controlled by `assets/config/config.json`, which you get by copying `assets/config/sample-config.json` (setup.ps1 does this for you automatically on first install). `sample-config.json` stays checked into git as the template/example; `config.json` is yours, gitignored, and never touched by updates.

If `config.json` is missing for any reason, the profile falls back to `sample-config.json` with a warning — it never fails to load outright.

### `settings`

| Key | Type | Description |
|---|---|---|
| `MaximumHistoryCount` | number | PowerShell session command history size. Default `8192`. |
| `OneDrivePath` | string | Explicit OneDrive path, used if it exists. Otherwise auto-detected (`$env:USERPROFILE\OneDrive` on Windows, `$HOME/OneDrive` elsewhere), falling back to "OneDrive is not configured". |
| `PoshTheme` | string | An oh-my-posh theme name or a full path to a `.omp.json` file. See [Theming](#theming). |
| `ShowWindowTitle` | bool | Set the console window title to `PowerShell <version> [ADMIN]`/`[ROOT]` when elevated. Cross-platform. |
| `ShowSplashScreen` | bool | Run a system-info splash command on load (see `SplashCommand` below). Only runs if the configured command is actually installed. |
| `SplashCommand` | object | Per-OS splash command: `Windows`, `MacOS`, `Linux` keys, e.g. `"winfetch"` or `"screenfetch -E"`. |
| `ShowElevatedWarning` | bool | Print a red banner when running elevated (Administrator on Windows, root on macOS/Linux). |
| `RunUpdateHelpOnElevated` | bool | When elevated, kick off `Update-Help` as a background job. |
| `ShowPSVersionBanner` | bool | Print the PowerShell version and execution policy on load. |
| `UpdateCheckIntervalHours` | number | How often the background update check runs. Default `24`; `0` turns the check and the update notice off. See [Updating](#updating). |
| `EnableChocolateyIntegration` | — | **Removed.** Windows package management is winget-only; see [Packages](#packages). |
| `DefaultParameterValues` | object | Merged directly into `$PSDefaultParameterValues` — arbitrary `"Cmdlet:Parameter": value` entries, e.g. an API key for a function's parameter (see [Secrets in config](#secrets-in-config)). |
| `PSReadLine` | object | See below. |
| `LazyLoadFunctions` | bool | Default `true`. Load each public function's file the first time it's called instead of dot-sourcing them all on every start — see [Lazy-loaded functions](#lazy-loaded-functions). Set `false` to load everything up front. |

All of the above except `PoshTheme`'s theming behavior and the `Modules`/`Packages`/`Aliases` arrays are optional — anything unset just doesn't run.

#### `PSReadLine`

| Key | Type | Description |
|---|---|---|
| `PredictionSource` | string | e.g. `"History"`. |
| `PredictionViewStyle` | string | e.g. `"ListView"`. |
| `EditMode` | string | `"Windows"` or `"Emacs"`. |
| `HistorySearchArrowKeys` | bool | Up/Down arrow search history by the text already typed. |
| `FilterSecretsFromHistory` | bool | Excludes any line matching `(?i)(password\|secret\|token\|apikey\|connectionstring)` from PSReadLine's on-disk history file. Doesn't stop the command from running — just keeps it out of plaintext history. |
| `Colors` | object | Arbitrary PSReadLine color table (`Command`, `String`, `Keyword`, etc. — any key `Set-PSReadLineOption -Colors` accepts). |

All of `PSReadLine` is wrapped in a single try/catch: `PredictionSource`/`PredictionViewStyle` throw on hosts without virtual-terminal support (some remote sessions, redirected output), and the whole block is skipped in non-interactive sessions in the first place (see [Interactive-only behavior](#interactive-only-behavior)).

### `Aliases`

```json
{ "Name": "edit", "Value": "Edit-File", "Description": "Edit a file" }
```

Applied via `New-Alias -Force`. Keep in mind PowerShell resolves existing aliases before functions of the same name — if you're aliasing over something with a built-in alias, remove it first (see [Adding functions](#adding-functions) for the pattern this repo uses).

### `Modules`

```json
{
    "Name": "Terminal-Icons",
    "Description": "...",
    "PSVersionMajor": "5",
    "OS": "All"
}
```

Each entry is imported at startup if it's installed. Missing ones are reported in one startup line and installed by `setup.ps1` or `Update-Profile` (`Install-Module -Scope CurrentUser`), never during shell start. `OS` is `"Windows"`, `"MacOS"`, `"Linux"`, `"All"`, or a comma-separated combination (e.g. `"Windows,MacOS"`). `PSVersionMajor` is a **minimum** PowerShell major version — the entry is skipped if `$PSVersionTable.PSVersion.Major` is lower. `PSVersionMajorMax` is the inverse — a **maximum** PowerShell major version, for a module that stops working on newer PowerShell (e.g. `TabExpansionPlusPlus`, which only supports Windows PowerShell 5.1 and doesn't install cleanly on PS7+/Core). The two can be combined to bound a module to a specific range.

`DeferImport` (optional bool) imports the module just after the prompt appears instead of before it (see [Deferred startup work](#deferred-startup-work)). Modules that only matter once you're typing — `Terminal-Icons` and `Microsoft.WinGet.CommandNotFound` — are deferred by default; set `"DeferImport": false` on an entry to import it before the prompt, or `true` to defer another module. Don't defer a module your prompt or the first command you type depends on.

### `Packages`

```json
{ "Name": "speedtest", "Id": "ookla.speedtest.cli", "Source": "winget" }
```

Supports `winget`, `brew`, `apt`, `yum` (or `dnf`), and `pacman`. Unlike `Modules`, there's no `OS` field — each entry only acts if its package manager's command is actually present on the machine, so one config's `Packages` array can safely list an entry per manager and only the applicable ones fire. `Name` is the command used to check whether the package is already installed (`Get-Command`); `Id` is the identifier passed to the package manager.

Packages are installed by `setup.ps1` and `Update-Profile` only; the profile doesn't probe for them at startup. The daily background check detects missing ones and the next shell start mentions them. `apt`/`dnf`/`yum`/`pacman` run through `sudo` when you're not root (you'll get a password prompt, which is fine there since you started the install yourself). `winget` entries use the `winget` CLI directly.

### `NativeCompletions`

```json
{ "Name": "docker", "GenerateCommand": "docker completion powershell" }
```

For tools that generate their own PowerShell completion script (Cobra-based CLIs mostly — `docker`, `kubectl`, `helm`, `gh` with its `-s powershell` flag, and others that support `<tool> completion powershell`). `Name` is checked with `Get-Command` the same way as everywhere else in this config; `GenerateCommand` is the exact command that prints the completion script to stdout.

This is deliberately **not** run on every profile load — shelling out to each configured tool every time you open a shell would be slow, and painfully so for anything backed by a daemon (`docker` in particular, if Docker Desktop isn't running). Instead, [`Update-Completions`](#update-completions) runs each `GenerateCommand` once and caches the output under `assets/private/<os>/completions/native/<Name>.ps1` (gitignored — machine/version-specific, never committed); `completions.ps1` registers whichever of those cache files exist, and loads one only the first time you press Tab after that tool. Run `Update-Completions` after installing a new tool, or let [`Update-Profile`](#update-profile) do it for you (see below) — a `NativeCompletions` entry for a tool with no cache yet is silently skipped, not an error, so it's safe to list tools you don't have installed everywhere.

### Secrets in config

Some functions take API keys as parameters (e.g. `Get-Weather -APIKey`). Rather than hardcoding a key in the function file, set it in `DefaultParameterValues`:

```json
"DefaultParameterValues": {
    "Get-Weather:APIKey": "your-key-here"
}
```

`sample-config.json` ships these blank. Since `config.json` is gitignored, your key never ends up in git history.

## Theming

`PoshTheme` accepts either a bare theme name (resolved under `$env:POSH_THEMES_PATH`) or a full path to a `.omp.json` file. `$env:POSH_THEMES_PATH` is set automatically by oh-my-posh's winget/scoop packages on Windows, but **not** by its Homebrew package on macOS/Linux — if you installed via Homebrew and want a specific theme, either set `$env:POSH_THEMES_PATH` yourself or put a full path directly in `PoshTheme`. If the theme can't be resolved, the profile falls back to oh-my-posh's built-in default theme with a warning instead of erroring.

If you installed oh-my-posh via Homebrew and *also* can't run `brew` itself from PowerShell, that's a separate, more common issue — see [Homebrew on macOS/Linux](#homebrew-on-macoslinux).

## Homebrew on macOS/Linux

Homebrew's installer adds its `PATH` setup to `.zprofile`/`.bash_profile`, which `pwsh` never sources. If you launch PowerShell directly (not from a zsh/bash login shell that already ran that setup), `brew` — and anything installed through it — is invisible to the whole session. This profile detects the standard Homebrew install locations (`/opt/homebrew`, `/usr/local` on macOS; `/home/linuxbrew/.linuxbrew`, `~/.linuxbrew` on Linux) and fixes `$env:PATH` automatically on load, so `brew` works at the prompt afterward too, not just internally for the `Packages` config.

## Lazy-loaded functions

Dot-sourcing a script file has a fixed cost (6–9 ms on Windows, mostly antivirus scanning) no matter how small the file, so dot-sourcing all ~120 function files took about a second on every shell start. Instead, the profile loads one generated **function index** that defines a lightweight placeholder for each public function. A placeholder carries the real function's help and parameters — `Get-Help`, syntax and tab completion all work before anything is loaded — and the first time it's called it loads the real file and hands the call over, arguments and pipeline input included. In an interactive shell, the real files are also loaded a few at a time while the prompt is idle (see [Deferred startup work](#deferred-startup-work)), so within a few seconds every function is the real one.

- The index is built by parsing the function files (nothing in them runs) and covers `assets/public/<os>` plus `assets/public/shared` if that folder exists; when both define a function, the OS folder's wins.
- `[Alias()]` attributes on a function, and top-level `Remove-Item alias:\…`/`New-Alias`/`Set-Alias` lines in a function file, are applied at load just like before, so aliases work before the function's first call.
- A file with any other top-level code is dot-sourced at load as before.
- The index records a fingerprint of every function file (name, size, modification time). If a file is added, removed or changed — a `git pull`, an edit, an update that replaced the install directory — the next shell rebuilds it automatically. If it can't be used for any reason, the profile falls back to dot-sourcing every file, so functions always load.
- Set `settings.LazyLoadFunctions` to `false` in `config.json` to always dot-source everything up front.

### Caches

Generated files live outside the install directory, so an update that replaces it can't leave a mismatched cache behind: `%LOCALAPPDATA%\PSProfile\cache` on Windows, `$XDG_CACHE_HOME/PSProfile` (default `~/.cache/PSProfile`) on macOS/Linux. File names include a key derived from the install path, so two installs on one machine don't collide. Every cache is checked on load and rebuilt when out of date; `Update-PSProfileCache` rebuilds them all on demand, e.g. right after an update so the next shell doesn't have to. Deleting the cache files is always safe.

## Deferred startup work

Some startup work only matters once you're at the prompt, so the profile queues it and runs it right after the prompt appears: one step each time PSReadLine reports it's idle waiting for input (the `PowerShell.OnIdle` event), so the prompt shows up first. Anything you type while a step runs is buffered, not lost. Errors and warnings from a deferred step are printed above the prompt.

Nothing is deferred when there won't be a prompt to wait for — no PSReadLine, a non-interactive host, or `pwsh -Command`/`-File` without `-NoExit` — then the queued steps run at the end of the profile instead, so scripts and one-off commands behave exactly as before.

## Load time

To see where profile load time goes, start a shell with `PSPROFILE_TRACE` set:

```powershell
$env:PSPROFILE_TRACE = 1; pwsh
```

The profile prints a per-section timing table when it finishes loading, and keeps the rows in `$Global:PSProfileTrace`. Work the profile defers until the first idle prompt is added there too (Phase `Deferred`) a moment after the prompt appears, so look at `$Global:PSProfileTrace` again after a second or two to see it.

## Security

- **Execution policy**: `powershell.config.json` sets `RemoteSigned`, not `Unrestricted` — your own local scripts run freely, but anything downloaded from the internet (carrying a Mark-of-the-Web zone identifier) must be signed to auto-execute. Windows-only; a no-op on macOS/Linux.
- **Secret-free history**: `PSReadLine.FilterSecretsFromHistory` (on by default in `sample-config.json`) keeps lines that look like they contain a password/token/API key out of the plaintext PSReadLine history file.
- **No hardcoded credentials**: any function needing an API key takes it as a parameter defaulting to empty, sourced from your gitignored `config.json` via `DefaultParameterValues` — never committed to the repo.

## Repository structure

```
profile2.0.ps1              The profile. Loads config, dot-sources functions, applies settings.
setup.ps1                   The installer and uninstaller (see Install above).
powershell.config.json      PowerShell engine config (execution policy, experimental features).
PSScriptAnalyzerSettings.psd1  Lint rules CI enforces (Error severity only).
tests/                      Pester suites, run by .github/workflows/tests.yml on every push/PR.
assets/
  lib/
    PSProfile.Lifecycle.ps1 Install/update/rollback/dependency logic. Not loaded at startup; used by
                             setup.ps1, Update-Profile, and the background update check.
  config/
    sample-config.json      Checked-in template/example. Copy to config.json to customize.
    config.json              Your personal config. Gitignored, created by setup.ps1.
  public/
    windows/ macos/ linux/  User-callable functions, one per file, split by OS support.
  private/
    windows/ macos/ linux/  Functions the profile uses internally to configure itself.
      completions/          Hand-written tool completers, dot-sourced if the tool is installed.
        native/             Cached output of installed tools' own completion generators.
                             Gitignored, regenerated by Update-Completions.
```

### Why functions are split by OS

Every function under `assets/public/` and `assets/private/` was individually reviewed for what it actually depends on — WMI/CIM, the Windows registry, Active Directory, WinRM `TrustedHosts`, Windows-only cmdlets (`Get-LocalUser`, `Set-ScreenResolution`, `Test-NetConnection`), P/Invoke, or Windows-formatted parsing of `arp`/`netstat`/`nbtstat` output — rather than assumed from its name. Functions that only depend on those live in `windows/` only; everything genuinely cross-platform (IP/subnet math, string conversions, git shortcuts, Unix-alias utilities like `unzip`/`pkill`/`tail`, web-request-based tools) is duplicated into `macos/` and `linux/` too. `profile2.0.ps1` only dot-sources the folder matching the OS it's actually running on.

`private/` functions (`Test-InteractiveShell`, `Enable-Tls12`, `Initialize-HomebrewPath`, `Resolve-PoshTheme`, `Set-ProfileWindowTitle`, plus `completions.ps1`/`history.ps1` for tab-completion and PSReadLine key bindings) exist to help the profile configure itself — they're not really meant to be called directly, though nothing stops you.

`completions.ps1` is a small dispatcher, not the completers themselves: each hand-written tool completer lives in its own file under `private/<os>/completions/` (`winget.ps1`, `dotnet.ps1`, `op.ps1`, `oh-my-posh.ps1`, `wsl.ps1` (Windows-only), `ssh-keygen.ps1`, `sqlite3.ps1`, `pwsh.ps1`, `npx.ps1`, `yt-dlp.ps1`, `ffmpeg.ps1`) and `completions.ps1` doesn't load any of them up front. It registers a tiny native completer for each file's tool (harmless for tools that aren't installed — it only runs when that tool is being completed), and the first Tab after the tool's name loads that tool's completer file and answers with it; from then on the real completer is used directly. Loading every completer on each start cost ~400 ms (`op.ps1` alone is ~200 ms), and even checking which tools were installed cost a `Get-Command` per tool. To add a hand-written completer, drop a `<tool>.ps1` file under `completions/` that calls `Register-ArgumentCompleter` for that tool — the file name is the tool name, and nothing else needs registering.

Two flavors of hand-written completer, by option-surface size: small/stable CLIs (`ssh-keygen`, `sqlite3`, `pwsh`, `npx`, `wsl`) get a static, curated flag/subcommand list, same style as `winget.ps1`. `yt-dlp` (270+ flags) and `ffmpeg` (190+, `-h long`) are too large and change too often to hand-transcribe reliably, so those two instead parse the tool's own `--help`/`-h` output at completion time — always matches whatever version is actually installed — and cache the result in a session-global variable so repeated Tab presses don't re-run `--help`. `ssh-keygen` specifically is never invoked by its own completer (only documented flags, hand-transcribed) since running it with no/wrong arguments can drop into an interactive key-generation prompt rather than printing help.

`private/<os>/completions/native/` holds a second kind of completer: for tools that generate their own PowerShell completion script (see [`NativeCompletions`](#nativecompletions)), `Update-Completions` writes the generated output there instead of anyone hand-writing it. Gitignored — regenerated per machine, never committed. `completions.ps1` lazy-loads whichever of those cache files exist, the same way as the hand-written ones.

### Interactive-only behavior

`Test-InteractiveShell` (host is `ConsoleHost` and neither stdin nor stdout is redirected) gates PSReadLine configuration (including loading `history.ps1`'s key handlers, which would otherwise import PSReadLine just to configure it) and the entire Windows/macOS/Linux settings section — window title, splash screen, elevated banner, PS-version banner, oh-my-posh init. None of that runs when the profile is dot-sourced by a script, a CI runner, or an editor's integrated PowerShell extension host; only actual interactive terminal sessions get the full experience.

## What's included

Run `Get-Help <FunctionName> -Full` on anything below for parameters, examples, and notes — comment-based help is included throughout.

### Git shortcuts (cross-platform)

`gs` (status) · `ga` (add .) · `gc <msg>` (commit) · `gpush` · `gpull` · `gcl <repo>` (clone) · `gcom <msg>` (add + commit) · `lazyg <msg>` (add + commit + push)

`gc`, and a few others, deliberately remove a same-named built-in PowerShell alias before defining themselves — see [Adding functions](#adding-functions).

### Unix-alias utilities (cross-platform)

`unzip` · `pkill` · `pgrep` · `head` · `tail -f` · `Set-LocationAndList` (aliased over `cd` — `cd` becomes "change directory and list") · `Set-LocationCustom` (same idea, called directly, no alias override) · `sudo` (elevation shim; calls the real external binary on macOS/Linux, `Start-Process -Verb RunAs` on Windows)

### Networking / IP math (cross-platform)

`Convert-IPv4Address` · `Convert-Subnetmask` · `Get-IPv4Subnet` · `Split-IPv4Subnet` · `Invoke-IPv4NetworkScan` · `Invoke-IPv4PortScan` · `Get-MACVendor` · `Send-WakeOnLan` · `Send-MagicPacket` · `Test-DHCPPxe` · `Test-WebSiteStatus` · `Resolve-ShortURL` · `Update-GoogleDNS`

### Diagnostics (cross-platform)

`Test-Port` (fast TCP reachability check with a timeout) · `Get-ProcessByPort` (which process owns a local TCP/UDP port) · `Test-TlsCertificate` (remote cert expiry, SANs, issuer, chain status) · `ConvertFrom-Jwt` (decode a JWT offline and show its expiry; does not verify the signature) · `Get-PathReport` (PATH entries in order, flagging missing and duplicate dirs) · `Invoke-Retry` (run a script block with retries and exponential backoff) · `Get-LastBootTime`

### Networking (Windows-only — WMI/registry/Windows-formatted CLI output)

`Get-ARPCache` · `Clear-ARPCache` · `Get-MACAddress` · `Get-Netstat` · `Get-WLANProfile` · `Invoke-DNSCacheFlush` · `Enable-PSRemotingRemote` · `Add-TrustedHost`/`Get-TrustedHost`/`Set-TrustedHost`/`Remove-TrustedHost` · `Enable-RemoteDesktop`/`Disable-RemoteDesktop`

### System info (Windows-only)

`Get-DeviceInfo` · `Get-OSInfo` · `Get-Uptime` · `Get-PendingReboot` · `Get-DiskInfo`/`Get-DiskSize`/`Get-DriveInfo`/`Get-DriveSpace` · `Get-FolderSizes` · `Get-BatteryStatus` · `Get-InstalledSoftware` · `Get-NetFramework` · `Get-WindowsProductKey` · `Show-Sysinfo` · `Get-UserSession`/`Get-LoggedOnUsers`/`Get-LastLogon`

### Active Directory (Windows-only)

`Get-ADCertificateInformation` · `Get-ADComputersNoDesc` · `Get-InactiveADComputers` · `Get-LocalAdministratorBuiltin`/`Get-LocalGroup`/`Get-LocalGroupMember`/`Get-LocalUser`

### Security / credentials (Windows-only)

`Get-BitLockerRecoveryKeyId` · `Get-CodeSignCert` · `Get-CredentialFromWindowsCredentialManager` · `Test-IsAdmin`

### Random generation (cross-platform)

`Get-RandomPIN` · `Get-RandomPassword` · `Get-RandomString` · `New-Password` — `-CopyToClipboard` on the PIN/password generators uses `Set-Clipboard` on Windows, `pbcopy` on macOS, and `xclip`/`xsel`/`wl-copy` (whichever is present) on Linux.

`New-RandomPassword` (Windows-only — depends on the .NET Framework `System.Web` assembly, not available on PS7+/.NET Core).

### File / data utilities (cross-platform)

`Find-StringInFile` · `Update-StringInFile` · `Test-IsFileBinary` · `Get-IniContent` · `ConvertTo-Base64`/`ConvertFrom-Base64` · `Convert-ROT13`/`Convert-ROT47` · `ConvertTo-StringList` · `Get-ConsoleColor` · `Get-Time` · `Get-QuoteOfTheDay` · `Get-Weather` · `Resolve-Error` · `Update-Profile` (updates a git or zip install with validation and rollback — see [Updating](#updating)) · `Update-Completions` (regenerates cached [`NativeCompletions`](#nativecompletions) for whichever configured tools are installed) · `Update-PSProfileCache` (rebuilds the profile's [startup caches](#caches))

### File utilities (Windows-only)

`Get-FileMetaData` (Shell.Application COM) · `Get-EncodedFile` · `New-ISOFile` · `New-Shortcut` · `New-ZipFile` · `Get-ImageInformation` · `Get-PublicDesktopShortcuts`

### Misc (Windows-only)

`Lock-Computer`/`Lock-Workstation` · `New-Explorer` · `Set-ScreenResolution` · `Set-Console` (WMI-based window title/full-name banner — superseded by the cross-platform `Set-ProfileWindowTitle` for the profile's own `ShowWindowTitle` setting, but still directly callable) · `Set-PathVariable` · `Set-RegValue` · `Send-VoiceMessage` · `Write-Log` · `Start-Elevated`/`Start-PSElevated` · `Invoke-IvantiInventoryScan` · `Update-PowerShell` (checks the latest PowerShell GitHub release, upgrades via winget) · `Edit-File`/`Edit-Profile`/`Open-HistoryFile` (open the right editor for the current host — VS Code, ISE, or OS-appropriate text editor) · `ConvertTo-NatoAlphabet`

## Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+ (Windows/macOS/Linux). Some modules/packages in `sample-config.json` are gated to PS5.1-only or require a minimum version — see `PSVersionMajor` in [Modules](#modules).
- `git` is recommended (for `setup.ps1`'s clone/pull path and easy updates) but not required — the installer falls back to a zip download.
- Everything else (oh-my-posh, Terminal-Icons, winget/brew/apt/yum/pacman packages) is optional and installed from your `config.json` by `setup.ps1`/`Update-Profile`, on whichever platforms actually support it. PSReadLine is optional too; older versions that don't support `-PredictionSource`/`-Colors` degrade gracefully (the whole `PSReadLine` config block is wrapped in a try/catch) rather than erroring.

## Adding functions

1. Drop a `.ps1` file with one function per file into `assets/public/<os>/` (user-callable) or `assets/private/<os>/` (profile-internal). Use the OS folder(s) it actually depends on — see [Why functions are split by OS](#why-functions-are-split-by-os).
2. Write comment-based help (`.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.EXAMPLE`/`.OUTPUTS`) directly above the `function` keyword, with **no other comment line directly above it** (a `#---` banner immediately above a help block breaks PowerShell's association between the two — always leave a blank line between them).
3. If the function name might collide with a built-in alias (e.g. `gc`/`Get-Content`, `cd`/`Set-Location`), remove the alias first: `Remove-Item -Path "alias:\<name>" -Force -ErrorAction Ignore`. PowerShell resolves aliases *before* functions of the same name, so without this the function would silently never run. Use `-ErrorAction Ignore` rather than `SilentlyContinue` for checks like this that are expected to fail - `SilentlyContinue` still records every failure in `$Error`, so a fresh shell would start with a pile of meaningless errors in it.
4. If it's cross-platform, copy the identical file into all three `windows`/`macos`/`linux` folders — `profile2.0.ps1` only loads the one matching the running OS, so there's no runtime cost to the duplication.
5. Run `./tests/Invoke-Tests.ps1` (needs Pester 5.5+: `Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser`). CI runs the same suites on Windows, macOS, and Ubuntu, so a function that parses or loads on one OS but not another fails the PR. The suites check that every file parses, that each public file defines a function named after the file and has a `.SYNOPSIS`, that copies of a cross-platform file stay identical across OS folders, and that the profile loads with no errors and exposes every public function. Pure functions (IP math, encoders, generators) also get behavior tests in `tests/Functions.Tests.ps1`; add a case there when a new function can be tested without network or admin rights.
6. Nothing to register: the [function index](#lazy-loaded-functions) notices the new file and rebuilds itself on the next shell start. Keep files to function definitions (plus alias lines, if needed) so the function can be lazy-loaded — any other top-level code makes the file load eagerly on every start.

## Credits

This repository's structure, documentation, and a substantial share of its features (the config-driven architecture, `NativeCompletions`, `Update-Profile`/`Update-Completions`, cross-OS parity fixes, load-time optimization work, and this Credits/License pass itself) were developed with AI assistance (Claude, via Claude Code) working alongside the repo's human maintainer.

Most of this profile's functions are original or built from common, unattributable patterns, but a number were pulled in from other PowerShell authors and projects, credited here per their own file headers (or, for `history.ps1`, by content match against a known public source — see below). A few files carry `Author: Unknown` in their own `.NOTES` — their origin predates this repo and couldn't be traced further, so they aren't listed individually here.

- **[BornToBeRoot/PowerShell](https://github.com/BornToBeRoot/PowerShell)** (GPL-3.0 — see [License](#license)) — the bulk of the networking/utility toolkit: `Add-TrustedHost`, `Clear-ARPCache`, `Convert-IPv4Address`, `Convert-ROT13`, `Convert-ROT47`, `Convert-Subnetmask`, `Find-StringInFile`, `Get-ARPCache`, `Get-ConsoleColor`, `Get-InstalledSoftware`, `Get-IPv4Subnet`, `Get-MACAddress`, `Get-MACVendor`, `Get-RandomPassword`, `Get-RandomPIN`, `Get-TrustedHost`, `Get-WindowsProductKey`, `Get-WLANProfile`, `Invoke-IPv4NetworkScan`, `Invoke-IPv4PortScan`, `Remove-TrustedHost`, `Send-WakeOnLan`, `Set-TrustedHost`, `Split-IPv4Subnet`, `Test-IsFileBinary`, `Update-StringInFile`.
- **Microsoft's official [PSReadLine sample profile](https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1)** — most of `assets/private/<os>/history.ps1`'s key handlers (smart quote/brace insertion, F7 history search via `Out-GridView`, directory marks, `git cmt` → `commit` autocorrect, and more), confirmed by matching `-BriefDescription` names and key bindings against the upstream file.
- **[lipkau/PsIni](https://github.com/lipkau/PsIni)** — `Get-IniContent`.
- **Chris Dent, [indented.co.uk](http://www.indented.co.uk/2010/02/17/dhcp-discovery/)** — `Test-DHCPPxe`.
- **Chris Wu** — `New-ISOFile` (`New-IsoFile`), later modified.
- **Stephane van Gulick, [powershellDistrict.com](http://www.powershellDistrict.com)** — `Get-BitLockerRecoveryKeyId`.
- **Brian (C.) Wilhite** — `Get-PendingReboot`, `Get-LastLogon`.
- **Boe Prox** — `Test-IsAdmin`.
- **saw-friendship** (published as a PowerShell Gallery script) — `Send-MagicPacket`.
- **mjolinor**, [blog post](https://mjolinor.wordpress.com/2014/01/31/random-password-generator/) — `New-Password`.
- **[screenFetch](https://github.com/KittyKatt/screenFetch) by KittyKatt** and **[archey](https://github.com/djmelik/archey) by djmelik** — named as inspiration for `Show-Sysinfo` (its own header lists the original Windows-port author as unknown).
- A **[Stack Overflow answer](http://stackoverflow.com/questions/7162604/get-cached-credentials-in-powershell-from-windows-7-credential-manager)** — `Get-CredentialFromWindowsCredentialManager` is adapted from it.

Separately, [`NativeCompletions`](#nativecompletions) entries (`docker`, `kubectl`, `gh`, `helm` by default) and the hand-written `winget.ps1`/`dotnet.ps1`/`oh-my-posh.ps1` completers under `completions/` are generated by, or built to parse the output of, each tool's own official completion generator — not third-party community code, so not credited as external authorship above.

## License

Public domain ([Unlicense](https://unlicense.org)) — use, copy, modify, and redistribute any part of this repository for any purpose, with or without attribution.

**Exception:** the 26 files adapted from [BornToBeRoot/PowerShell](https://github.com/BornToBeRoot/PowerShell) (listed in [Credits](#credits) above) remain licensed under that project's own license, **GPL-3.0** — each carries a `License: GPL-3.0` line in its own header. See [LICENSE](LICENSE) for the full text of both and the exact file list.
