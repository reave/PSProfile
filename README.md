# PSProfile

A single, config-driven PowerShell profile that works the same way on Windows, macOS, and Linux — one `profile2.0.ps1`, one JSON config, and a library of 120+ helper functions organized by which OS they actually support.

## Install

```powershell
irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1 | iex
```

This is the only supported install path. It works on Windows PowerShell 5.1, PowerShell 7+ on Windows, and PowerShell 7+ on macOS/Linux. Read `setup.ps1` before running it — it's short and does exactly what's described below, nothing more.

### What it does

1. Installs (or updates) this repo to `~/.config/powershell/PSProfile` — via `git clone`/`git pull` if git is available, otherwise a zip download from GitHub. Safe to re-run any time to update.
2. Creates a personal `assets/config/config.json` from `assets/config/sample-config.json`, but only if one doesn't already exist. Re-running never touches a config you've already customized.
3. Points `$PROFILE.CurrentUserAllHosts` at the installed `profile2.0.ps1`. If you already have a profile, it's backed up (`<profile>.bak-<timestamp>`) and its original content is preserved, appended below the new dot-source line — nothing is discarded.

It does **not** install oh-my-posh, Terminal-Icons, or any packages itself. `profile2.0.ps1` handles that on its own the first time it loads, based on your config (see [Modules](#modules) and [Packages](#packages) below).

### Custom install path or branch

```powershell
&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/reave/PSProfile/main/setup.ps1))) -InstallPath 'C:\PSProfile' -Branch 'develop'
```

Add `-SkipProfileLink` to just get the repo on disk without touching `$PROFILE` — useful if you'd rather dot-source `profile2.0.ps1` yourself from an existing profile.

### Manual install

```powershell
git clone https://github.com/reave/PSProfile.git ~/.config/powershell/PSProfile
cp ~/.config/powershell/PSProfile/assets/config/sample-config.json ~/.config/powershell/PSProfile/assets/config/config.json
# then add this line to $PROFILE.CurrentUserAllHosts:
. "$HOME/.config/powershell/PSProfile/profile2.0.ps1"
```

### Updating

From an already-loaded profile, run `Update-Profile` — it `git pull`s the install directory and reloads `$PROFILE` in place, no restart needed. Otherwise, re-run the install one-liner at the top of this file, or if you cloned manually, `git pull` inside the install directory. Either way, your `config.json` is untouched — it isn't part of the repo (it's gitignored), so nothing can overwrite it.

`Update-Profile` only works for a git-based install (the default); a zip-installed copy (no git available at install time) needs the install one-liner re-run instead.

`Update-Profile` also refreshes cached [`NativeCompletions`](#nativecompletions) (`Update-Completions`) after reloading — pass `-SkipCompletions` to skip that. Run `Update-Completions` on its own any time, e.g. right after installing a new CLI, to pick it up without a full profile update.

### Uninstalling

Remove the dot-source line (and the `# Managed by PSProfile` comment block above it) from `$PROFILE.CurrentUserAllHosts`, then delete the install directory.

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
| `EnableChocolateyIntegration` | — | **Removed.** Windows package management is winget-only; see [Packages](#packages). |
| `DefaultParameterValues` | object | Merged directly into `$PSDefaultParameterValues` — arbitrary `"Cmdlet:Parameter": value` entries, e.g. an API key for a function's parameter (see [Secrets in config](#secrets-in-config)). |
| `PSReadLine` | object | See below. |

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

Each entry is installed (`Install-Module -Force`) and imported if not already present. `OS` is `"Windows"`, `"MacOS"`, `"Linux"`, `"All"`, or a comma-separated combination (e.g. `"Windows,MacOS"`). `PSVersionMajor` is a **minimum** PowerShell major version — the entry is skipped if `$PSVersionTable.PSVersion.Major` is lower. `PSVersionMajorMax` is the inverse — a **maximum** PowerShell major version, for a module that stops working on newer PowerShell (e.g. `TabExpansionPlusPlus`, which only supports Windows PowerShell 5.1 and doesn't install cleanly on PS7+/Core). The two can be combined to bound a module to a specific range.

### `Packages`

```json
{ "Name": "speedtest", "Id": "ookla.speedtest.cli", "Source": "winget" }
```

Supports `winget`, `brew`, `apt`, `yum` (or `dnf`), and `pacman`. Unlike `Modules`, there's no `OS` field — each entry only acts if its package manager's command is actually present on the machine, so one config's `Packages` array can safely list an entry per manager and only the applicable ones fire. `Name` is the command used to check whether the package is already installed (`Get-Command`); `Id` is the identifier passed to the package manager.

`apt`/`yum`/`pacman` require root. If not elevated, the entry is skipped with a warning instead of invoking `sudo` interactively — a password prompt there would hang profile load.

The `winget` case imports `Microsoft.WinGet.Client` itself, lazily, right before calling `Install-WinGetPackage` — not eagerly in [Modules](#modules) — because once every configured package is already installed (the common case after first setup) this branch never runs, so there's no reason to pay that module's import cost on every session.

### `NativeCompletions`

```json
{ "Name": "docker", "GenerateCommand": "docker completion powershell" }
```

For tools that generate their own PowerShell completion script (Cobra-based CLIs mostly — `docker`, `kubectl`, `helm`, `gh` with its `-s powershell` flag, and others that support `<tool> completion powershell`). `Name` is checked with `Get-Command` the same way as everywhere else in this config; `GenerateCommand` is the exact command that prints the completion script to stdout.

This is deliberately **not** run on every profile load — shelling out to each configured tool every time you open a shell would be slow, and painfully so for anything backed by a daemon (`docker` in particular, if Docker Desktop isn't running). Instead, [`Update-Completions`](#update-completions) runs each `GenerateCommand` once and caches the output under `assets/private/<os>/completions/native/<Name>.ps1` (gitignored — machine/version-specific, never committed); `completions.ps1` just dot-sources whichever of those cache files already exist on every load, which is cheap. Run `Update-Completions` after installing a new tool, or let [`Update-Profile`](#update-profile) do it for you (see below) — a `NativeCompletions` entry for a tool with no cache yet is silently skipped, not an error, so it's safe to list tools you don't have installed everywhere.

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

## Security

- **Execution policy**: `powershell.config.json` sets `RemoteSigned`, not `Unrestricted` — your own local scripts run freely, but anything downloaded from the internet (carrying a Mark-of-the-Web zone identifier) must be signed to auto-execute. Windows-only; a no-op on macOS/Linux.
- **Secret-free history**: `PSReadLine.FilterSecretsFromHistory` (on by default in `sample-config.json`) keeps lines that look like they contain a password/token/API key out of the plaintext PSReadLine history file.
- **No hardcoded credentials**: any function needing an API key takes it as a parameter defaulting to empty, sourced from your gitignored `config.json` via `DefaultParameterValues` — never committed to the repo.

## Repository structure

```
profile2.0.ps1              The profile. Loads config, dot-sources functions, applies settings.
setup.ps1                   The installer (see Install above).
powershell.config.json      PowerShell engine config (execution policy, experimental features).
assets/
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

`completions.ps1` is a small dispatcher, not the completers themselves: each hand-written tool completer lives in its own file under `private/<os>/completions/` (`winget.ps1`, `dotnet.ps1`, `op.ps1`, `oh-my-posh.ps1`, `wsl.ps1` (Windows-only), `ssh-keygen.ps1`, `sqlite3.ps1`, `pwsh.ps1`, `npx.ps1`, `yt-dlp.ps1`, `ffmpeg.ps1`) and `completions.ps1` only dot-sources one if `Get-Command` finds that tool installed. Dot-sourcing forces a full parse of whatever file it points at regardless of any `if` inside that file, so gating had to happen at file-selection level — one file per tool, not one giant always-loaded file with conditionals in it. Add a new hand-written tool completer the same way: a new file under `completions/`, plus one `if (Get-Command ...) { . ... }` line in `completions.ps1`.

Two flavors of hand-written completer, by option-surface size: small/stable CLIs (`ssh-keygen`, `sqlite3`, `pwsh`, `npx`, `wsl`) get a static, curated flag/subcommand list, same style as `winget.ps1`. `yt-dlp` (270+ flags) and `ffmpeg` (190+, `-h long`) are too large and change too often to hand-transcribe reliably, so those two instead parse the tool's own `--help`/`-h` output at completion time — always matches whatever version is actually installed — and cache the result in a session-global variable so repeated Tab presses don't re-run `--help`. `ssh-keygen` specifically is never invoked by its own completer (only documented flags, hand-transcribed) since running it with no/wrong arguments can drop into an interactive key-generation prompt rather than printing help.

`private/<os>/completions/native/` holds a second kind of completer: for tools that generate their own PowerShell completion script (see [`NativeCompletions`](#nativecompletions)), `Update-Completions` writes the generated output there instead of anyone hand-writing it. Gitignored — regenerated per machine, never committed. `completions.ps1`'s dispatcher dot-sources whichever of those cache files happen to exist, same `Get-Command`-gated pattern as the hand-written ones.

### Interactive-only behavior

`Test-InteractiveShell` (host is `ConsoleHost` and neither stdin nor stdout is redirected) gates PSReadLine configuration and the entire Windows/macOS/Linux settings section — window title, splash screen, elevated banner, PS-version banner, oh-my-posh init. None of that runs when the profile is dot-sourced by a script, a CI runner, or an editor's integrated PowerShell extension host; only actual interactive terminal sessions get the full experience.

## What's included

Run `Get-Help <FunctionName> -Full` on anything below for parameters, examples, and notes — comment-based help is included throughout.

### Git shortcuts (cross-platform)

`gs` (status) · `ga` (add .) · `gc <msg>` (commit) · `gpush` · `gpull` · `gcl <repo>` (clone) · `gcom <msg>` (add + commit) · `lazyg <msg>` (add + commit + push)

`gc`, and a few others, deliberately remove a same-named built-in PowerShell alias before defining themselves — see [Adding functions](#adding-functions).

### Unix-alias utilities (cross-platform)

`unzip` · `pkill` · `pgrep` · `head` · `tail -f` · `Set-LocationAndList` (aliased over `cd` — `cd` becomes "change directory and list") · `Set-LocationCustom` (same idea, called directly, no alias override) · `sudo` (elevation shim; calls the real external binary on macOS/Linux, `Start-Process -Verb RunAs` on Windows)

### Networking / IP math (cross-platform)

`Convert-IPv4Address` · `Convert-Subnetmask` · `Get-IPv4Subnet` · `Split-IPv4Subnet` · `Invoke-IPv4NetworkScan` · `Invoke-IPv4PortScan` · `Get-MACVendor` · `Send-WakeOnLan` · `Send-MagicPacket` · `Test-DHCPPxe` · `Test-WebSiteStatus` · `Resolve-ShortURL` · `Update-GoogleDNS`

### Networking (Windows-only — WMI/registry/Windows-formatted CLI output)

`Get-ARPCache` · `Clear-ARPCache` · `Get-MACAddress` · `Get-Netstat` · `Get-WLANProfile` · `Invoke-DNSCacheFlush` · `Enable-PSRemotingRemote` · `Add-TrustedHost`/`Get-TrustedHost`/`Set-TrustedHost`/`Remove-TrustedHost` · `Enable-RemoteDesktop`/`Disable-RemoteDesktop`

### System info (Windows-only)

`Get-DeviceInfo` · `Get-OSInfo` · `Get-Uptime` · `Get-LastBootTime` · `Get-PendingReboot` · `Get-DiskInfo`/`Get-DiskSize`/`Get-DriveInfo`/`Get-DriveSpace` · `Get-FolderSizes` · `Get-BatteryStatus` · `Get-InstalledSoftware` · `Get-NetFramework` · `Get-WindowsProductKey` · `Show-Sysinfo` · `Get-UserSession`/`Get-LoggedOnUsers`/`Get-LastLogon`

### Active Directory (Windows-only)

`Get-ADCertificateInformation` · `Get-ADComputersNoDesc` · `Get-InactiveADComputers` · `Get-LocalAdministrator`/`Get-LocalGroup`/`Get-LocalGroupMember`/`Get-LocalUser`

### Security / credentials (Windows-only)

`Get-BitLockerRecoveryKeyId` · `Get-CodeSignCert` · `Get-CredentialFromWindowsCredentialManager` · `Test-IsAdmin`

### Random generation (cross-platform)

`Get-RandomPIN` · `Get-RandomPassword` · `Get-RandomString` · `New-Password` — `-CopyToClipboard` on the PIN/password generators uses `Set-Clipboard` on Windows, `pbcopy` on macOS, and `xclip`/`xsel`/`wl-copy` (whichever is present) on Linux.

`New-RandomPassword` (Windows-only — depends on the .NET Framework `System.Web` assembly, not available on PS7+/.NET Core).

### File / data utilities (cross-platform)

`Find-StringInFile` · `Update-StringInFile` · `Test-IsFileBinary` · `Get-IniContent` · `ConvertTo-Base64`/`ConvertFrom-Base64` · `Convert-ROT13`/`Convert-ROT47` · `ConvertTo-StringList` · `Get-ConsoleColor` · `Get-Time` · `Get-QuoteOfTheDay` · `Get-Weather` · `Resolve-Error` · `Update-Profile` (`git pull`s the install directory and reloads `$PROFILE` — see [Updating](#updating)) · `Update-Completions` (regenerates cached [`NativeCompletions`](#nativecompletions) for whichever configured tools are installed)

### File utilities (Windows-only)

`Get-FileMetaData` (Shell.Application COM) · `Get-EncodedFile` · `New-ISOFile` · `New-Shortcut` · `New-ZipFile` · `Get-ImageInformation` · `Get-PublicDesktopShortcuts`

### Misc (Windows-only)

`Lock-Computer`/`Lock-Workstation` · `New-Explorer` · `Set-ScreenResolution` · `Set-Console` (WMI-based window title/full-name banner — superseded by the cross-platform `Set-ProfileWindowTitle` for the profile's own `ShowWindowTitle` setting, but still directly callable) · `Set-PathVariable` · `Set-RegValue` · `Send-VoiceMessage` · `Write-Log` · `Start-Elevated`/`Start-PSElevated` · `Invoke-IvantiInventoryScan` · `Update-PowerShell` (checks the latest PowerShell GitHub release, upgrades via winget) · `Edit-File`/`Edit-Profile`/`Open-HistoryFile` (open the right editor for the current host — VS Code, ISE, or OS-appropriate text editor) · `ConvertTo-NatoAlphabet`

## Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+ (Windows/macOS/Linux). Some modules/packages in `sample-config.json` are gated to PS5.1-only or require a minimum version — see `PSVersionMajor` in [Modules](#modules).
- `git` is recommended (for `setup.ps1`'s clone/pull path and easy updates) but not required — the installer falls back to a zip download.
- Everything else (oh-my-posh, Terminal-Icons, winget/brew/apt/yum/pacman packages) is optional and self-installs from your `config.json` on first load, on whichever platforms actually support it. PSReadLine is optional too; older versions that don't support `-PredictionSource`/`-Colors` degrade gracefully (the whole `PSReadLine` config block is wrapped in a try/catch) rather than erroring.

## Adding functions

1. Drop a `.ps1` file with one function per file into `assets/public/<os>/` (user-callable) or `assets/private/<os>/` (profile-internal). Use the OS folder(s) it actually depends on — see [Why functions are split by OS](#why-functions-are-split-by-os).
2. Write comment-based help (`.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.EXAMPLE`/`.OUTPUTS`) directly above the `function` keyword, with **no other comment line directly above it** (a `#---` banner immediately above a help block breaks PowerShell's association between the two — always leave a blank line between them).
3. If the function name might collide with a built-in alias (e.g. `gc`/`Get-Content`, `cd`/`Set-Location`), remove the alias first: `Remove-Item -Path "alias:\<name>" -Force -ErrorAction SilentlyContinue`. PowerShell resolves aliases *before* functions of the same name, so without this the function would silently never run.
4. If it's cross-platform, copy the identical file into all three `windows`/`macos`/`linux` folders — `profile2.0.ps1` only loads the one matching the running OS, so there's no runtime cost to the duplication.

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
