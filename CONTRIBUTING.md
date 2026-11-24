# Contributing to PSProfile

PSProfile runs on Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS and Linux. Every change
needs to keep working on each platform it supports.

## Before you change anything

- Read [STYLE.md](STYLE.md). It's the coding and documentation standard for this repository.
- To add a function, follow [Adding functions](README.md#adding-functions) in the README.

## Making a change

- Keep each pull request to one change. If you want to reformat a file, do it in a separate commit
  that changes only whitespace and layout.
- Run PSScriptAnalyzer with [`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1), as
  described in [Linting](STYLE.md#linting). New and changed code should add no new warnings.
- Lint Markdown with [`.markdownlint.json`](.markdownlint.json). Lines wrap at 100 columns.
- Load the profile in Windows PowerShell 5.1 and in PowerShell 7 before you open a pull request.

## Versioning

The profile's version is the `version` in `assets/config/sample-config.json`, written as
Major.Minor.Build.Revision. Always write all four parts: `1.0.0.0`, never `1.0.0`. The full rules
are in [Versioning](STYLE.md#versioning) in STYLE.md. In short:

- **Major**: a change that can break your scripts or needs a manual action, such as removing or
  renaming a command or a config key, changing a parameter's type, or raising the minimum
  PowerShell version.
- **Minor**: a new capability that breaks nothing, such as a new function, a new parameter or
  config option with a safe default, or a new module or alias in `sample-config.json`.
- **Build**: fixes and quality work that add nothing new to use, such as bug fixes, refactors,
  help, lint cleanup or documentation corrections.
- **Revision**: a small correction to the same build, or a hotfix, such as a typo or a one-line
  regression fix right after a release.

A higher bump resets the lower parts to `0`. Bump once per release to `main`, not once per pull
request. The exception is `sample-config.json`: every change to its settings or entries bumps the
version in the same commit.

### Bumping the version

1. Decide which part to bump. Use the highest part that any change in the release needs.
1. Change `version` in `assets/config/sample-config.json`. Write all four parts, and reset the
   parts after the one you bumped to `0`.
1. Add a section for the new version at the top of [CHANGELOG.md](CHANGELOG.md).
1. Confirm the new version casts to `[version]`:

   ```powershell
   $sample = Get-Content -Path ./assets/config/sample-config.json -Raw | ConvertFrom-Json
   [version]$sample.version
   ```

1. If the shape of `sample-config.json` changed, commit the change, then confirm that
   `Update-ProfileConfig -WhatIf` handles each added, changed or removed setting in an existing
   `config.json`.
1. Confirm the profile loads in Windows PowerShell 5.1 and PowerShell 7, and that
   `$PSProfileVersion` shows the new version.
