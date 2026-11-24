# PSProfile style and practices

This is the coding standard for PSProfile. It adopts the community [PowerShell Practice and Style
guide](https://github.com/PoshCode/PowerShellPracticeAndStyle) (by Don Jones, Matt Penny, Carlos
Perez, Joel Bennett and the PowerShell community) as its baseline, and settles the points that guide
leaves open or gets wrong for a profile that runs on Windows PowerShell 5.1 and PowerShell 7 on
Windows, macOS and Linux.

For documentation (the README, this file, any other Markdown, and comment-based help), it also
adopts Microsoft's [PowerShell-Docs style
guide](https://learn.microsoft.com/powershell/scripting/community/contributing/powershell-style-guide)
and its [Markdown best
practices](https://learn.microsoft.com/powershell/scripting/community/contributing/general-markdown).
See [Documentation](#documentation).

Where this file and either guide disagree, this file wins. Where this file is silent, follow the
guides. Rules marked **(lint)** are enforced by
[`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1); see [Linting](#linting).

## Scope

- These rules apply to new code and to code you change. Don't reformat a whole file as part of a
  content change. If you want to bring a file up to standard, do it in a separate commit that
  changes only whitespace and layout, so the real changes stay easy to review.
- Files adapted from upstream projects (the GPL-3.0, LGPL-3.0 and MIT files listed in
  [LICENSE](LICENSE)) keep their license and author headers intact. Make the smallest change that
  fixes the problem, and match the surrounding style of that file rather than restyling it.
- A function copied into `windows/`, `macos/` and `linux/` must stay byte-identical across all three
  copies. Edit one, then copy it over the other two.

## Target runtimes

Which PowerShell a file must run on depends on where it lives:

| Location | Runs on | Write for |
| --- | --- | --- |
| `profile.ps1`, `setup.ps1` | Windows PowerShell 5.1, PowerShell 7 on all three OSes | 5.1 syntax and APIs |
| `assets/*/windows/` | Windows PowerShell 5.1 and PowerShell 7 on Windows | 5.1 syntax and APIs |
| `assets/*/macos/`, `assets/*/linux/` | PowerShell 7 only | PowerShell 7.6 (current LTS) |

A cross-platform function lives in all three folders, so it is held to the strictest row: **5.1
syntax, no Windows-only APIs**.

5.1 syntax means no ternary `? :`, no `??` or `??=`, no `&&` or `||` pipeline chains, no `-Parallel`
on `ForEach-Object`, no `Join-Path -AdditionalChildPath`, no `-ErrorMessage` on validation
attributes, and no `$IsWindows`/`$IsMacOS`/`$IsLinux` unguarded (see [Platform
detection](#platform-detection)). **(lint, via `PSUseCompatibleSyntax` and
`PSUseCompatibleCommands`)**

The guide's VER-01 says to write for the lowest version you can. For PowerShell 7 the lowest version
worth writing for is the oldest one Microsoft still supports. As of November 2026 that is 7.6 LTS;
7.4 LTS and 7.5 reached end of support on November 10, 2026 ([support
lifecycle](https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle)).

## Layout and formatting

**Indentation.** Four spaces, no tabs. Continuation lines may be indented further to line up with
what they continue. **(lint)**

**Braces.** One True Brace Style, as in the guide: the opening brace ends the line, the closing
brace starts a line, and `else`, `elseif`, `catch` and `finally` go on the same line as the closing
brace before them (`} else {`). Short scriptblocks passed as arguments may stay on one line, such as
`Where-Object { $_.Length -gt 10MB }`. **(lint)**

This style has a practical advantage beyond taste. Pasting code that puts `else` or `catch` on its
own line into a console ends the `if` or `try` statement early, so the paste fails
([#24](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/24),
[#81](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/81)). It also matches the guide
and the `CodeFormattingOTBS` preset that ships with PSScriptAnalyzer.

**Line length.** Aim for 120 characters or less. This is a warning, not a hard rule. The guide says
115; this project uses 120 because it's PSScriptAnalyzer's default for `PSAvoidLongLines`, it's what
the guide's own maintainer wraps at
([#145](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/145)), and the five-character
difference buys nothing on a modern terminal or on GitHub. **(lint)**

**Line continuation.** Use splatting and PowerShell's natural line breaks (after `|`, `,`, an
opening `(`, `[` or `{`, or an operator) instead of backticks. A backtick with a trailing space
after it silently ends the statement. **(lint, via `PSMisleadingBacktick`)**

**Pipelines.** When a pipeline doesn't fit on one line, break after each `|` and indent the
following lines one level
([#184](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/184)). **(lint)**

```powershell
$largeFiles = Get-ChildItem -Path $Path -File -Recurse |
    Where-Object { $_.Length -gt 100MB } |
    Sort-Object -Property Length -Descending
```

**Whitespace.**

- One space around operators and after commas. No spaces just inside `( )` or `[ ]`, including `if (
  $x )` ([#109](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/109)). One space just
  inside `{ }` and `$( )`. **(lint)**
- Unary operators and the colon form of switch parameters take no spaces: `$i++`, `-not $x`,
  `(Get-Date).AddDays(-1)`, `-Recurse:$Recurse`.
- No trailing whitespace. **(lint)**
- End each file with a newline.

**Semicolons.** Don't end lines with `;`. **(lint)** Don't put several statements on one line either
([#159](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/159)). The one tolerated case
is a short guard clause such as `if (-not $cmd) { Write-Warning 'Skipping.'; continue }`.

**Hashtables.** One key per line once a hashtable spans more than one line, no semicolons. Quote a
key if it starts with a digit or contains anything other than letters, digits and underscores, such
as `'Font-Size'` ([#146](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/146)).

**Strings.** Use single quotes for strings with nothing to expand, double quotes only when you're
expanding something. The guide makes no rule here and the performance difference is nil
([#63](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/63)), so this is for
readability: a single-quoted string tells the reader nothing in it is live. Not linted, because it
would flag most of the existing code.

## Capitalization

PascalCase for everything public: function names (both halves of `Verb-Noun`), parameters, global
and script-scope variables, and full .NET type names (`[System.IO.Path]`). Use camelCase for local
variables inside a function so they read differently from parameters
([#61](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/61)).

Lowercase for language keywords (`foreach`, `if`, `param`, `begin`, `process`, `end`, `try`,
`catch`, `throw`, `return`) and operators (`-eq`, `-match`, `-not`). **(lint, via
`PSUseCorrectCasing`)**

Type accelerators are lowercase (`[string]`, `[int]`, `[switch]`, `[pscustomobject]`,
`[hashtable]`), and attributes are PascalCase (`[Parameter()]`, `[CmdletBinding()]`,
`[ValidateSet()]`), following the pattern PowerShell's own accelerators use
([#54](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/54);
[#154](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/154) was never answered).

Comment-based help keywords are UPPERCASE (`.SYNOPSIS`, `.EXAMPLE`).

Acronyms follow the .NET rule the guide uses: a two-letter acronym stays uppercase (`$PSVersion`,
`Get-PSDrive`), longer ones are PascalCase (`Get-HtmlContent`). Existing names that break this, such
as `Get-MACVendor` or `Invoke-DNSCacheFlush`, stay as they are, because renaming a function breaks
everyone who calls it.

## Naming

- Functions are `Verb-Noun` with an approved verb (`Get-Verb`) and a singular noun. **(lint)**
  Functions that only the profile uses get a `PSProfile` noun prefix, like `Get-PSProfileConfig`, so
  they can't collide with something a user installs.
- **Exception:** the interactive shortcut functions (`gs`, `ga`, `gc`, `head`, `tail`, `pkill`, and
  similar) are deliberately short and some shadow built-in aliases. That's what they're for. Never
  call them from other code; call the real command instead.
- Use standard parameter names that match built-in cmdlets: `-Path`, `-LiteralPath`,
  `-ComputerName`, `-Credential`, `-Force`, `-PassThru`.
- In code, use full command names and full parameter names, never aliases (`Get-ChildItem -Path`,
  not `gci` or `ls`) ([#108](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/108)). On
  Linux and macOS this is more than style: `ls`, `cat`, `sort` and others are native programs there,
  not aliases, so the alias form runs something else entirely. **(lint)**
- Use `$_`, not `$PSItem`
  ([#143](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/143)). It's what almost all
  existing code uses.
- File name matches function name, case included: `Get-Thing.ps1` defines `Get-Thing`. Linux file
  systems are case-sensitive, so a dot-source or `Join-Path` that gets the case wrong works on
  Windows and macOS and fails on Linux.

## Functions

**Start every function as an advanced function.**

```powershell
function Get-Example {
    <#
    .SYNOPSIS
        One line saying what it does.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The item to look up.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Name
    )

    process {
        [pscustomobject]@{
            Name = $Name
        }
    }
}
```

- `[CmdletBinding()]` on every function, so `-Verbose`, `-ErrorAction` and `-?` work. The exceptions
  are the interactive shortcut functions and the PSReadLine and completion scriptblocks, which
  aren't commands. The `filter` keyword isn't used; write a function with a `process` block.
- `[OutputType()]` on every function that returns objects.
- Write `param(` with no space before the parenthesis. The guide writes `param ()`, but `param(` is
  what this repository already uses by a wide margin, and the guide's own rule is to follow a
  project's predominant style
  ([#128](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/128)).
- Name every block you use. Code that accepts pipeline input goes in `process`. Don't mix named
  blocks with loose code.
- Write `[Parameter(Mandatory)]`, not `Mandatory = $true`. The longer form only mattered for
  PowerShell 2.0 ([#52](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/52)).
- Give a `DefaultParameterSetName` whenever you use parameter sets.
- Functions that change state (files, registry, settings, services, remote machines) use
  `[CmdletBinding(SupportsShouldProcess)]` and wrap the change in `$PSCmdlet.ShouldProcess()`.
  **(lint)**

**Parameters.**

- Type every parameter. Be careful with `[string]` and `[object]` on parameters that take pipeline
  input or select a parameter set, since anything converts to them.
- Don't give optional parameters a default just to have one
  ([#67](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/67)). Never give a mandatory
  parameter a default. **(lint)** If a default has to be computed, compute it in the body and
  document the behavior. Don't put a complex expression in the `param` block
  ([#190](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/190)).
- Switches default to off and are never three-state
  ([#69](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/69)). **(lint)** Pass one on
  with `-Other:$MySwitch`.
- Validate with attributes instead of code in the body. Prefer `ValidateSet` (it gives tab
  completion). Avoid `ValidatePattern` in shared code: its error message shows the user a raw regex
  ([#18](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/18)). Use `ValidateScript`
  that throws a readable message instead. `-ErrorMessage` on validation attributes is PowerShell 6+
  only, so it's only allowed in `macos/` and `linux/` files.
- Accept `ValueFromPipelineByPropertyName` generously, and add `[Alias()]`es that match property
  names callers are likely to pipe in.
- Take credentials as `[pscredential]$Credential`, never as a username and plain-text password pair,
  and never call `Get-Credential` inside a function. **(lint)**

**Output.**

- Emit objects by leaving them on their own line. Use `return` only to leave a function early
  ([#46](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/46)). Don't use
  `Write-Output` in new code; it's slower and adds nothing. One exception: `Write-Output
  -NoEnumerate` to emit a collection as a single object.
- Output one kind of object per command, and output raw values (bytes, not "1.2 GB"). Formatting
  belongs in a `Show-` or `Format-` function, or in the console at the point of use.
- Return `[pscustomobject]@{ ... }`, with `PSTypeName` set if you want to recognize the type later.
  Don't define PowerShell classes in profile files. A dot-sourced class can't be redefined in the
  same session, so editing it means restarting the shell. Classes also have scoping problems
  ([#97](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/97),
  [#185](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/185)).
- Use `[pscustomobject]@{}`, `[TypeName]::new()` and `@{}` instead of `New-Object`. In particular,
  `New-Object Hashtable` gives a case-sensitive hashtable
  ([#60](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/60)).

**Streams.** `Write-Verbose` for what a user might want to trace, `Write-Debug` for what a
maintainer needs, `Write-Warning` for problems that don't stop the work, and `Write-Progress` for
long loops. `Write-Host` is allowed for the profile's own startup banners, for `Show-` functions,
and for interactive prompts. Elsewhere it's flagged. **(lint)** The guide's warning that
`Write-Host` output can't be captured predates PowerShell 5. Since 5.0 it writes to the Information
stream (`6>`), but it's still the wrong place for data.

## Help and comments

- Every public function has comment-based help with at least `.SYNOPSIS`, one `.EXAMPLE` per main
  use, and a description of every parameter. **(lint, via `PSProvideCommentHelp`)**
- Put the help block **inside** the function, as its first lines, as the guide recommends. Help
  written above the `function` keyword only attaches if it ends at most one blank line before it,
  and a stray comment such as a `#---` banner nearby detaches it without any error. Help inside the
  function can't come loose that way. Existing functions with help above them are fine as they are;
  move it only when you're already rewriting the function.
- Document each parameter with a comment directly above it in the `param` block. `Get-Help` picks
  these up ([#161](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/161)), and they're
  harder to forget when the parameter changes. Existing `.PARAMETER` entries are also fine; just
  don't mix both styles in one function.
- Indent help keywords one level inside the function and their text one level further
  ([#147](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/147)). Editors fold on
  indentation, so this lets the whole help block collapse.
- `.EXAMPLE` shows the command first, then a blank line, then what it does. Use full command and
  parameter names and no positional arguments, and don't type a prompt (`PS C:\>`) in front of the
  command. If the example shows output, put it after the command, separated by a blank line.
- Comments explain why, not what. Use full sentences in English. A regular expression usually
  deserves a comment saying what it matches.

## Documentation

Markdown files and comment-based help follow Microsoft's [PowerShell-Docs style
guide](https://learn.microsoft.com/powershell/scripting/community/contributing/powershell-style-guide)
and [Markdown best
practices](https://learn.microsoft.com/powershell/scripting/community/contributing/general-markdown).
The rules that matter for this repository:

### Writing about code

- Use the full, correctly cased name of every command and parameter. Use an alias only when you're
  documenting that alias, such as the shortcut functions in the README.
- Put these in backticks: command, function and script names; variables (`$PROFILE`); parameter
  values; keywords and operators; file and folder paths; native commands (`git`, `brew`); type names
  written with brackets (`[System.IO.FileInfo]`); and method names (`ToString()`).
- Write a parameter in backticks with its hyphen (`-Force`) when showing how to type it. When
  talking about it as a name in a sentence, write it in bold without the hyphen: "the **Force**
  parameter".
- Show paths in the form that works on the platform being discussed. When a step applies everywhere,
  use `$HOME/...` with forward slashes.

### Code samples

- Every code sample goes in a fenced block. Never indent to make a code block.
- Tag PowerShell blocks `powershell`, command output `Output`, and JSON `json`. Leave syntax
  diagrams untagged.
- Don't put a prompt in front of commands. Use `PS>` only when the prompt itself is the point of the
  example.
- Samples meant to be copied follow the code rules in this file. That means no aliases, no
  positional parameters, and no backtick line continuation. Splat instead.

### Markdown layout

- Use ATX headings (`#`) in sentence case. Use one H1 per file, as its first line. Don't skip
  heading levels, and go no deeper than H4. Don't use bold or other markup in headings.
- Use one blank line between blocks, never two. No trailing spaces and no tabs.
- Use `-` for bullets. Number every item of an ordered list `1.`; Markdown renders the real numbers,
  and reordering stays a one-line change.
- Use `**bold**` and `_italic_`.
- End a list item with a period only if it's a full sentence.
- Give every link descriptive text. Use HTTPS. Leave the locale (`/en-us/`) and `?view=` parameters
  out of Microsoft Learn links unless you need one specific version.
- Wrap Markdown prose at 100 characters. Tables, long links and code blocks can run longer.

These rules are linted by [`.markdownlint.json`](.markdownlint.json), which the markdownlint
extension for VS Code picks up automatically.

### Where the two guides disagree

| Topic | PoshCode guide | PowerShell-Docs guide | Decision |
| --- | --- | --- | --- |
| Line length | 115 for code | 100 for Markdown prose, 76 to 80 for `about_` topics | 120 for code (see [Line length](#layout-and-formatting)), 100 for Markdown prose. Comment-based help text wraps at 100, since `Get-Help` shows it in a console. |
| Positional parameters | Expose them, but avoid them in shared scripts | Never in examples | Never, in code or examples. |
| Parameter help | Comment above each parameter | Generated MAML help with `.PARAMETER` sections (PlatyPS) | Comment above each parameter. PSProfile ships comment-based help, not MAML, so PlatyPS's reference-article structure doesn't apply. |
| Prompts in examples | Not addressed | Avoid them, except `PS>` when the prompt matters | No prompts. |
| Brace style | OTBS | Not addressed; some syntax diagrams put the brace on a new line | OTBS for all code, including samples. Syntax diagrams are untagged and exempt. |
| Example paths | Windows paths | Windows paths (`C:\Windows`) | Paths that work on every OS the example applies to. |

The README doesn't follow the wrapping and list-numbering rules yet. Reflow it in a separate commit
that changes only layout, not as part of a content change.

## Error handling

- Inside `try`, call cmdlets with `-ErrorAction Stop`. Otherwise a non-terminating error skips the
  `catch` and execution carries on.
- Native programs (`git`, `brew`, `winget`, `apt-get`) don't throw when they fail; they set
  `$LASTEXITCODE`. Check it after every call whose failure matters. A `try`/`catch` around `& brew
  install ...` never catches a failed install. `$PSNativeCommandUseErrorActionPreference` would
  change that, but it doesn't exist in 5.1, so don't rely on it in files that run there.
- Put the whole transaction in the `try` block instead of setting success flags (ERR-03). In a
  `catch`, copy `$_` to a variable before running anything else (ERR-06).
- Don't test `$?` to decide whether a cmdlet worked (ERR-04).
- In an advanced function, report a failure that stops the command with
  `$PSCmdlet.ThrowTerminatingError($_)` or `throw`, and a failure for one input among many with
  `Write-Error`, then continue to the next input
  ([#37](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/37)).
- A `Get-` function given an exact name that doesn't exist writes a non-terminating error. Given a
  wildcard or filter that matches nothing, it returns nothing. This is the PowerShell committee's
  rule for new cmdlets ([#113](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/113)).
- `-ErrorAction SilentlyContinue` is fine for probes where absence is expected, such as `Get-Command
  -Name git -ErrorAction SilentlyContinue`. Don't use it to hide errors you didn't anticipate. No
  empty `catch` blocks; at least write a `Write-Verbose` saying what was skipped and why. **(lint)**

## Strict mode

`sample-config.json` turns on `Set-StrictMode -Version Latest`, and `profile.ps1` applies it at
global scope. Every dot-sourced function, and every command the user types at the prompt, runs under
it. So all code here **must run cleanly under strict mode Latest**. In practice that means:

- **`.Count` and `.Length`:** wrap anything that might be `$null` or a single object in `@()` before
  using `.Count`, as in `@($jobs | Where-Object { $_.State -eq 'Running' }).Count`. Under strict
  mode, `.Count` on `$null` or on a scalar that doesn't have that property throws.
- **Optional properties:** a missing property on an object throws. This hits configuration read from
  JSON, where every key is optional. Test before reading: `if
  ($module.PSObject.Properties['PSVersionMajorMax']) { ... }`. A small helper that returns a
  property value or a default keeps this readable.
- **Variables:** initialize every variable before reading it, including in branches that might not
  run.
- **Platform variables:** `$IsWindows`, `$IsMacOS` and `$IsLinux` don't exist in 5.1, so reading
  them there throws (see [Platform detection](#platform-detection)).

The guide doesn't take a position on strict mode, and its discussion
([#51](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/51)) leans toward static
analysis instead. Strict mode is a runtime check, so it only catches the paths you actually run. Use
both: the linter for what it can see, strict mode for what it can't.

## Cross-platform rules

These cover gaps in the guide, which was written for Windows only.

### Platform detection

`$IsWindows`, `$IsMacOS` and `$IsLinux` were added in PowerShell 6. In 5.1 they're undefined, so
they read as `$null` normally and throw under strict mode. Code that can run on 5.1 must check the
edition first:

```powershell
$onWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows
```

The `-or` short-circuits, so on 5.1 `$IsWindows` is never read. Files in `macos/` and `linux/` can
use the variables directly.

### Paths

- Never write `\` inside a path string in cross-platform code. PowerShell's own cmdlets often accept
  it on Linux and macOS, but the moment that string reaches a .NET method, a native program, or an
  error message, it breaks or misleads.
- Build paths with `Join-Path` (one child segment per call, since `-AdditionalChildPath` is 6+ only)
  or `[System.IO.Path]::Combine($a, $b, $c)` for several segments. `Join-Path` resolves the drive
  through the provider, so it fails for a drive that doesn't exist on this machine.
  `[System.IO.Path]::Combine` doesn't
  ([#84](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/84)).
- The guide's advice to use `${Env:UserProfile}` instead of `~` is Windows-only. Use `$HOME`, which
  exists on every platform and in 5.1. Don't use `~` in strings either; it's only expanded in some
  contexts.
- Use `$env:TEMP` and `$env:APPDATA` only in Windows-only code. Cross-platform code uses
  `[System.IO.Path]::GetTempPath()` and `[Environment]::GetFolderPath()`, or an explicit XDG lookup
  (`$env:XDG_CONFIG_HOME`, then `$HOME/.config`).
- Base paths on `$PSScriptRoot` or `$Global:PSProfileRoot`, never on the current directory. .NET
  methods resolve relative paths against the process directory, not `$PWD`.
- When a parameter takes a path from the user, offer `-LiteralPath` for paths that contain `[` or
  `]`.
- Match the case of every file and folder name exactly.

### Encoding and line endings

- Keep source files ASCII where you can. Windows PowerShell 5.1 reads a `.ps1` file without a
  byte-order mark as the system ANSI code page. A UTF-8 character such as `é` in a BOM-less file
  therefore turns into mojibake on 5.1. Curly quotes and dashes are worse: their bytes decode into
  characters PowerShell treats as quotes or dashes, which can break parsing. PowerShell 7 assumes
  UTF-8.
- If a file needs non-ASCII characters, save it as UTF-8 **with** a BOM. Both 5.1 and 7 read that
  correctly. **(lint, via `PSUseBOMForUnicodeEncodedFile`)**
- Don't change the encoding of an existing file unless that's the point of the commit.
- Use LF line endings. Both 5.1 and 7 read LF without trouble, and it keeps diffs clean across
  machines.
- When writing files, pass `-Encoding` explicitly. The defaults differ between 5.1 (UTF-16 for
  `Out-File`, ANSI for `Set-Content`) and 7 (UTF-8 without BOM).

### Windows-only APIs

- `Get-WmiObject` doesn't exist in PowerShell 7, and the `windows/` folder runs on 7 too. Use
  `Get-CimInstance`. Fall back to WMI only to reach an old remote machine over DCOM from 5.1, and
  only behind a version check. **(lint, via `PSAvoidUsingWMICmdlet`)**
- `[System.Reflection.Assembly]::LoadWithPartialName()` is obsolete. Use `Add-Type -AssemblyName`.
- `System.Web` and other .NET Framework-only assemblies don't exist on PowerShell 7. A function that
  needs one belongs in `windows/`, with a note saying it's 5.1-only.

### Secrets

The guide's security chapter assumes Windows:

- `SecureString` is only encrypted in memory on Windows. On macOS and Linux it's a plain string with
  a different type. Still take `[pscredential]` and `[securestring]` parameters (they keep secrets
  out of history and logs), but don't claim they protect anything at rest on those platforms.
- `ConvertFrom-SecureString` and `Export-Clixml` protect secrets with DPAPI, which is Windows-only.
  Don't use them to store secrets in cross-platform code.
- API keys come from the gitignored `config.json` through `DefaultParameterValues`, as described in
  the README. Never hard-code a secret, and never commit one to `sample-config.json`. For anything
  more sensitive, use `Microsoft.PowerShell.SecretManagement`.
- Don't use `Invoke-Expression` on anything assembled from input. **(lint)** The accepted exceptions
  are tool-generated init and completion scripts, such as `oh-my-posh init pwsh |
  Invoke-Expression`, where the tool's own documentation requires it. Suppress the warning at each
  such call with a justification.

## Profile-specific rules

The guide is written for modules and standalone scripts. A profile has extra constraints because it
runs at the start of every shell.

- **Nothing runs at load time except definitions.** A file under `assets/` defines one function and
  nothing else: no top-level commands, no network calls, no module imports. Every shell pays for
  every line that runs during dot-sourcing.
- **Import what you use.** `sample-config.json` sets `$PSModuleAutoLoadingPreference = 'None'`, so a
  command from a module that isn't loaded yet isn't found. A function that uses a module outside the
  core engine (`CimCmdlets`, `Microsoft.WinGet.Client`, `PSReadLine`, `ActiveDirectory`) imports it
  inside the function, right before first use.
- **No `#Requires` in profile-loaded files.** A failed `#Requires` stops the dot-source of that
  file. `#Requires -Modules` also imports the module at load time
  ([#131](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/131)). Check versions and
  modules at runtime inside the function, and fail with a clear message.
- **Interactive-only behavior** (PSReadLine handlers, banners, window titles, prompts) is gated on
  `Test-InteractiveShell` so scripts, CI and editors that load the profile stay quiet.
- **Global variables** are only for state the profile shares with its own functions. Name them with
  a `PSProfile` prefix (`$Global:PSProfileRoot`). **(lint)** The rule flags every global, so
  suppress it with a justification where one is intended.
- **Overriding a built-in alias** (as `gc` or `cd` do) requires removing the alias first. See
  "Adding functions" in the README.

## Performance

- Measure before optimizing (PERF-01); readability wins unless the data is large (PERF-02).
- The `foreach` statement is much faster than `ForEach-Object` for data that's already in memory. A
  pipeline is better when streaming a large file, because `foreach` loads the whole collection first
  ([#65](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/65)).
- Don't grow an array with `+=` in a loop; each append copies the whole array. Assign the loop's
  output instead (`$results = foreach (...) { ... }`), or use
  `[System.Collections.Generic.List[object]]`.
- Use `$null = ...` instead of `| Out-Null` to discard output. Piping costs a whole pipeline.
- Put `$null` on the left of comparisons: `$null -eq $x`. With an array on the left, `-eq` filters
  the array instead of comparing it
  ([#132](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/132)). **(lint)**

## Linting

[`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1) at the repository root encodes
every rule marked **(lint)** above. The VS Code PowerShell extension picks it up automatically from
the workspace root.

To run it by hand (PSScriptAnalyzer 1.25 or later):

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

The settings check compatibility against Windows PowerShell 5.1 and PowerShell 7 on Windows, which
covers `profile.ps1`, `setup.ps1` and the `windows/` folders. To also check the cross-platform
copies against Linux:

```powershell
$settings = Import-PowerShellDataFile -Path ./PSScriptAnalyzerSettings.psd1
$linux = 'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core'
$settings.Rules.PSUseCompatibleCommands.TargetProfiles += $linux
$settings.Rules.PSUseCompatibleTypes.TargetProfiles += $linux
'./assets/public/linux', './assets/private/linux' |
    ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings $settings }
```

PSScriptAnalyzer has no macOS compatibility profile; the Linux profile is the closest substitute.

The existing code doesn't pass yet, especially the upstream files. The goal is that new and changed
code adds no new warnings. When a rule has to be broken on purpose, suppress it at that function
with a reason:

```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '',
    Justification = 'oh-my-posh init output must be evaluated in the current scope.')]
```

Some rules can't be linted: single quotes, camelCase locals, one function per file, no load-time
work, `$LASTEXITCODE` checks, strict-mode safety and path separators. Those rely on review.

## How the guide's open questions are settled here

The guide is still marked as a preview, and many of its points were argued in issues that never
closed. This table records where this project lands on each one.

| Topic | Guide issue(s) | Decision for PSProfile |
| --- | --- | --- |
| Brace style | [#24](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/24), [#81](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/81) | OTBS with `} else {` on one line. |
| Backticks vs. splatting | [#15](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/15) | Splat or use natural line breaks; no backtick continuation in new code. |
| Line length | [#30](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/30), [#47](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/47), [#145](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/145) | 120, as a warning. |
| Tabs, spaces, indent width | [#120](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/120), [#141](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/141) | Four spaces. |
| Spaces inside parentheses | [#109](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/109) | None inside `( )` and `[ ]`; one inside `{ }` and `$( )`. |
| `param()` or `param ()` | [#128](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/128) | `param(`, the repository's predominant form. |
| Pipeline line breaks | [#106](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/106), [#184](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/184) | Break after `\|`, indent one level. |
| Semicolons | [#159](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/159) | None as terminators; one statement per line except short guard clauses. |
| Variable casing | [#61](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/61) | PascalCase for parameters and shared variables, camelCase for locals. |
| Keywords and acronyms | [#36](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/36), [#53](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/53) | Lowercase keywords and operators; .NET acronym rule; no renames of existing names. |
| Type name casing | [#54](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/54), [#154](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/154) | Lowercase accelerators, PascalCase attributes and full type names. |
| Quotes | [#63](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/63) | Single quotes for constant strings; not linted. |
| Aliases in code | [#108](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/108) | Never in code; shortcut functions are interactive-only. |
| Non-advanced functions | [#32](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/32) | Always `[CmdletBinding()]`, except interactive shortcuts and handler scriptblocks. |
| Named blocks | [#181](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/181) | Name every block you use; pipeline input goes in `process`. |
| `Mandatory` syntax | [#52](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/52) | `[Parameter(Mandatory)]`. |
| Parameter defaults | [#67](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/67), [#190](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/190) | Only meaningful defaults; compute complex ones in the body. |
| Three-state switches | [#69](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/69) | Never. |
| `ValidatePattern` | [#18](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/18), [#33](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/33) | `ValidateSet`, or `ValidateScript` with a readable `throw`. |
| `return` vs. `Write-Output` | [#46](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/46) | Implicit output; `return` only to exit early. |
| Error strategy | [#37](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/37), [#74](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/74) | `-ErrorAction Stop` inside `try`; `ThrowTerminatingError` or `Write-Error` per the rules above; check `$LASTEXITCODE`. |
| Error when nothing is found | [#113](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/113) | Error for an exact name, nothing for a wildcard. |
| `$_` vs. `$PSItem` | [#143](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/143) | `$_`. |
| `$null` comparisons | [#132](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/132) | `$null` on the left. |
| Strict mode | [#51](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/51) | All code must run under `Latest`, plus static analysis. |
| `New-Object` | [#60](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/60) | Avoid; use `[pscustomobject]@{}` and `::new()`. |
| `foreach` vs. `ForEach-Object` | [#65](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/65), [#148](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/148) | `foreach` for in-memory data, pipeline for streaming. |
| `Set-Variable` | [#144](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/144) | Plain assignment, except when you need `-Scope` or `-Option`. |
| Paths | [#64](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/64), [#84](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/84) | See [Paths](#paths). |
| PowerShell 7 practices | [#68](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/68) | See [Cross-platform rules](#cross-platform-rules). |
| `#Requires` | [#131](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/131), [#189](https://github.com/PoshCode/PowerShellPracticeAndStyle/pull/189) | Not in profile-loaded files. |
| Help placement and indentation | [#147](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/147), [#161](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/161) | Inside the function; parameter comments in the `param` block. |
| Classes | [#97](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/97), [#107](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/107), [#185](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/185) | Not in profile files; `[pscustomobject]` with `PSTypeName`. |
| Profile organization | [#38](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/38) | See [Profile-specific rules](#profile-specific-rules). |
| Command prefixes | [#23](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/23) | `PSProfile` noun prefix for profile-internal functions only. |
| Module layout, building, packaging, dot-sourcing, configuration | [#22](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/22), [#59](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/59), [#79](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/79), [#102](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/102), [#151](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/151), [#157](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/157) | Not applicable: PSProfile is a dot-sourced profile, not a module. |

The guide's "PURE" section (prefer native PowerShell over .NET or external tools) is marked dubious
by the guide itself. It's adopted here only in its PURE-03 form: when you reach for .NET, COM or a
native program, say why in a comment. Its WAST-02 link for reporting bugs is out of date; PowerShell
bugs go to
[github.com/PowerShell/PowerShell/issues](https://github.com/PowerShell/PowerShell/issues).
