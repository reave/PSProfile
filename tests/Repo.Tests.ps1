#- Static checks over the repo. No code from the profile runs here, so these behave the
#- same on every OS; CI still runs them everywhere because parsing differs on 5.1.

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $repoRoot = Get-PSProfileRepoRoot

    $scriptCases = Get-ChildItem -Path $repoRoot -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
        ForEach-Object { @{ Path = $_.FullName; Name = $_.FullName.Substring($repoRoot.Length + 1) } }

    $publicCases = Get-ChildItem -Path (Join-Path $repoRoot 'assets/public') -Directory | ForEach-Object {
        $folder = $_.Name
        Get-ChildItem -Path $_.FullName -Filter '*.ps1' -File | ForEach-Object {
            @{ Path = $_.FullName; Name = "$folder/$($_.Name)"; BaseName = $_.BaseName }
        }
    }
    $osCases = 'windows', 'macos', 'linux' | ForEach-Object { @{ OS = $_ } }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $repoRoot = Get-PSProfileRepoRoot
}

Describe 'PowerShell sources' {
    It '<Name> parses without errors' -ForEach $scriptCases {
        $tokens = $null; $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" } | Should -BeNullOrEmpty
    }
}

Describe 'Public function files' {
    It '<Name> defines a function named after the file' -ForEach $publicCases {
        Get-PSProfileDefinedFunction -Path $Path | Should -Contain $BaseName
    }

    It '<Name> has comment-based help with a synopsis' -ForEach $publicCases {
        # Files that had no comment-based help when this test was added. Remove a name once
        # its help is written; new functions are not exempt.
        $exempt = @(
            'Get-DriveInfo', 'Get-EncodedFile', 'Get-FolderSizes',
            'Get-PublicDesktopShortcuts', 'Lock-Workstation', 'Resolve-ShortURL', 'Search-Google',
            'Send-MagicPacket', 'Set-LocationAndList', 'Set-LocationCustom', 'Set-PathVariable', 'Sudo'
        )
        if ($BaseName -in $exempt) { Set-ItResult -Skipped -Because 'help not written yet'; return }

        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $function = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $BaseName }, $false) | Select-Object -First 1
        $function.GetHelpContent().Synopsis | Should -Not -BeNullOrEmpty
    }

    It 'no two files loaded on <OS> define the same function' -ForEach $osCases {
        $defined = foreach ($kind in 'public', 'private') {
            Get-PSProfileFunctionFile -Kind $kind -OS $OS | Get-PSProfileDefinedFunction
        }
        $defined | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name | Should -BeNullOrEmpty
    }
}

Describe 'Shared and OS folders' {
    # Cross-platform functions live once in assets/<kind>/shared. An OS folder may override a
    # shared file on purpose, but a byte-identical copy is just a duplicate that will drift.
    It '<Kind> OS folders hold no identical copies of shared files' -ForEach @(@{ Kind = 'public' }, @{ Kind = 'private' }) {
        $sharedPath = Join-Path $repoRoot "assets/$Kind/shared"
        $duplicates = foreach ($os in Get-PSProfileOSFolder -Kind $Kind) {
            $osPath = Join-Path $repoRoot "assets/$Kind/$os"
            Get-ChildItem -Path $osPath -Filter '*.ps1' -File -Recurse | ForEach-Object {
                $relative = $_.FullName.Substring($osPath.Length + 1)
                $sharedFile = Join-Path $sharedPath $relative
                if ((Test-Path -LiteralPath $sharedFile) -and
                    (Get-FileHash -LiteralPath $sharedFile).Hash -eq (Get-FileHash -LiteralPath $_.FullName).Hash) { "$os/$relative" }
            }
        }
        $duplicates | Should -BeNullOrEmpty
    }
}

Describe 'Config files' {
    BeforeAll {
        $sample = Get-Content -Path (Join-Path $repoRoot 'assets/config/sample-config.json') -Raw | ConvertFrom-Json
    }

    It 'sample-config.json has settings, Aliases, Modules, and Packages' {
        $sample.settings | Should -Not -BeNullOrEmpty
        $sample.PSObject.Properties.Name | Should -Contain 'Aliases'
        $sample.PSObject.Properties.Name | Should -Contain 'Modules'
        $sample.PSObject.Properties.Name | Should -Contain 'Packages'
    }

    It 'every sample module names a known OS' {
        $valid = 'All', 'Windows', 'MacOS', 'Linux'
        foreach ($module in $sample.Modules) {
            $module.Name | Should -Not -BeNullOrEmpty
            foreach ($os in ($module.OS -split '\s*,\s*' | Where-Object { $_ })) { $os | Should -BeIn $valid -Because $module.Name }
        }
    }

    It 'every sample package uses a supported source' {
        foreach ($package in $sample.Packages) {
            $package.Name | Should -Not -BeNullOrEmpty
            $package.Id | Should -Not -BeNullOrEmpty
            $package.Source | Should -BeIn 'winget', 'brew', 'apt', 'yum', 'pacman' -Because $package.Id
        }
    }
}
