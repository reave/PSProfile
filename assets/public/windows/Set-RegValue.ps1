Function Set-RegValue {
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

        Co-Author: Joseph Ascanio
        Co-Author: Christopher Kitchen

    #>
    [CmdletBinding()]
    Param(
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

    Begin {
        Switch ($RegHive) {
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
    Process {
        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking that $RegPath exists."

        If (Get-Item -Path $RegPath -ErrorAction SilentlyContinue) {
            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegPath exists and is readable."

            If ($RegValueName) {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking that $RegValueName exists in $RegPath."
                If (Get-ItemProperty -Path $RegPath -Name $RegValueName -ErrorAction SilentlyContinue) {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName exists in $RegPath."

                    If ($RegValueType) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking registry data type of $RegValueName."
                        $CurrentRegValueType = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
                        $TestRegType = $CurrentRegValueType.GetValueKind("$($RegValueName)")

                        If ($RegValueType -eq $TestRegType) {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName is already set to $RegValueType"
                        }
                        Else {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Registry Type is currently $TestRegType, not $RegValueType."

                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Updating Registry Value Type to $RegValueType."

                            Try {
                                Remove-ItemProperty -Path $RegPath -Name $RegValueName -Force -ErrorAction SilentlyContinue | Out-Null
                                New-ItemProperty -Path $RegPath -Name $RegValueName -Type $RegValueType -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                            Catch {
                                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Type of $RegValueType."
                            }

                        }

                    }

                    If ($RegValueData) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking that $RegValueName has the correct value."

                        If ((Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue).$($RegValueName) -eq $RegValueData) {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName is already at the passed value of $RegValueData."
                        }
                        Else {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: WARNING :: $RegValueName is not currently set to the passed value of $RegValueData. Current Value is $((Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue).$($RegValueName))"

                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                            Try {
                                Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                            }
                            Catch {
                                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                            }
                        }
                    }
                    Else {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: No Reg Value Data was passed. Will erase the currently set data from the value."

                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                        Try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        }
                        Catch {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                        }
                    }
                }
                Else {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: WARNING :: Cannot find $RegValueName in $RegPath."

                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry value $RegValueName at $RegPath"

                    Try {
                        Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                    }
                    Catch {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to create Registry value $RegValueName at $RegPath "
                    }

                    If ($RegValueType) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking registry data type of $RegValueName."
                        $CurrentRegValueType = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
                        $TestRegType = $CurrentRegValueType.GetValueKind("$($RegValueName)")

                        If ($RegValueType -eq $TestRegType) {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName is already set to $RegValueType"
                        }
                        Else {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Registry Type is currently $TestRegType, not $RegValueType."

                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Updating Registry Value Type to $RegValueType."

                            Try {
                                Remove-ItemProperty -Path $RegPath -Name $RegValueName -Force -ErrorAction SilentlyContinue | Out-Null
                                New-ItemProperty -Path $RegPath -Name $RegValueName -Type $RegValueType -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                            Catch {
                                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Type of $RegValueType."
                            }

                        }

                    }

                    If ($RegValueData) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting Registry value Data of $RegValueName to $RegValueData"

                        Try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        }
                        Catch {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry value Data of $RegValueName to $RegValueData."
                        }

                    }
                    Else {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: No Reg Value Data was passed. Will erase the currently set data from the value."

                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                        Try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        }
                        Catch {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                        }
                    }
                }
            }

        }

        Else {
            # Write RegPath if Registry path does not exist.
            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: WARNING :: Cannot find $RegPath."

            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Creating $RegPath"
            Try {
                New-Item -Path $RegPath -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Catch {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR ::  Failed to create $RegPath"
            }

            If ($RegValueName) {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Creating Registry Value $($RegValueName) with type of $($RegValueType)."

                Try {
                    New-ItemProperty -Path $RegPath -Name $RegValueName -Type $RegValueType -Force -ErrorAction SilentlyContinue | Out-Null
                }
                Catch {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value $($RegValueName) with type of $($RegValueType)."
                }
            }

            If ($RegValueData) {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting Registry value Data of $RegValueName to $RegValueData"

                Try {
                    Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                }
                Catch {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry value Data of $RegValueName to $RegValueData."
                }
            }
            Else {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: No Reg Value Data was passed. Will erase the currently set data from the value."

                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                Try {
                    Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                }
                Catch {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                }
            }
        }
    }
    End {
        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Ending Script Execution."
    }
}