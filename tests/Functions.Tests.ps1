#- Behavior checks for public functions that run the same on every OS without network,
#- admin rights, or external tools. Each loads the copy the profile would load here.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    $names = @(
        'ConvertTo-Base64', 'ConvertFrom-Base64', 'Convert-ROT13', 'Convert-ROT47',
        'Convert-Subnetmask', 'Convert-IPv4Address', 'Get-IPv4Subnet', 'Split-IPv4Subnet',
        'Get-RandomPassword', 'Get-RandomPIN', 'Get-RandomString', 'ConvertTo-StringList',
        'Get-IniContent', 'Test-IsFileBinary', 'head', 'tail'
    )
    foreach ($name in $names) { . (Import-PSProfileFunction -Name $name) }
}

Describe 'Base64' {
    It 'ConvertTo-Base64 encodes a file''s bytes' {
        $path = Join-Path $TestDrive 'bytes.bin'
        [System.IO.File]::WriteAllBytes($path, [byte[]](0, 1, 2, 250, 255))
        ConvertTo-Base64 -Path $path | Should -Be 'AAEC+v8='
    }

    It 'ConvertFrom-Base64 decodes to text' {
        ConvertFrom-Base64 -String 'aGVsbG8gd29ybGQ=' | Should -Be 'hello world'
    }
}

Describe 'ROT ciphers' {
    It 'Convert-ROT13 encrypts and decrypts' {
        (Convert-ROT13 -Text 'Hello, World' -Rot 13).Text | Should -BeExactly 'Uryyb, Jbeyq'
        (Convert-ROT13 -Text 'Uryyb, Jbeyq' -Rot 13 -Decrypt).Text | Should -BeExactly 'Hello, World'
    }

    It 'Convert-ROT47 round-trips' {
        $encrypted = (Convert-ROT47 -Text 'Hello' -Rot 47).Text
        $encrypted | Should -BeExactly 'w6==@'
        (Convert-ROT47 -Text $encrypted -Rot 47 -Decrypt).Text | Should -BeExactly 'Hello'
    }
}

Describe 'IPv4 helpers' {
    It 'Convert-Subnetmask converts CIDR to mask and back' {
        (Convert-Subnetmask -CIDR 24).Mask | Should -Be '255.255.255.0'
        (Convert-Subnetmask -Mask '255.255.240.0').CIDR | Should -Be 20
    }

    It 'Convert-IPv4Address converts between dotted and Int64' {
        (Convert-IPv4Address -IPv4Address '192.168.1.1').Int64 | Should -Be 3232235777
        (Convert-IPv4Address -Int64 3232235777).IPv4Address | Should -Be '192.168.1.1'
    }

    It 'Get-IPv4Subnet describes a /24' {
        $subnet = Get-IPv4Subnet -IPv4Address '192.168.1.77' -CIDR 24
        "$($subnet.NetworkID)" | Should -Be '192.168.1.0'
        "$($subnet.Broadcast)" | Should -Be '192.168.1.255'
        $subnet.Hosts | Should -Be 254
    }

    It 'Split-IPv4Subnet splits a /24 into four /26s' {
        $subnets = @(Split-IPv4Subnet -IPv4Address '192.168.1.0' -CIDR 24 -NewCIDR 26)
        $subnets.Count | Should -Be 4
        "$($subnets[0].Broadcast)" | Should -Be '192.168.1.63'
    }
}

Describe 'Random generators' {
    It 'Get-RandomPassword honors length and character switches' {
        $password = (Get-RandomPassword -Length 24 -DisableSpecialChars).Password
        $password.Length | Should -Be 24
        $password | Should -Match '^[A-Za-z0-9]+$'
    }

    It 'Get-RandomPIN returns digits of the requested length' {
        (Get-RandomPIN -Length 6).PIN | Should -Match '^\d{6}$'
    }

    It 'Get-RandomString returns the requested length' {
        (Get-RandomString -Length 12).Length | Should -Be 12
    }
}

Describe 'Text and file helpers' {
    BeforeAll {
        $numbers = Join-Path $TestDrive 'numbers.txt'
        1..20 | Set-Content -Path $numbers
    }

    It 'ConvertTo-StringList joins with a delimiter' {
        ConvertTo-StringList -Array 'a', 'b', 'c' | Should -BeExactly 'a,b,c'
        ConvertTo-StringList -Array 'a', 'b' -Delimiter ';' | Should -BeExactly 'a;b'
    }

    It 'Get-IniContent parses sections, keys, and comments' {
        $ini = Join-Path $TestDrive 'test.ini'
        "[s1]`nk=v`n; note`n[s2]`na = b c" | Set-Content -Path $ini
        $content = Get-IniContent -FilePath $ini
        $content['s1']['k'] | Should -Be 'v'
        $content['s1']['Comment1'] | Should -Be '; note'
        $content['s2']['a'] | Should -Be 'b c'
    }

    It 'Test-IsFileBinary tells text from binary' {
        $binary = Join-Path $TestDrive 'binary.bin'
        [System.IO.File]::WriteAllBytes($binary, [byte[]](77, 90, 0, 0, 3, 0))
        Test-IsFileBinary -FilePath $numbers | Should -BeFalse
        Test-IsFileBinary -FilePath $binary | Should -BeTrue
    }

    It 'head returns the first lines' {
        (head $numbers -n 3) -join ',' | Should -Be '1,2,3'
    }

    It 'tail returns the last lines' {
        (tail $numbers -n 3) -join ',' | Should -Be '18,19,20'
    }
}
