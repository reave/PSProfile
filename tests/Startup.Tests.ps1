#- Startup caches and helpers from profile2.0.ps1's interactive section: the splash screen
#- cache, oh-my-posh theme overrides and the weekly help refresh. Profile functions are
#- loaded on their own (by parsing profile2.0.ps1), not by running the whole profile.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $root = Get-PSProfileRepoRoot

    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'profile2.0.ps1'), [ref]$null, [ref]$null)
    $wanted = 'Get-PSProfileCachePath', 'Show-PSProfileSplash'
    $definitions = $profileAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $node.Name
        }, $false)
    foreach ($definition in $definitions) { . ([scriptblock]::Create($definition.Extent.Text)) }
    . (Join-Path $root 'assets/private/shared/Resolve-PoshTheme.ps1')

    # Every cache goes under TestDrive.
    $script:savedLocalAppData = $env:LOCALAPPDATA
    $script:savedXdgCache = $env:XDG_CACHE_HOME
    $env:LOCALAPPDATA = Join-Path $TestDrive 'localappdata'
    $env:XDG_CACHE_HOME = Join-Path $TestDrive 'xdg'
    $script:installRoot = Join-Path $TestDrive 'install'
}

AfterAll {
    $env:LOCALAPPDATA = $script:savedLocalAppData
    $env:XDG_CACHE_HOME = $script:savedXdgCache
}

Describe 'Show-PSProfileSplash' {
    BeforeEach {
        $global:PSProfileTestSplashRuns = 0
        function global:Invoke-PSProfileTestSplash {
            $global:PSProfileTestSplashRuns++
            "line one $([char]27)[35mcolored$([char]27)[0m"
            'line two'
        }
        Get-ChildItem -Path $TestDrive -Recurse -Filter 'splash.*' -ErrorAction Ignore | Remove-Item -Force
    }

    AfterAll {
        Remove-Item -Path function:global:Invoke-PSProfileTestSplash -ErrorAction Ignore
    }

    It 'runs the command once, then replays the cached output' {
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot
        $global:PSProfileTestSplashRuns | Should -Be 1
        $cache = Get-PSProfileCachePath -Root $script:installRoot -Name 'splash' -Extension '.txt'
        [System.IO.File]::ReadAllText($cache) | Should -Match 'line two'
    }

    It 'runs the command again when it changed' {
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash -Extra' -Root $script:installRoot
        $global:PSProfileTestSplashRuns | Should -Be 2
    }

    It 'runs the command every time when CacheHours is 0' {
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot -CacheHours 0
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot -CacheHours 0
        $global:PSProfileTestSplashRuns | Should -Be 2
    }

    It 'runs the command again once the cache is older than CacheHours' {
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot
        $cache = Get-PSProfileCachePath -Root $script:installRoot -Name 'splash' -Extension '.txt'
        [System.IO.File]::SetLastWriteTimeUtc($cache, [datetime]::UtcNow.AddHours(-25))
        Show-PSProfileSplash -Command 'Invoke-PSProfileTestSplash' -Root $script:installRoot
        $global:PSProfileTestSplashRuns | Should -Be 2
    }

    It 'does nothing when the command is not installed' {
        { Show-PSProfileSplash -Command 'psprofile-no-such-splash --flag' -Root $script:installRoot } | Should -Not -Throw
        $cache = Get-PSProfileCachePath -Root $script:installRoot -Name 'splash' -Extension '.txt'
        Test-Path -Path $cache | Should -BeFalse
    }
}

Describe 'Resolve-PoshTheme overrides' {
    BeforeEach {
        $script:theme = Join-Path $TestDrive 'Test.omp.json'
        Set-Content -Path $script:theme -Value '{ "version": 3, "final_space": true, "blocks": [ { "type": "prompt", "segments": [] } ] }'
        $script:overridePath = Join-Path $TestDrive 'cache/theme.omp.json'
        Remove-Item -Path "$script:overridePath*" -Force -ErrorAction Ignore
    }

    It 'returns the theme itself without overrides' {
        Resolve-PoshTheme -PoshTheme $script:theme -OverridePath $script:overridePath | Should -Be (Resolve-Path $script:theme).Path
        Test-Path -Path $script:overridePath | Should -BeFalse
    }

    It 'writes a copy with the overrides applied and returns it' {
        $override = [PSCustomObject]@{ shell_integration = $true; streaming = 100 }
        $result = Resolve-PoshTheme -PoshTheme $script:theme -Override $override -OverridePath $script:overridePath
        $result | Should -Be $script:overridePath
        $copy = Get-Content -Path $result -Raw | ConvertFrom-Json
        $copy.shell_integration | Should -BeTrue
        $copy.streaming | Should -Be 100
        $copy.final_space | Should -BeTrue
        @($copy.blocks).Count | Should -Be 1
    }

    It 'reuses the copy until the theme or overrides change' {
        $override = [PSCustomObject]@{ shell_integration = $true }
        $null = Resolve-PoshTheme -PoshTheme $script:theme -Override $override -OverridePath $script:overridePath
        [System.IO.File]::SetLastWriteTimeUtc($script:overridePath, [datetime]'2020-01-01')

        $null = Resolve-PoshTheme -PoshTheme $script:theme -Override $override -OverridePath $script:overridePath
        [System.IO.File]::GetLastWriteTimeUtc($script:overridePath).Year | Should -Be 2020

        $null = Resolve-PoshTheme -PoshTheme $script:theme -Override ([PSCustomObject]@{ shell_integration = $false }) -OverridePath $script:overridePath
        [System.IO.File]::GetLastWriteTimeUtc($script:overridePath).Year | Should -Not -Be 2020
        (Get-Content -Path $script:overridePath -Raw | ConvertFrom-Json).shell_integration | Should -BeFalse
    }

    It 'returns a non-JSON theme as is' {
        $yamlTheme = Join-Path $TestDrive 'Test.omp.yaml'
        Set-Content -Path $yamlTheme -Value 'version: 3'
        $result = Resolve-PoshTheme -PoshTheme $yamlTheme -Override ([PSCustomObject]@{ async = $true }) -OverridePath $script:overridePath -WarningAction SilentlyContinue
        $result | Should -Be (Resolve-Path $yamlTheme).Path
    }
}

Describe 'Update-PSProfileHelp' {
    BeforeAll {
        . (Join-Path (Get-PSProfileRepoRoot) 'assets/lib/PSProfile.Lifecycle.ps1')
    }

    BeforeEach {
        Remove-Item -Path (Join-Path (Get-PSProfileStateDirectory) 'update-state.json') -Force -ErrorAction Ignore
        Mock Update-Help { }
    }

    It 'updates help and records when' {
        Update-PSProfileHelp
        Should -Invoke Update-Help -Times 1 -Exactly
        (Get-PSProfileState)."LastHelpUpdate$($PSVersionTable.PSEdition)" | Should -Not -BeNullOrEmpty
    }

    It 'skips a second update within the interval' {
        Update-PSProfileHelp
        Update-PSProfileHelp
        Should -Invoke Update-Help -Times 1 -Exactly
    }

    It 'updates again once the interval has passed' {
        Set-PSProfileState -Values @{ "LastHelpUpdate$($PSVersionTable.PSEdition)" = [datetime]::UtcNow.AddDays(-8).ToString('o') }
        Update-PSProfileHelp
        Should -Invoke Update-Help -Times 1 -Exactly
    }
}
