#- Layered config (sample-config.json, config.json, config.<MACHINE>.json, config.local.json),
#- its JSON Schema, and secret lookup for functions that need API keys.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $repoRoot = Get-PSProfileRepoRoot

    # The layering helpers live in profile2.0.ps1; load just those, the way Lifecycle does.
    $helpers = 'Get-PSProfileConfigLayer', 'Merge-PSProfileConfigObject', 'Read-PSProfileConfig'
    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'profile2.0.ps1'), [ref]$null, [ref]$null)
    $definitions = $profileAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $helpers -contains $node.Name
        }, $false)
    foreach ($definition in $definitions) { . ([scriptblock]::Create($definition.Extent.Text)) }

    . (Join-Path $repoRoot 'assets/lib/PSProfile.Lifecycle.ps1')
    . (Import-PSProfileFunction -Name 'Get-PSProfileSecret')
    . (Import-PSProfileFunction -Name 'Get-Weather')

    function New-ConfigRoot {
        param([hashtable]$Files)
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $dir = Join-Path (Join-Path $root 'assets') 'config'
        $null = New-Item -Path $dir -ItemType Directory -Force
        foreach ($name in $Files.Keys) { Set-Content -Path (Join-Path $dir $name) -Value $Files[$name] -Encoding UTF8 }
        $root
    }

    $script:machineFile = "config.$([Environment]::MachineName).json"
}

Describe 'Merge-PSProfileConfigObject' {
    BeforeAll {
        $base = '{"settings":{"A":1,"B":{"X":"base","Y":"base"}},"Modules":[{"Name":"One"},{"Name":"Two"}]}' | ConvertFrom-Json
    }

    It 'merges nested objects key by key' {
        $overlay = '{"settings":{"B":{"Y":"overlay"},"C":true}}' | ConvertFrom-Json
        $merged = Merge-PSProfileConfigObject -Base $base -Overlay $overlay
        $merged.settings.A | Should -Be 1
        $merged.settings.B.X | Should -Be 'base'
        $merged.settings.B.Y | Should -Be 'overlay'
        $merged.settings.C | Should -BeTrue
    }

    It 'replaces arrays whole, including one-item and empty ones' {
        $one = Merge-PSProfileConfigObject -Base $base -Overlay ('{"Modules":[{"Name":"Only"}]}' | ConvertFrom-Json)
        , $one.Modules | Should -BeOfType [array]
        @($one.Modules).Count | Should -Be 1
        $one.Modules[0].Name | Should -Be 'Only'

        $none = Merge-PSProfileConfigObject -Base $base -Overlay ('{"Modules":[]}' | ConvertFrom-Json)
        , $none.Modules | Should -BeOfType [array]
        @($none.Modules).Count | Should -Be 0
    }

    It 'lets a layer set a value to null' {
        $merged = Merge-PSProfileConfigObject -Base $base -Overlay ('{"settings":{"A":null}}' | ConvertFrom-Json)
        $merged.settings.PSObject.Properties.Name | Should -Contain 'A'
        $merged.settings.A | Should -BeNullOrEmpty
    }

    It 'leaves both inputs unchanged' {
        $overlay = '{"settings":{"A":2,"B":{"X":"overlay"}}}' | ConvertFrom-Json
        $null = Merge-PSProfileConfigObject -Base $base -Overlay $overlay
        $base.settings.A | Should -Be 1
        $base.settings.B.X | Should -Be 'base'
        $overlay.settings.B.PSObject.Properties.Name | Should -Not -Contain 'Y'
    }
}

Describe 'Read-PSProfileConfig' {
    It 'merges every layer, later files winning' {
        $root = New-ConfigRoot -Files @{
            'sample-config.json' = '{"settings":{"Layer":"default","Default":true,"OneDrivePath":"C:\\Users\\josep\\OneDrive"}}'
            'config.json'        = '{"settings":{"Layer":"user","User":true}}'
            $script:machineFile  = '{"settings":{"Layer":"machine","OneDrivePath":"C:\\Users\\joseph\\OneDrive"}}'
            'config.local.json'  = '{"settings":{"Layer":"local"}}'
        }
        (Get-PSProfileConfigLayer -Root $root).Layer | Should -Be 'Default', 'User', 'Machine', 'Local'

        $config = Read-PSProfileConfig -Root $root
        $config.settings.Layer | Should -Be 'local'
        $config.settings.Default | Should -BeTrue
        $config.settings.User | Should -BeTrue
        $config.settings.OneDrivePath | Should -Be 'C:\Users\joseph\OneDrive'
    }

    It 'works with only the repo defaults' {
        $root = New-ConfigRoot -Files @{ 'sample-config.json' = '{"settings":{"MaximumHistoryCount":100}}' }
        (Read-PSProfileConfig -Root $root).settings.MaximumHistoryCount | Should -Be 100
    }

    It 'ignores another machine''s file' {
        $root = New-ConfigRoot -Files @{
            'sample-config.json'                 = '{"settings":{"Layer":"default"}}'
            'config.SOME-OTHER-MACHINE-123.json' = '{"settings":{"Layer":"other"}}'
        }
        (Read-PSProfileConfig -Root $root).settings.Layer | Should -Be 'default'
    }

    It 'skips a layer that fails to parse, with a warning, and keeps the rest' {
        $root = New-ConfigRoot -Files @{
            'sample-config.json' = '{"settings":{"Layer":"default","Kept":true}}'
            'config.json'        = '{"settings": {'
            'config.local.json'  = '{"settings":{"Layer":"local"}}'
        }
        $config = Read-PSProfileConfig -Root $root -WarningVariable warnings -WarningAction SilentlyContinue
        $warnings | Should -HaveCount 1
        "$warnings" | Should -Match 'config\.json'
        $config.settings.Layer | Should -Be 'local'
        $config.settings.Kept | Should -BeTrue
    }

    It 'returns nothing when there are no layers' {
        Read-PSProfileConfig -Root (New-ConfigRoot -Files @{}) | Should -BeNullOrEmpty
    }

    It 'gives Lifecycle the same merged config as the profile' {
        $root = New-ConfigRoot -Files @{
            'sample-config.json' = '{"Modules":[{"Name":"A"}],"settings":{"Layer":"default"}}'
            'config.local.json'  = '{"settings":{"Layer":"local"}}'
        }
        Copy-Item -Path (Join-Path $repoRoot 'profile2.0.ps1') -Destination $root
        $config = Get-PSProfileConfigFromPath -InstallPath $root
        $config.settings.Layer | Should -Be 'local'
        $config.Modules[0].Name | Should -Be 'A'
    }
}

Describe 'Copy-PSProfileLocalFile' {
    It 'carries personal layers into a new tree, but not over a machine file the tree ships' {
        $from = New-ConfigRoot -Files @{
            'sample-config.json' = '{"from":true}'
            'config.json'        = '{"from":true}'
            'config.local.json'  = '{"from":true}'
            'config.MINE.json'   = '{"from":true}'
            'config.SHIPPED.json' = '{"from":true}'
        }
        $to = New-ConfigRoot -Files @{ 'sample-config.json' = '{"from":false}'; 'config.SHIPPED.json' = '{"from":false}' }
        Copy-PSProfileLocalFile -From $from -To $to

        $dir = Join-Path (Join-Path $to 'assets') 'config'
        foreach ($name in 'config.json', 'config.local.json', 'config.MINE.json') {
            (Get-Content -Path (Join-Path $dir $name) -Raw | ConvertFrom-Json).from | Should -BeTrue -Because $name
        }
        (Get-Content -Path (Join-Path $dir 'config.SHIPPED.json') -Raw | ConvertFrom-Json).from | Should -BeFalse
        (Get-Content -Path (Join-Path $dir 'sample-config.json') -Raw | ConvertFrom-Json).from | Should -BeFalse
    }
}

Describe 'Config schema' {
    BeforeAll {
        $schemaPath = Join-Path $repoRoot 'assets/config/psprofile.schema.json'
        $configFiles = Get-ChildItem -Path (Join-Path $repoRoot 'assets/config') -Filter '*.json' |
            Where-Object Name -ne 'psprofile.schema.json'
    }

    It 'is valid JSON' {
        { Get-Content -Path $schemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'every checked-in config file points at the schema' {
        foreach ($file in $configFiles) {
            (Get-Content -Path $file.FullName -Raw | ConvertFrom-Json).'$schema' | Should -Be './psprofile.schema.json' -Because $file.Name
        }
    }

    # Test-Json only exists on PowerShell 7+.
    It 'every checked-in config file validates against it' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        $schema = Get-Content -Path $schemaPath -Raw
        foreach ($file in $configFiles) {
            Get-Content -Path $file.FullName -Raw | Test-Json -Schema $schema -ErrorAction SilentlyContinue | Should -BeTrue -Because $file.Name
        }
    }

    It 'rejects a wrong type' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        $schema = Get-Content -Path $schemaPath -Raw
        '{"settings":{"ShowSplashScreen":"yes"}}' | Test-Json -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It 'keeps API keys out of the sample DefaultParameterValues' {
        $sample = Get-Content -Path (Join-Path $repoRoot 'assets/config/sample-config.json') -Raw | ConvertFrom-Json
        $sample.settings.DefaultParameterValues.PSObject.Properties.Name | Where-Object { $_ -like '*:APIKey' } | Should -BeNullOrEmpty
    }
}

Describe 'Get-PSProfileSecret' {
    BeforeAll {
        # Stand-in for SecretManagement's Get-Secret: records what it was asked for.
        function Get-Secret {
            param([string]$Name, [string]$Vault, [switch]$AsPlainText)
            $script:secretCall = [PSCustomObject]@{ Name = $Name; Vault = $Vault; AsPlainText = [bool]$AsPlainText }
            if ($Name -eq 'Missing') { throw "The secret $Name was not found." }
            "value-of-$Name"
        }
    }

    BeforeEach {
        $script:savedSettings = Get-Variable -Name PSProfileSettings -Scope Global -ValueOnly -ErrorAction Ignore
        $script:secretCall = $null
    }

    AfterEach {
        Set-Variable -Name PSProfileSettings -Scope Global -Value $script:savedSettings
    }

    It 'reads an unmapped name from the default vault' {
        $Global:PSProfileSettings = $null
        Get-PSProfileSecret -Name 'OpenWeatherMapApiKey' | Should -Be 'value-of-OpenWeatherMapApiKey'
        $script:secretCall.AsPlainText | Should -BeTrue
        $script:secretCall.Vault | Should -BeNullOrEmpty
    }

    It 'follows a settings.Secrets name and settings.SecretVault' {
        $Global:PSProfileSettings = '{"SecretVault":"Profile","Secrets":{"OpenWeatherMapApiKey":"owm"}}' | ConvertFrom-Json
        Get-PSProfileSecret -Name 'OpenWeatherMapApiKey' | Should -Be 'value-of-owm'
        $script:secretCall.Vault | Should -Be 'Profile'
    }

    It 'lets an entry pick its own vault' {
        $Global:PSProfileSettings = '{"SecretVault":"Profile","Secrets":{"Key":{"Name":"other","Vault":"Work"}}}' | ConvertFrom-Json
        Get-PSProfileSecret -Name 'Key' | Should -Be 'value-of-other'
        $script:secretCall.Vault | Should -Be 'Work'
    }

    It 'returns nothing when the secret is missing' {
        $Global:PSProfileSettings = $null
        Get-PSProfileSecret -Name 'Missing' | Should -BeNullOrEmpty
    }

    It 'returns nothing for a 1Password reference when op is not installed' -Skip:([bool](Get-Command -Name op -CommandType Application -ErrorAction Ignore)) {
        $Global:PSProfileSettings = '{"Secrets":{"Key":"op://Personal/Item/credential"}}' | ConvertFrom-Json
        Get-PSProfileSecret -Name 'Key' | Should -BeNullOrEmpty
        $script:secretCall | Should -BeNullOrEmpty
    }
}

Describe 'Get-Weather API key' {
    It 'fails clearly when no key is passed or stored' {
        Mock Get-PSProfileSecret { }
        Mock Invoke-WebRequest { throw 'no network in tests' }
        { Get-Weather -City 'Boston' } | Should -Throw '*No OpenWeatherMap API key*'
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'uses the stored key over https when -APIKey is omitted' {
        Mock Get-PSProfileSecret { 'stored-key' } -ParameterFilter { $Name -eq 'OpenWeatherMapApiKey' }
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ Content = '<current><city name="Boston"><country>US</country></city><temperature value="50" max="55" min="45"/></current>' }
        }
        $weather = Get-Weather -City 'Boston' -Country 'US'
        $weather.City | Should -Be 'Boston'
        Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -like 'https://api.openweathermap.org/*APPID=stored-key*' }
    }

    It 'prefers an explicit -APIKey' {
        Mock Get-PSProfileSecret { 'stored-key' }
        Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '<current/>' } }
        $null = Get-Weather -City 'Boston' -APIKey 'explicit'
        Should -Invoke Get-PSProfileSecret -Times 0
        Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { "$Uri" -like '*APPID=explicit*' }
    }
}
