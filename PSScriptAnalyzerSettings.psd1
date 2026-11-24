# PSScriptAnalyzer settings for PSProfile. See STYLE.md for the rules these enforce.
# Requires PSScriptAnalyzer 1.25 or later. The VS Code PowerShell extension loads this
# file automatically from the workspace root.
@{
    Severity     = @('Error', 'Warning', 'Information')

    # Every built-in rule runs except these.
    ExcludeRules = @(
        # Aligning '=' in hashtables adds whitespace churn to every edit near it.
        'PSAlignAssignmentStatement'
        # Would flag most existing strings; single quotes are a review-time preference.
        'PSAvoidUsingDoubleQuotesForConstantString'
        # PSProfile is not a module and has no manifest.
        'PSMissingModuleManifestField'
        'PSUseToExportFieldsInManifest'
        'PSAvoidUsingDeprecatedManifestFields'
        # DSC and constrained-language checks don't apply to a user profile.
        'PSDSC*'
        'PSUseConstrainedLanguageMode'
    )

    Rules        = @{
        # Layout: One True Brace Style, 4-space indent.
        PSPlaceOpenBrace                          = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace                         = @{
            Enable             = $true
            # $false keeps '} else {' and '} catch {' on one line.
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation                = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace                 = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSAvoidLongLines                          = @{
            Enable            = $true
            MaximumLineLength = 120
        }

        PSAvoidSemicolonsAsLineTerminators        = @{
            Enable = $true
        }

        PSAvoidTrailingWhitespace                 = @{
            Enable = $true
        }

        PSUseCorrectCasing                        = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $true
            CheckOperator = $true
        }

        # Help inside the function, as a block comment, on every function.
        PSProvideCommentHelp                      = @{
            Enable                  = $true
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $true
            Placement               = 'begin'
        }

        # Write-Host is allowed for the profile's banners and Show-* functions;
        # suppress it per function with a justification there.
        PSAvoidUsingWriteHost                     = @{
            Enable = $true
        }

        # Runtime compatibility: profile.ps1, setup.ps1 and the windows/ folders run on
        # Windows PowerShell 5.1 and PowerShell 7. STYLE.md shows how to add the Linux
        # profile when checking the cross-platform copies.
        PSUseCompatibleSyntax                     = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }

        PSUseCompatibleCommands                   = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'
            )
        }

        PSUseCompatibleTypes                      = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'
            )
        }
    }
}
