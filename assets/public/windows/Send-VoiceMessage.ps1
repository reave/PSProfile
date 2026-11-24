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
        Specifies a user account that has permission to connect to the remote computer. If you omit
        it, the command connects as the current user.
    .EXAMPLE
        C:\PS>Send-VoiceMessage -Message 'Hello World'
        Will speak "Hello World" on the local computer
    .EXAMPLE
        C:\PS>Send-VoiceMessage -ComputerName test01 -Message 'Hello World' -Credential (Get-Credential)
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
        [System.Management.Automation.PSCredential]$Credential
    )
    process {
        if ($ComputerName -eq $env:ComputerName) {
            if (!$Message) {
                $Message = Read-Host 'Enter a Message'
            }

            [Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
            $object = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $object.Speak($Message)
        } else {
            $sessionParams = @{
                ComputerName = $ComputerName
            }
            if ($Credential) {
                $sessionParams.Credential = $Credential
            }
            $Session = New-PSSession @sessionParams

            if (!$Message) {
                Invoke-Command -Session $Session {
                    $Message = Read-Host 'Enter Text'

                    [Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
                    $object = New-Object System.Speech.Synthesis.SpeechSynthesizer
                    $object.Speak($Message)
                }
            } else {
                Invoke-Command -Session $Session {
                    [Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
                    $object = New-Object System.Speech.Synthesis.SpeechSynthesizer
                    $object.Speak($using:Message)
                }
            }
        }
    }
}
