<#
.SYNOPSIS
    Brings config.json up to date with the sample-config.json that ships with this profile.
.DESCRIPTION
    Compares assets\config\config.json with assets\config\sample-config.json and adds what the
    sample has gained since config.json was made, without losing any of your own settings:

    - Settings that are new in the sample are added with the sample's value.
    - New Aliases, Modules, Packages and NativeCompletions entries are added. Entries are
      matched by Name, plus Source for Packages.
    - A setting or entry whose default changed in the sample is updated only if you never
      changed it from the old default.
    - A setting or entry the sample no longer has is removed only if you never changed it.
    - Anything you added, changed or removed yourself is kept as it is.
    - config.json's "version" is set to the sample's version.

    To tell your changes apart from the sample's, it reads the sample-config.json that matches
    config.json's version from the install's git history, choosing the closest one if several
    share that version. Without git (a zip install), or when
    no sample with that version is found, it only adds settings that are missing, and leaves
    the entry lists and existing values alone.

    Before writing, it saves the current file as config.json.bak-<timestamp> next to it. If
    config.json doesn't exist, it's created from sample-config.json.

    Update-Profile runs this after it pulls an update. Run it directly after updating the
    install some other way, such as with git pull.
.EXAMPLE
    Update-ProfileConfig

    Adds new settings from sample-config.json to config.json and reports what changed.
.EXAMPLE
    Update-ProfileConfig -WhatIf

    Shows whether config.json would be changed, without writing it.
.OUTPUTS
    None
#>
function Update-ProfileConfig {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
        Justification = 'profile.ps1 sets PSProfileRoot so functions in other files can find the install.')]
    param()

    # Show informational messages unless the caller chose otherwise with -InformationAction.
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { $InformationPreference = 'Continue' }

    $installPath = $Global:PSProfileRoot
    if (-not $installPath -or -not (Test-Path -Path $installPath)) {
        Write-Error 'Could not determine the PSProfile install directory ($Global:PSProfileRoot is unset).'
        return
    }

    $samplePath = Join-Path $installPath 'assets/config/sample-config.json'
    $configPath = Join-Path $installPath 'assets/config/config.json'
    $objectType = [System.Management.Automation.PSCustomObject]

    function ConvertTo-ConfigJson {
        <#
        .SYNOPSIS
            Writes JSON with four-space indents, the same way on 5.1 and 7, matching the layout of
            sample-config.json. ConvertTo-Json formats differently on each version.
        #>
        param($Value, [int]$Depth = 0)

        $indent = '    ' * ($Depth + 1)
        $closeIndent = '    ' * $Depth
        $newLine = [Environment]::NewLine

        if ($null -eq $Value) { return 'null' }
        if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
        if ($Value -is [string]) {
            $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
            $escaped = $escaped.Replace("`n", '\n').Replace("`r", '\r').Replace("`t", '\t')
            $escaped = [regex]::Replace($escaped, '[\x00-\x1f]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
            return '"' + $escaped + '"'
        }
        if ($Value -is [System.Collections.IList]) {
            if ($Value.Count -eq 0) { return '[]' }
            $items = foreach ($item in $Value) { $indent + (ConvertTo-ConfigJson -Value $item -Depth ($Depth + 1)) }
            return '[' + $newLine + ($items -join (',' + $newLine)) + $newLine + $closeIndent + ']'
        }
        if ($Value -is $objectType) {
            $properties = @($Value.PSObject.Properties)
            if ($properties.Count -eq 0) { return '{}' }
            $members = foreach ($property in $properties) {
                $memberValue = ConvertTo-ConfigJson -Value $property.Value -Depth ($Depth + 1)
                $indent + (ConvertTo-ConfigJson -Value $property.Name) + ': ' + $memberValue
            }
            return '{' + $newLine + ($members -join (',' + $newLine)) + $newLine + $closeIndent + '}'
        }
        return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    }

    function Test-ConfigValueEqual {
        <#
        .SYNOPSIS
            Tests whether two config values are the same, by comparing their JSON.
        #>
        param($First, $Second)
        (ConvertTo-ConfigJson -Value $First) -ceq (ConvertTo-ConfigJson -Value $Second)
    }

    function Get-ConfigVersion {
        <#
        .SYNOPSIS
            Returns a config's "version" as a [version], or $null if it's missing or not a version.
        #>
        param($Config)
        $property = $Config.PSObject.Properties['version']
        $parsed = $null
        if ($property -and [version]::TryParse([string]$property.Value, [ref]$parsed)) { return $parsed }
        return $null
    }

    function Get-EntryKey {
        <#
        .SYNOPSIS
            Identifies a list entry: Name (plus Source, for Packages) for objects, the JSON otherwise.
        #>
        param($Entry)
        if ($Entry -is $objectType -and $Entry.PSObject.Properties['Name']) {
            $key = [string]$Entry.Name
            if ($Entry.PSObject.Properties['Source']) { $key += '|' + [string]$Entry.Source }
            return $key
        }
        return ConvertTo-ConfigJson -Value $Entry
    }

    function Get-ConfigLeaf {
        <#
        .SYNOPSIS
            Flattens a config into a table of paths and JSON values, one per setting and list entry.
        #>
        param($Value, [string]$Path)

        $leaves = @{}
        if ($Value -is $objectType) {
            foreach ($property in $Value.PSObject.Properties) {
                $childLeaves = Get-ConfigLeaf -Value $property.Value -Path "$Path.$($property.Name)"
                foreach ($key in $childLeaves.Keys) { $leaves[$key] = $childLeaves[$key] }
            }
        } elseif ($Value -is [System.Collections.IList]) {
            foreach ($entry in $Value) {
                $leaves["$Path[$(Get-EntryKey -Entry $entry)]"] = ConvertTo-ConfigJson -Value $entry
            }
        } else {
            $leaves[$Path] = ConvertTo-ConfigJson -Value $Value
        }
        return $leaves
    }

    function Merge-ConfigList {
        <#
        .SYNOPSIS
            Merges a list such as Modules: adds new sample entries and updates or removes the ones the
            user never changed.
        #>
        param($Base, $Sample, $Current, [string]$Path)

        # Without the old sample there's no telling a new entry from one the user removed.
        if ($null -eq $Base) { return , $Current }

        $baseByKey = @{}
        foreach ($entry in $Base) { $baseByKey[(Get-EntryKey -Entry $entry)] = $entry }
        $sampleByKey = @{}
        foreach ($entry in $Sample) { $sampleByKey[(Get-EntryKey -Entry $entry)] = $entry }

        $result = New-Object -TypeName System.Collections.Generic.List[object]
        $currentKeys = @{}
        foreach ($entry in $Current) {
            $key = Get-EntryKey -Entry $entry
            $currentKeys[$key] = $true
            $unchanged = $baseByKey.ContainsKey($key) -and (Test-ConfigValueEqual $entry $baseByKey[$key])
            if ($unchanged -and -not $sampleByKey.ContainsKey($key)) {
                $changes.Add("removed $Path entry $key")
            } elseif ($unchanged -and -not (Test-ConfigValueEqual $entry $sampleByKey[$key])) {
                $result.Add($sampleByKey[$key])
                $changes.Add("updated $Path entry $key")
            } else {
                $result.Add($entry)
            }
        }
        foreach ($entry in $Sample) {
            $key = Get-EntryKey -Entry $entry
            if (-not $baseByKey.ContainsKey($key) -and -not $currentKeys.ContainsKey($key)) {
                $result.Add($entry)
                $changes.Add("added $Path entry $key")
            }
        }
        return , $result.ToArray()
    }

    function Merge-ConfigObject {
        <#
        .SYNOPSIS
            Three-way merge: $Base is the sample config.json was made from ($null if unknown),
            $Sample is the current sample, and $Current is the user's config.json.
        #>
        param($Base, $Sample, $Current, [string]$Path)

        $merged = [ordered]@{}
        foreach ($property in $Sample.PSObject.Properties) {
            $name = $property.Name
            # The version is set once the merge is done.
            if (-not $Path -and $name -eq 'version') {
                $merged[$name] = $property.Value
                continue
            }
            $childPath = if ($Path) { "$Path.$name" } else { $name }
            $baseProperty = if ($null -ne $Base) { $Base.PSObject.Properties[$name] } else { $null }
            $currentProperty = $Current.PSObject.Properties[$name]

            if (-not $currentProperty) {
                # Missing from config.json: new in the sample, or removed by the user on purpose.
                if (-not $baseProperty) {
                    $merged[$name] = $property.Value
                    $changes.Add("added $childPath")
                }
                continue
            }

            # Plain assignments, because `if` used as an expression unrolls a one-item array.
            $baseValue = $null
            if ($baseProperty) { $baseValue = $baseProperty.Value }
            $sampleValue = $property.Value
            $currentValue = $currentProperty.Value
            if ($sampleValue -is $objectType -and $currentValue -is $objectType) {
                $childBase = $null
                if ($baseValue -is $objectType) { $childBase = $baseValue }
                $merged[$name] = Merge-ConfigObject -Base $childBase -Sample $sampleValue -Current $currentValue `
                    -Path $childPath
            } elseif ($sampleValue -is [System.Collections.IList] -and $currentValue -is [System.Collections.IList]) {
                $childBase = $null
                if ($baseValue -is [System.Collections.IList]) { $childBase = $baseValue }
                $merged[$name] = Merge-ConfigList -Base $childBase -Sample $sampleValue -Current $currentValue `
                    -Path $childPath
            } elseif ($baseProperty -and (Test-ConfigValueEqual $currentValue $baseValue) -and
                -not (Test-ConfigValueEqual $currentValue $sampleValue)) {
                $merged[$name] = $sampleValue
                $changes.Add("updated $childPath")
            } else {
                $merged[$name] = $currentValue
            }
        }

        foreach ($property in $Current.PSObject.Properties) {
            $name = $property.Name
            if ($Sample.PSObject.Properties[$name]) { continue }
            $childPath = if ($Path) { "$Path.$name" } else { $name }
            $baseProperty = if ($null -ne $Base) { $Base.PSObject.Properties[$name] } else { $null }
            if ($baseProperty -and (Test-ConfigValueEqual $property.Value $baseProperty.Value)) {
                $changes.Add("removed $childPath")
            } else {
                $merged[$name] = $property.Value
            }
        }

        return [PSCustomObject]$merged
    }

    if (-not (Test-Path -Path $samplePath)) {
        Write-Error "sample-config.json not found at $samplePath."
        return
    }

    try {
        $sample = Get-Content -Path $samplePath -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Failed to read $samplePath`: $_"
        return
    }
    $sampleVersion = Get-ConfigVersion -Config $sample

    if (-not (Test-Path -Path $configPath)) {
        if ($PSCmdlet.ShouldProcess($configPath, 'Create from sample-config.json')) {
            Copy-Item -Path $samplePath -Destination $configPath
            Write-Information -MessageData "Created $configPath from sample-config.json."
        }
        return
    }

    try {
        $current = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Failed to read $configPath, so it was left unchanged: $_"
        return
    }
    $currentVersion = Get-ConfigVersion -Config $current

    if ($null -ne $currentVersion -and $null -ne $sampleVersion -and $currentVersion -ge $sampleVersion) {
        Write-Verbose "config.json is already at version $currentVersion."
        return
    }

    # Find the sample config.json was made from, so the user's own changes can be told apart.
    $base = $null
    $gitCommand = Get-Command -Name git -ErrorAction SilentlyContinue
    $hasGit = $gitCommand -and (Test-Path -Path (Join-Path $installPath '.git'))
    if ($null -ne $currentVersion -and $hasGit) {
        # When several samples share the version, use the one with the most values in common with
        # config.json. Newer samples come first, so they win a tie.
        $currentLeaves = Get-ConfigLeaf -Value $current -Path ''
        $bestScore = -1
        $commits = @(git -C $installPath log --format=%H -- assets/config/sample-config.json 2>$null)
        foreach ($commit in $commits) {
            $text = git -C $installPath show "${commit}:assets/config/sample-config.json" 2>$null
            if ($LASTEXITCODE -ne 0) { continue }
            try {
                $candidate = ($text -join "`n") | ConvertFrom-Json
            } catch {
                Write-Debug "Skipping sample-config.json at $commit, which isn't valid JSON: $_"
                continue
            }
            if ((Get-ConfigVersion -Config $candidate) -ne $currentVersion) { continue }

            $candidateLeaves = Get-ConfigLeaf -Value $candidate -Path ''
            $score = 0
            foreach ($key in $candidateLeaves.Keys) {
                if ($currentLeaves.ContainsKey($key) -and $currentLeaves[$key] -ceq $candidateLeaves[$key]) { $score++ }
            }
            if ($score -gt $bestScore) {
                $base = $candidate
                $bestScore = $score
            }
        }
    }
    if ($null -eq $base) {
        Write-Verbose ('No sample-config.json matching config.json''s version was found, so only missing ' +
            'settings will be added.')
    }

    $changes = New-Object -TypeName System.Collections.Generic.List[string]
    $merged = Merge-ConfigObject -Base $base -Sample $sample -Current $current -Path ''
    if ($merged.PSObject.Properties['version']) {
        $merged.version = $sample.version
    } else {
        $merged | Add-Member -MemberType NoteProperty -Name version -Value $sample.version
    }

    if (-not $PSCmdlet.ShouldProcess($configPath, "Update to version $($sample.version)")) { return }

    $backupPath = '{0}.bak-{1}' -f $configPath, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -Path $configPath -Destination $backupPath
    $json = (ConvertTo-ConfigJson -Value $merged) + [Environment]::NewLine
    [IO.File]::WriteAllText($configPath, $json, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))

    Write-Information -MessageData "Updated config.json to version $($sample.version). Backup: $backupPath"
    foreach ($change in $changes) { Write-Information -MessageData "  $change" }
}
