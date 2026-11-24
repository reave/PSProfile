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
        if (-not $PSCmdlet.ShouldProcess("$RegPath\$RegValueName", "Set registry value to '$RegValueData' ($RegValueType)")) { return }

        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking that $RegPath exists."

        if (Get-Item -Path $RegPath -ErrorAction SilentlyContinue) {
            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegPath exists and is readable."

            if ($RegValueName) {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking that $RegValueName exists in $RegPath."
                if (Get-ItemProperty -Path $RegPath -Name $RegValueName -ErrorAction SilentlyContinue) {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName exists in $RegPath."

                    if ($RegValueType) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking registry data type of $RegValueName."
                        $CurrentRegValueType = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
                        $TestRegType = $CurrentRegValueType.GetValueKind("$($RegValueName)")

                        if ($RegValueType -eq $TestRegType) {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName is already set to $RegValueType"
                        } else {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Registry Type is currently $TestRegType, not $RegValueType."

                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Updating Registry Value Type to $RegValueType."

                            try {
                                Remove-ItemProperty -Path $RegPath -Name $RegValueName -Force -ErrorAction SilentlyContinue | Out-Null
                                New-ItemProperty -Path $RegPath -Name $RegValueName -Type $RegValueType -Force -ErrorAction SilentlyContinue | Out-Null
                            } catch {
                                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Type of $RegValueType."
                            }

                        }

                    }

                    if ($RegValueData) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking that $RegValueName has the correct value."

                        if ((Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue).$($RegValueName) -eq $RegValueData) {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName is already at the passed value of $RegValueData."
                        } else {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: WARNING :: $RegValueName is not currently set to the passed value of $RegValueData. Current Value is $((Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue).$($RegValueName))"

                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                            try {
                                Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                            } catch {
                                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                            }
                        }
                    } else {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: No Reg Value Data was passed. Will erase the currently set data from the value."

                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                        try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        } catch {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                        }
                    }
                } else {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: WARNING :: Cannot find $RegValueName in $RegPath."

                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry value $RegValueName at $RegPath"

                    try {
                        Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                    } catch {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to create Registry value $RegValueName at $RegPath "
                    }

                    if ($RegValueType) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Checking registry data type of $RegValueName."
                        $CurrentRegValueType = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
                        $TestRegType = $CurrentRegValueType.GetValueKind("$($RegValueName)")

                        if ($RegValueType -eq $TestRegType) {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: $RegValueName is already set to $RegValueType"
                        } else {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Registry Type is currently $TestRegType, not $RegValueType."

                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Updating Registry Value Type to $RegValueType."

                            try {
                                Remove-ItemProperty -Path $RegPath -Name $RegValueName -Force -ErrorAction SilentlyContinue | Out-Null
                                New-ItemProperty -Path $RegPath -Name $RegValueName -Type $RegValueType -Force -ErrorAction SilentlyContinue | Out-Null
                            } catch {
                                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Type of $RegValueType."
                            }

                        }

                    }

                    if ($RegValueData) {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting Registry value Data of $RegValueName to $RegValueData"

                        try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        } catch {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry value Data of $RegValueName to $RegValueData."
                        }

                    } else {
                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: No Reg Value Data was passed. Will erase the currently set data from the value."

                        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                        try {
                            Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                        } catch {
                            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                        }
                    }
                }
            }

        }

        else {
            # Write RegPath if Registry path does not exist.
            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: WARNING :: Cannot find $RegPath."

            Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Creating $RegPath"
            try {
                New-Item -Path $RegPath -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR ::  Failed to create $RegPath"
            }

            if ($RegValueName) {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Creating Registry Value $($RegValueName) with type of $($RegValueType)."

                try {
                    New-ItemProperty -Path $RegPath -Name $RegValueName -Type $RegValueType -Force -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value $($RegValueName) with type of $($RegValueType)."
                }
            }

            if ($RegValueData) {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting Registry value Data of $RegValueName to $RegValueData"

                try {
                    Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                } catch {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry value Data of $RegValueName to $RegValueData."
                }
            } else {
                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: No Reg Value Data was passed. Will erase the currently set data from the value."

                Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Setting New Registry Value Data of $RegValueName to $RegValueData"

                try {
                    Set-ItemProperty -Path $RegPath -Name $RegValueName -Value $RegValueData -Force
                } catch {
                    Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: ERROR :: Failed to Set Registry Value Data of $RegValueName to $RegValueData."
                }
            }
        }
    }
    end {
        Write-Output "$(Get-Date -Format 'ddd, dd MMM yyyy HH:MM:ss') :: INFO :: Ending Script Execution."
    }
}
