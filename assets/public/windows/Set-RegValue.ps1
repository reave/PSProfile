function Set-RegValue {
    <#
        .SYNOPSIS
        Create or Modify a specific registry key or value

        .DESCRIPTION

        Explain me better here
        .PARAMETER RegHive

        Determines the registry hive to make changes in.
        Validated Set: 'HKEY_LOCAL_MACHINE', 'HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER', 'HKEY_USERS'
        .PARAMETER RegKey

        Determines the path of the key to create or modify
        .PARAMETER RegValueName

        Determines the value to create or modify
        .PARAMETER RegValueType

        Determines the type of value to create or change
        Validated Set: 'Binary', 'Dword', 'ExpandString', 'MultiString', 'Qword', 'String'
        .PARAMETER RegValueData

        Determines the data to input into the value
        .NOTES

        Co-Author: reave (https://github.com/reave)
        Co-Author: Christopher Kitchen

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True)]
        [ValidateSet('HKEY_LOCAL_MACHINE', 'HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER', 'HKEY_USERS')]
        [string]$RegHive,
        [Parameter(Mandatory = $True)]
        [string]$RegKey,
        [Parameter(Mandatory = $false)]
        [string]$RegValueName,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Binary', 'Dword', 'ExpandString', 'MultiString', 'Qword', 'String')]
        [string]$RegValueType = 'String',
        [Parameter(Mandatory = $false)]
        [string]$RegValueData
    )

    begin {
        function Write-RegLog {
            <#
            .SYNOPSIS
                Writes one timestamped log line for Set-RegValue.

            .DESCRIPTION
                Outputs "<timestamp> :: <Level> :: <Message>", the format every Set-RegValue message uses.

            .PARAMETER Level
                The message level, such as INFO, WARNING or ERROR.

            .PARAMETER Message
                The message text.

            .EXAMPLE
                Write-RegLog -Level INFO -Message 'Checking that the key exists.'

                Outputs the message with the current time and the INFO level.
            #>
            param([string]$Level, [string]$Message)
            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: $Level :: $Message"
        }
        switch ($RegHive) {
            'HKEY_LOCAL_MACHINE' {
                $RegPath = "HKLM:\$($RegKey)"
            }
            'HKEY_CLASSES_ROOT' {
                $RegPath = "HKCR:\$($RegKey)"
            }
            'HKEY_CURRENT_USER' {
                $RegPath = "HKCU:\$($RegKey)"
            }
            'HKEY_USERS' {
                $RegPath = "HKU:\$($RegKey)"
            }
        }

        Write-Output ''
    }
    process {
        if (-not $PSCmdlet.ShouldProcess(
                "$RegPath\$RegValueName",
                "Set registry value to '$RegValueData' ($RegValueType)")) { return }

        Write-RegLog -Level INFO -Message "Checking that $RegPath exists."

        if (Get-Item -Path $RegPath -ErrorAction SilentlyContinue) {
            Write-RegLog -Level INFO -Message "$RegPath exists and is readable."

            if ($RegValueName) {
                Write-RegLog -Level INFO -Message "Checking that $RegValueName exists in $RegPath."
                if (Get-ItemProperty -Path $RegPath -Name $RegValueName -ErrorAction SilentlyContinue) {
                    Write-RegLog -Level INFO -Message "$RegValueName exists in $RegPath."

                    if ($RegValueType) {
                        Write-RegLog -Level INFO -Message "Checking registry data type of $RegValueName."
                        $CurrentRegValueType = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
                        $TestRegType = $CurrentRegValueType.GetValueKind("$($RegValueName)")

                        if ($RegValueType -eq $TestRegType) {
                            Write-RegLog -Level INFO -Message "$RegValueName is already set to $RegValueType"
                        } else {
                            $logParams = @{
                                Level = 'INFO'
                                Message = "Registry Type is currently $TestRegType, not $RegValueType."
                            }
                            Write-RegLog @logParams

                            Write-RegLog -Level INFO -Message "Updating Registry Value Type to $RegValueType."

                            try {
                                $removeParams = @{
                                    Path = $RegPath
                                    Name = $RegValueName
                                    Force = $true
                                    ErrorAction = 'SilentlyContinue'
                                }
                                Remove-ItemProperty @removeParams | Out-Null
                                $newPropertyParams = @{
                                    Path = $RegPath
                                    Name = $RegValueName
                                    Type = $RegValueType
                                    Force = $true
                                    ErrorAction = 'SilentlyContinue'
                                }
                                New-ItemProperty @newPropertyParams | Out-Null
                            } catch {
                                Write-RegLog -Level ERROR -Message "Failed to Set Registry Value Type of $RegValueType."
                            }

                        }

                    }

                    if ($RegValueData) {
                        Write-RegLog -Level INFO -Message "Checking that $RegValueName has the correct value."

                        $propertyParams = @{
                            Path = $RegPath
                            ErrorAction = 'SilentlyContinue'
                        }
                        if ((Get-ItemProperty @propertyParams).$($RegValueName) -eq $RegValueData) {
                            $logParams = @{
                                Level = 'INFO'
                                Message = "$RegValueName is already at the passed value of $RegValueData."
                            }
                            Write-RegLog @logParams
                        } else {
                            $logParams = @{
                                Level = 'WARNING'
                                Message = ("$RegValueName is not currently set to the passed value of $RegValueData. " +
                                    "Current Value is $((Get-ItemProperty @propertyParams).$($RegValueName))")
                            }
                            Write-RegLog @logParams

                            $logParams = @{
                                Level = 'INFO'
                                Message = "Setting New Registry Value Data of $RegValueName to $RegValueData"
                            }
                            Write-RegLog @logParams

                            try {
                                Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                            } catch {
                                $logParams = @{
                                    Level = 'ERROR'
                                    Message = "Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                                }
                                Write-RegLog @logParams
                            }
                        }
                    } else {
                        $logParams = @{
                            Level = 'INFO'
                            Message = "No Reg Value Data was passed. Will erase the currently set data from the value."
                        }
                        Write-RegLog @logParams

                        $logParams = @{
                            Level = 'INFO'
                            Message = "Setting New Registry Value Data of $RegValueName to $RegValueData"
                        }
                        Write-RegLog @logParams

                        try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        } catch {
                            $logParams = @{
                                Level = 'ERROR'
                                Message = "Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                            }
                            Write-RegLog @logParams
                        }
                    }
                } else {
                    Write-RegLog -Level WARNING -Message "Cannot find $RegValueName in $RegPath."

                    Write-RegLog -Level INFO -Message "Setting New Registry value $RegValueName at $RegPath"

                    try {
                        Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                    } catch {
                        Write-RegLog -Level ERROR -Message "Failed to create Registry value $RegValueName at $RegPath "
                    }

                    if ($RegValueType) {
                        Write-RegLog -Level INFO -Message "Checking registry data type of $RegValueName."
                        $CurrentRegValueType = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
                        $TestRegType = $CurrentRegValueType.GetValueKind("$($RegValueName)")

                        if ($RegValueType -eq $TestRegType) {
                            Write-RegLog -Level INFO -Message "$RegValueName is already set to $RegValueType"
                        } else {
                            $logParams = @{
                                Level = 'INFO'
                                Message = "Registry Type is currently $TestRegType, not $RegValueType."
                            }
                            Write-RegLog @logParams

                            Write-RegLog -Level INFO -Message "Updating Registry Value Type to $RegValueType."

                            try {
                                $removeParams = @{
                                    Path = $RegPath
                                    Name = $RegValueName
                                    Force = $true
                                    ErrorAction = 'SilentlyContinue'
                                }
                                Remove-ItemProperty @removeParams | Out-Null
                                $newPropertyParams = @{
                                    Path = $RegPath
                                    Name = $RegValueName
                                    Type = $RegValueType
                                    Force = $true
                                    ErrorAction = 'SilentlyContinue'
                                }
                                New-ItemProperty @newPropertyParams | Out-Null
                            } catch {
                                Write-RegLog -Level ERROR -Message "Failed to Set Registry Value Type of $RegValueType."
                            }

                        }

                    }

                    if ($RegValueData) {
                        $logParams = @{
                            Level = 'INFO'
                            Message = "Setting Registry value Data of $RegValueName to $RegValueData"
                        }
                        Write-RegLog @logParams

                        try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        } catch {
                            $logParams = @{
                                Level = 'ERROR'
                                Message = "Failed to Set Registry value Data of $RegValueName to $RegValueData."
                            }
                            Write-RegLog @logParams
                        }

                    } else {
                        $logParams = @{
                            Level = 'INFO'
                            Message = "No Reg Value Data was passed. Will erase the currently set data from the value."
                        }
                        Write-RegLog @logParams

                        $logParams = @{
                            Level = 'INFO'
                            Message = "Setting New Registry Value Data of $RegValueName to $RegValueData"
                        }
                        Write-RegLog @logParams

                        try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        } catch {
                            $logParams = @{
                                Level = 'ERROR'
                                Message = "Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                            }
                            Write-RegLog @logParams
                        }
                    }
                }
            }

        }

        else {
            # Write RegPath if Registry path does not exist.
            Write-RegLog -Level WARNING -Message "Cannot find $RegPath."

            Write-RegLog -Level INFO -Message "Creating $RegPath"
            try {
                New-Item -Path $RegPath -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {
                Write-RegLog -Level ERROR -Message " Failed to create $RegPath"
            }

            if ($RegValueName) {
                $logParams = @{
                    Level = 'INFO'
                    Message = "Creating Registry Value $($RegValueName) with type of $($RegValueType)."
                }
                Write-RegLog @logParams

                try {
                    $newPropertyParams = @{
                        Path = $RegPath
                        Name = $RegValueName
                        Type = $RegValueType
                        Force = $true
                        ErrorAction = 'SilentlyContinue'
                    }
                    New-ItemProperty @newPropertyParams | Out-Null
                } catch {
                    $logParams = @{
                        Level = 'ERROR'
                        Message = "Failed to Set Registry Value $($RegValueName) with type of $($RegValueType)."
                    }
                    Write-RegLog @logParams
                }
            }

            if ($RegValueData) {
                Write-RegLog -Level INFO -Message "Setting Registry value Data of $RegValueName to $RegValueData"

                try {
                    Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                } catch {
                    $logParams = @{
                        Level = 'ERROR'
                        Message = "Failed to Set Registry value Data of $RegValueName to $RegValueData."
                    }
                    Write-RegLog @logParams
                }
            } else {
                $logParams = @{
                    Level = 'INFO'
                    Message = "No Reg Value Data was passed. Will erase the currently set data from the value."
                }
                Write-RegLog @logParams

                Write-RegLog -Level INFO -Message "Setting New Registry Value Data of $RegValueName to $RegValueData"

                try {
                    Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                } catch {
                    $logParams = @{
                        Level = 'ERROR'
                        Message = "Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                    }
                    Write-RegLog @logParams
                }
            }
        }
    }
    end {
        Write-RegLog -Level INFO -Message "Ending Script Execution."
    }
}
