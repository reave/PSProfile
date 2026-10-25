#- Shared helpers for the Pester suites in this folder.
#- Function discovery follows the profile's folder layout: assets\<kind>\shared plus
#- assets\<kind>\<os> (OS files win on a name clash).

$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent

<#
.SYNOPSIS
    Returns the repository root (the folder holding profile2.0.ps1).
#>
function Get-PSProfileRepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $script:RepoRoot
}

<#
.SYNOPSIS
    Returns the asset folder name for the running OS: windows, macos, or linux.
.DESCRIPTION
    Windows PowerShell 5.1 has no $IsWindows, so the Desktop edition counts as Windows.
#>
function Get-PSProfileOSName {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) { 'windows' }
    elseif ($IsMacOS) { 'macos' }
    else { 'linux' }
}

<#
.SYNOPSIS
    Lists the OS folder names that exist under assets\<Kind>, excluding shared.
#>
function Get-PSProfileOSFolder {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('public', 'private')]
        [string]$Kind = 'public'
    )

    $base = Join-Path -Path $script:RepoRoot -ChildPath "assets/$Kind"
    Get-ChildItem -Path $base -Directory | Where-Object Name -ne 'shared' | ForEach-Object Name
}

<#
.SYNOPSIS
    Returns the top-level .ps1 files the profile loads for one OS.
.PARAMETER Kind
    public (user-facing functions) or private (profile internals).
.PARAMETER OS
    windows, macos, or linux. Defaults to the running OS.
#>
function Get-PSProfileFunctionFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [ValidateSet('public', 'private')]
        [string]$Kind = 'public',

        [ValidateSet('windows', 'macos', 'linux')]
        [string]$OS = (Get-PSProfileOSName)
    )

    $base = Join-Path -Path $script:RepoRoot -ChildPath "assets/$Kind"
    $files = [ordered]@{}
    foreach ($folder in @((Join-Path $base 'shared'), (Join-Path $base $OS))) {
        if (-not (Test-Path -Path $folder)) { continue }
        foreach ($file in Get-ChildItem -Path $folder -Filter '*.ps1' -File) { $files[$file.Name] = $file }
    }
    $files.Values | Sort-Object -Property Name
}

<#
.SYNOPSIS
    Returns the names of the functions a script file defines at its top level.
#>
function Get-PSProfileDefinedFunction {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$Path
    )

    process {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        foreach ($block in @($ast.BeginBlock, $ast.ProcessBlock, $ast.EndBlock)) {
            if (-not $block) { continue }
            $block.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object Name
        }
    }
}

<#
.SYNOPSIS
    Dot-sources the file that defines a public function into the caller's scope.
.DESCRIPTION
    Returns the file path; the caller must dot-source it (". (Import-PSProfileFunction X)")
    so the function lands in the test's scope rather than this module's.
#>
function Import-PSProfileFunction {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $file = Get-PSProfileFunctionFile -Kind public | Where-Object { (Get-PSProfileDefinedFunction -Path $_.FullName) -contains $Name } | Select-Object -First 1
    if (-not $file) { throw "No public function file defines $Name for $(Get-PSProfileOSName)." }
    $file.FullName
}

<#
.SYNOPSIS
    Copies the repo to a scratch folder with a minimal config.json and loads the profile
    in a child process, returning what the load produced.
.DESCRIPTION
    A child process keeps the profile's global side effects (aliases, default parameter
    values, PSReadLine settings) out of the test session. The config lists no Modules or
    Packages so nothing is installed. LOCALAPPDATA and XDG_CACHE_HOME point inside the
    scratch folder so profile caches stay hermetic; call it twice against the same
    Destination to exercise a warm cache.
.PARAMETER Destination
    Scratch folder (e.g. under $TestDrive). The repo is copied to <Destination>\PSProfile
    on the first call only.
.PARAMETER FunctionName
    Public function names to check with Get-Command after the load.
.OUTPUTS
    PSCustomObject with Errors (string[]), Warnings (string[]), Missing (string[]),
    ExitCode, and Output (the child's console output, for diagnostics).
#>
function Invoke-PSProfileLoad {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Destination,

        [string[]]$FunctionName = @()
    )

    $profileCopy = Join-Path -Path $Destination -ChildPath 'PSProfile'
    if (-not (Test-Path -Path $profileCopy)) {
        $null = New-Item -Path $profileCopy -ItemType Directory -Force
        Get-ChildItem -Path $script:RepoRoot -Force | Where-Object Name -notin '.git', 'tests', '.github' |
            Copy-Item -Destination $profileCopy -Recurse -Force

        $config = [ordered]@{
            name     = 'CI test config'
            settings = [ordered]@{
                MaximumHistoryCount    = 4096
                DefaultParameterValues = [ordered]@{ 'Export-Csv:NoTypeInformation' = $true }
            }
            Aliases  = @(@{ Name = 'pstest-alias'; Value = 'Get-ChildItem'; Description = 'CI alias check' })
            Modules  = @()
            Packages = @()
        }
        $config | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $profileCopy 'assets/config/config.json') -Encoding UTF8
    }

    $cacheRoot = Join-Path -Path $Destination -ChildPath 'cache'
    $null = New-Item -Path $cacheRoot -ItemType Directory -Force
    $resultPath = Join-Path -Path $Destination -ChildPath "result-$([guid]::NewGuid().ToString('N')).json"
    $namesPath = Join-Path -Path $Destination -ChildPath 'names.json'
    ConvertTo-Json -InputObject @($FunctionName) | Set-Content -Path $namesPath -Encoding UTF8

    # Single-quoted on purpose: expanded by the child, with paths passed via env vars.
    $childScript = @'
$loadErrors = @(); $loadWarnings = @()
# Only what reaches the error stream counts. $Error also holds errors the profile caught
# and handled itself (e.g. Get-Command probes for tools that aren't installed).
try {
    . (Join-Path $env:PSPROFILE_TEST_ROOT 'profile2.0.ps1') 2>&1 3>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $loadErrors += "$($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber) $($_.Exception.Message)"
        }
        elseif ($_ -is [System.Management.Automation.WarningRecord]) { $loadWarnings += $_.Message }
    }
}
catch { $loadErrors += "Terminating: $($_.Exception.Message)" }

$names = @(Get-Content -Path $env:PSPROFILE_TEST_NAMES -Raw | ConvertFrom-Json)
# [string[]] rather than @(): Windows PowerShell 5.1 serializes a pipeline-built array
# as {"value": [...], "Count": n}, which would read back as one non-empty entry.
[string[]]$missing = $names | Where-Object { -not (Get-Command -Name $_ -CommandType Function -ErrorAction SilentlyContinue) }
if (-not (Get-Alias -Name 'pstest-alias' -ErrorAction SilentlyContinue)) { $loadErrors += 'Configured alias pstest-alias was not created.' }

[ordered]@{ Errors = [string[]]$loadErrors; Warnings = [string[]]$loadWarnings; Missing = $missing } |
    ConvertTo-Json -Depth 3 | Set-Content -Path $env:PSPROFILE_TEST_RESULT -Encoding UTF8
'@

    $savedEnv = @{}
    $envOverrides = @{
        PSPROFILE_TEST_ROOT   = $profileCopy
        PSPROFILE_TEST_NAMES  = $namesPath
        PSPROFILE_TEST_RESULT = $resultPath
        LOCALAPPDATA          = $cacheRoot
        XDG_CACHE_HOME        = $cacheRoot
    }
    foreach ($key in $envOverrides.Keys) {
        $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key, $envOverrides[$key])
    }

    try {
        # Same executable as the test run, so the 5.1 job really loads under Windows PowerShell.
        $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript))
        $output = & $exe -NoProfile -NonInteractive -NoLogo -EncodedCommand $encoded 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        foreach ($key in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnv[$key]) }
    }

    if (-not (Test-Path -Path $resultPath)) {
        throw "Profile load child process wrote no result (exit $exitCode). Output:`n$output"
    }
    $result = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
    [PSCustomObject]@{
        Errors   = @($result.Errors | Where-Object { $_ })
        Missing  = @($result.Missing | Where-Object { $_ })
        Warnings = @($result.Warnings | Where-Object { $_ })
        ExitCode = $exitCode
        Output   = $output
    }
}

Export-ModuleMember -Function *-PSProfile*
