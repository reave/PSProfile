function ConvertTo-NatoAlphabet {
    <#
    .SYNOPSIS
    This script is designed to take input and conver to NATO phoneic spelling.

    .DESCRIPTION
    This script is designed to take input from the user and convert it to the NATO phonetic spelling.

    .PARAMETER InputParameter
    The string(s) to convert to NATO phonetic alphabet.

    .PARAMETER TextToSpeech
    If this switch is used the script will use text to speech to say the input string and the NATO phonetic spelling.

    .EXAMPLE
    ConvertTo-NatoAlphabet -InputParameter "example"
    This will convert the word "example" to the NATO phonetic spelling.

    Output:
    Word    NATO Phonetic Spelling
    ----    ----------------------
    example Echo -> X-ray -> Alpha -> Mike -> Papa -> Lima -> Echo

    .EXAMPLE
    "example" | ConvertTo-NatoAlphabet
    This will convert the word "example" to the NATO phonetic spelling.
    Output:
    Word    NATO Phonetic Spelling
    ----    ----------------------
    example Echo -> X-ray -> Alpha -> Mike -> Papa -> Lima -> Echo

    .EXAMPLE
    ConvertTo-NatoAlphabet -InputParameter "example" -TextToSpeech
    This will convert the word "example" to the NATO phonetic spelling and use text to speech to say the input string and the NATO phonetic spelling.
    Output:
    Word    NATO Phonetic Spelling
    ----    ----------------------
    example Echo -> X-ray -> Alpha -> Mike -> Papa -> Lima -> Echo

    .INPUTS
    String[]

    .OUTPUTS
    PSObject with properties Word and NATO Phonetic Spelling

    .NOTES
    Author: Joseph Ascanio
    Date: 2025.10.04
    Version: 1.2.0.0000
    #>
    [CmdletBinding()]
    param (
        # Input strings to convert to NATO phonetic alphabet
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$InputStrings,
        # Switch to enable text to speech
        [Parameter(Mandatory = $false)]
        [switch]$TextToSpeech
    )
    begin {
        if ($TextToSpeech) {
            Try {
                # Load the System.Speech assembly
                Add-Type -AssemblyName System.Speech -ErrorAction Stop

                # Create a speech synthesizer object
                $Speech = New-Object System.Speech.Synthesis.SpeechSynthesizer

                # Set the voice to use (optional)
                $voice = $Speech.GetInstalledVoices() | Select-Object -ExpandProperty VoiceInfo | Where-Object { $_.Name -like "*Zira*" }
                if ($voice) {
                    Write-Verbose "Using voice: $($voice.Name)"
                    $Speech.SelectVoice($voice.Name)
                }
                else {
                    Write-Verbose "Zira voice not found, using default voice"
                }

                Write-Verbose "Text to Speech is enabled"
            }
            Catch {
                Write-Warning "Failed to initialize Text to Speech. Disabling Text to Speech."
                $TextToSpeech = $false
            }
        }

        $natoAlphabet = @{
            'A' = 'Alpha'
            'B' = 'Bravo'
            'C' = 'Charlie'
            'D' = 'Delta'
            'E' = 'Echo'
            'F' = 'Foxtrot'
            'G' = 'Golf'
            'H' = 'Hotel'
            'I' = 'India'
            'J' = 'Juliet'
            'K' = 'Kilo'
            'L' = 'Lima'
            'M' = 'Mike'
            'N' = 'November'
            'O' = 'Oscar'
            'P' = 'Papa'
            'Q' = 'Quebec'
            'R' = 'Romeo'
            'S' = 'Sierra'
            'T' = 'Tango'
            'U' = 'Uniform'
            'V' = 'Victor'
            'W' = 'Whiskey'
            'X' = 'X-ray'
            'Y' = 'Yankee'
            'Z' = 'Zulu'
        }
    }

    process {
        foreach ($inputString in $InputStrings) {
            Write-Verbose "Processing input string: $inputString"

            # create a new hashtable to store properties for output object
            Write-Verbose "Creating output object"
            $outputObject = New-Object PSObject

            # create an array variable to store the nato alphabet for each letter
            Write-Verbose "Creating nato alphabet array"
            $natoAlphabetArray = @()

            $inputString.ToCharArray() | ForEach-Object {
                Write-Verbose "Processing character: $_"
                if ($natoAlphabet.ContainsKey($_.ToString().ToUpper())) {
                    Write-Verbose "Adding nato alphabet for character: $_"
                    # add the nato alphabet for the letter to the array
                    $natoAlphabetArray += $natoAlphabet[$_.ToString().ToUpper()]
                }
                else {
                    Write-Verbose "Skipping character: $_"
                    $_
                }
            }

            # add the input string to the output object
            Write-Verbose "Adding input string to output object"
            $outputObject | Add-Member -MemberType NoteProperty -Name 'Word' -Value $inputString

            # add the nato alphabet array to the output object
            Write-Verbose "Adding nato alphabet array to output object"
            $outputObject | Add-Member -MemberType NoteProperty -Name 'NATO Phonetic Spelling' -Value ($natoAlphabetArray -join ' -> ')

            if ($TextToSpeech) {
                Write-Verbose "Speaking the input string $inputString"
                $Speech.Speak($inputString)
                Write-Verbose "Speaking the NATO phonetic spelling $natoAlphabetArray"
                $Speech.Speak($natoAlphabetArray -join ' ')
            }

            Write-Verbose "Outputting object"
            $outputObject
        }
    }
    End {
        if ($TextToSpeech) {
            Write-Verbose "Disposing of Speech Synthesizer"
            $Speech.Dispose()
        }
    }
}
