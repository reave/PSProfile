#- Static checks over the repo. No code from the profile runs here, so these behave the
#- same on every OS; CI still runs them everywhere because parsing differs on 5.1.

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $repoRoot = Get-PSProfileRepoRoot

    $scriptCases = Get-ChildItem -Path $repoRoot -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
        ForEach-Object { @{ Path = $_.FullName; Name = $_.FullName.Substring($repoRoot.Length + 1) } }

    $publicCases = foreach ($os in 'windows', 'macos', 'linux') {
        Get-PSProfileFunctionFile -Kind public -OS $os | ForEach-Object {
            @{ Path = $_.FullName; Name = "$os/$($_.Name)"; BaseName = $_.BaseName }
        }
    }
    $osCases = 'windows', 'macos', 'linux' | ForEach-Object { @{ OS = $_ } }
    $hasSharedLayout = Test-Path -Path (Join-Path $repoRoot 'assets/public/shared')
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

Describe 'Per-OS copies' -Skip:$hasSharedLayout {
    # Until the per-OS folders are consolidated into assets/public/shared, a function that
    # exists in more than one OS folder has to be the same file in each, or a fix made in one
    # copy silently misses the others.
    It 'public files shared between OS folders are identical' {
        $byName = Get-PSProfileOSFolder -Kind public | ForEach-Object {
            Get-ChildItem -Path (Join-Path $repoRoot "assets/public/$_") -Filter '*.ps1' -File
        } | Group-Object -Property Name | Where-Object Count -gt 1

        $drifted = foreach ($group in $byName) {
            $hashes = $group.Group | ForEach-Object { (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash } | Select-Object -Unique
            if (@($hashes).Count -gt 1) { $group.Name }
        }
        $drifted | Should -BeNullOrEmpty
    }

    It 'every macOS and Linux public function also exists on the other' {
        $mac = Get-PSProfileFunctionFile -Kind public -OS macos | ForEach-Object Name
        $linux = Get-PSProfileFunctionFile -Kind public -OS linux | ForEach-Object Name
        Compare-Object -ReferenceObject $mac -DifferenceObject $linux | ForEach-Object { "$($_.InputObject) $($_.SideIndicator)" } | Should -BeNullOrEmpty
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

    It 'powershell.config.json is valid JSON' {
        { Get-Content -Path (Join-Path $repoRoot 'powershell.config.json') -Raw | ConvertFrom-Json } | Should -Not -Throw
    }
}
