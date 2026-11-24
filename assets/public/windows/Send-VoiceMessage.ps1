function Send-VoiceMessage {
    <#
    .SYNOPSIS
        Send a message through Text to Speech
    .DESCRIPTION
        Uses PowerShell to send a message using Text to Speech
    .PARAMETER ComputerName
        Specifies the computer to perform this action on.

        Default Value: $env:ComputerName
    .PARAMETER Message
        Specifies the message to be read out.
    .PARAMETER Credential
        Specifies whether you are going to pass a credential object or not.

        Switch (passing it implies $true)
    .PARAMETER CredentialObject
        Accepts a PSCredential Object.
    .EXAMPLE
        C:\PS>Send-VoiceMessage -Message 'Hello World'
        Will speak "Hello World" on the local computer
    .EXAMPLE
        C:\PS>Send-VoiceMessage -ComputerName test01 -Message 'Hello World' -Credential -CredentialObject (Get-Credential)
        Will speak the message "Hello World" on the computer test01 using the credential you pass to get-credential
    .NOTES
        Author: reave (https://github.com/reave)
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$ComputerName = $env:ComputerName,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [switch]$Credential,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$CredentialObject
    )
    begin {
        if ($Credential) {
            if (!($CredentialObject)) {
                $CredentialObject = (Get-Credential -Message "Please enter your credentials.")

                if (!($CredentialObject -is [System.Management.Automation.PSCredential])) {
                    throw "Failed to create credential object."
                }
            } else {
                if (!($CredentialObject -is [System.Management.Automation.PSCredential])) {
                    throw "Failed to create credential object."
                }
            }

        }
    }
    process {
        if ($ComputerName -eq $env:ComputerName) {
            if (!$Message) {
                $Message = Read-Host 'Enter a Message'
            }

            [Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
            $object = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $object.Speak($Message)
        } else {
            if ($CredentialObject) {
                $Session = New-PSSession -ComputerName $ComputerName -Credential $CredentialObject
            }

            $Session = New-PSSession -ComputerName $ComputerName

            if (!$Message) {
                Invoke-Command -Session $Session {
                    $Message = Read-Host 'Enter Text'

                    [Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
                    $object = New-Object System.Speech.Synthesis.SpeechSynthesizer
                    $object.Speak($Message)
                }
            } else {
                Invoke-Command -Session $Session -ArgumentList $Message {
                    param($Text)
                    [Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
                    $object = New-Object System.Speech.Synthesis.SpeechSynthesizer
                    $object.Speak($Text)
                }
            }
        }
    }
}
