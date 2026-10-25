function Get-PSProfileSecret {
    <#
    .SYNOPSIS
        Looks up a named secret (e.g. an API key) for a profile function, at call time.
    .DESCRIPTION
        Resolves a secret only when a function asks for it, never at shell startup, so
        keys stay out of config files and nothing is unlocked until it is needed.

        Where it looks is set by settings.Secrets.<Name> in the merged config:
          - "op://vault/item/field"   read with the 1Password CLI (op read).
          - "SomeSecretName"          that secret in SecretManagement.
          - { "Name": ..., "Vault": ... }  that secret in that SecretManagement vault.
        A name with no entry is looked up in SecretManagement under the same name, in
        settings.SecretVault if set, otherwise the registered default vault.

        Needs Microsoft.PowerShell.SecretManagement plus a vault (e.g.
        Microsoft.PowerShell.SecretStore), or the op CLI for op:// references. Neither is
        installed for you. Returns nothing, with a verbose message, when the secret or the
        tool to read it isn't available, so callers decide how to fail.
    .PARAMETER Name
        The secret's name, as functions ask for it (e.g. OpenWeatherMapApiKey).
    .EXAMPLE
        Set-Secret -Name OpenWeatherMapApiKey -Secret 'your-key'
        Get-PSProfileSecret -Name OpenWeatherMapApiKey

        Stores the key once in your default SecretManagement vault, then reads it back.
    .EXAMPLE
        "Secrets": { "OpenWeatherMapApiKey": "op://Personal/OpenWeatherMap/credential" }

        In config.json: reads the key from 1Password instead.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $settings = Get-Variable -Name PSProfileSettings -Scope Global -ValueOnly -ErrorAction Ignore
    $entry = if ($settings -and $settings.Secrets) { $settings.Secrets.$Name }
    $secretName = $Name
    $vault = if ($settings) { $settings.SecretVault }

    if ($entry -is [string] -and $entry -like 'op://*') {
        if (-not (Get-Command -Name op -CommandType Application -ErrorAction Ignore)) {
            Write-Verbose "Secret $Name points at 1Password ($entry), but the op CLI isn't installed."
            return
        }
        $value = & op read $entry 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $value) {
            Write-Verbose "op read $entry failed (exit code $LASTEXITCODE). Run 'op signin' and retry."
            return
        }
        return ($value -join "`n").TrimEnd("`r", "`n")
    }
    if ($entry -is [string] -and $entry) { $secretName = $entry }
    elseif ($entry -and $entry.Name) {
        $secretName = $entry.Name
        if ($entry.Vault) { $vault = $entry.Vault }
    }

    if (-not (Get-Command -Name Get-Secret -ErrorAction Ignore)) {
        Write-Verbose "Secret $Name needs Microsoft.PowerShell.SecretManagement, which isn't installed. Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore"
        return
    }
    $getSecret = @{ Name = $secretName; AsPlainText = $true; ErrorAction = 'Stop' }
    if ($vault) { $getSecret.Vault = $vault }
    try { Get-Secret @getSecret }
    catch { Write-Verbose "Secret $secretName not found$(if ($vault) { " in vault $vault" }): $($_.Exception.Message)" }
}
