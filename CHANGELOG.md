# Changelog

All notable changes to PSProfile are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version of the profile is the
`version` in `assets/config/sample-config.json`.

## 1.0.0 - 2026-11-24

The first release.

### Added

- One `profile.ps1` for Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS and Linux,
  driven by `assets/config/config.json`.
- `setup.ps1`, which installs the profile, creates `config.json` from `sample-config.json` and
  links `$PROFILE` to the install.
- Config-driven modules, packages, aliases, PSReadLine settings and native completions.
- A library of helper functions, split by the operating systems each one supports.
- `Update-Profile`, which pulls the latest version and reloads the profile.
- `Update-ProfileConfig`, which adds new settings from `sample-config.json` to `config.json` and
  keeps your own settings. `Update-Profile` runs it after each update.
- `$PSProfileVersion`, and a startup warning when `config.json` was made from an older sample.
