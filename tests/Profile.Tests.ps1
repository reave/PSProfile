#- Loads profile2.0.ps1 end to end on the running OS, in a child process with a minimal
#- config, and checks that every public function for this OS is callable afterwards.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    $script:expected = Get-PSProfileFunctionFile -Kind public | Get-PSProfileDefinedFunction | Sort-Object -Unique
    $scratch = Join-Path $TestDrive 'load'
    # Two loads against the same cache folder: the first starts cold, the second reuses
    # whatever the first cached, and the two can take different code paths.
    $script:cold = Invoke-PSProfileLoad -Destination $scratch -FunctionName $script:expected
    $script:warm = Invoke-PSProfileLoad -Destination $scratch -FunctionName $script:expected
}

Describe 'Profile load (<_>)' -ForEach 'cold', 'warm' {
    BeforeAll {
        $load = if ($_ -eq 'cold') { $script:cold } else { $script:warm }
    }

    It 'loads without errors' {
        $load.Errors | Should -BeNullOrEmpty -Because "warnings were: $($load.Warnings -join '; ')"
    }

    It 'exits cleanly' {
        $load.ExitCode | Should -Be 0 -Because "child output was:`n$($load.Output)"
    }

    It 'makes every public function available' {
        $script:expected.Count | Should -BeGreaterThan 0
        $load.Missing | Should -BeNullOrEmpty
    }
}
