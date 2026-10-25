#- Behavior checks for the cross-platform diagnostics functions in assets/public/shared.
#- Everything runs against 127.0.0.1 listeners started by the tests themselves, so no
#- network access or public test hosts are needed.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    $names = @(
        'Test-Port', 'Get-ProcessByPort', 'Test-TlsCertificate', 'ConvertFrom-Jwt',
        'Get-PathReport', 'Invoke-Retry', 'Get-LastBootTime'
    )
    foreach ($name in $names) { . (Import-PSProfileFunction -Name $name) }

    function Get-FreeTcpPort {
        $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $probe.Start()
        $port = $probe.LocalEndpoint.Port
        $probe.Stop()
        $port
    }

    function ConvertTo-Base64Url([string]$Text) {
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
}

Describe 'Test-Port' {
    BeforeAll {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $openPort = $listener.LocalEndpoint.Port
    }
    AfterAll { $listener.Stop() }

    It 'reports an open port with a latency' {
        $result = Test-Port -ComputerName 127.0.0.1 -Port $openPort
        $result.Open | Should -BeTrue
        $result.LatencyMs | Should -Not -BeNullOrEmpty
        $result.Error | Should -BeNullOrEmpty
    }

    It 'reports a closed port as not open' {
        # Windows retries a refused SYN for ~2s, so a short timeout can end it either way
        $result = Test-Port -ComputerName 127.0.0.1 -Port (Get-FreeTcpPort) -TimeoutMs 300
        $result.Open | Should -BeFalse
        $result.Error | Should -Not -BeNullOrEmpty
    }

    It '-Quiet returns one boolean per port' {
        $result = Test-Port -ComputerName 127.0.0.1 -Port $openPort, (Get-FreeTcpPort) -TimeoutMs 300 -Quiet
        $result | Should -HaveCount 2
        $result[0] | Should -BeTrue
        $result[1] | Should -BeFalse
    }
}

Describe 'Get-ProcessByPort' {
    BeforeAll {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $client = [System.Net.Sockets.TcpClient]::new()
        $client.Connect([System.Net.IPAddress]::Loopback, $port)
        $accepted = $listener.AcceptTcpClient()
    }
    AfterAll {
        $client.Dispose()
        $accepted.Dispose()
        $listener.Stop()
    }

    It 'finds this process listening on a local port' {
        $result = @(Get-ProcessByPort -Port $port -Protocol TCP)
        $result.Count | Should -BeGreaterThan 0
        $result.ProcessId | Should -Contain $PID
        $result.State | Should -Match '^LISTEN$|^Listen$'
    }

    It 'finds this process as the client with -RemotePort' {
        $result = @(Get-ProcessByPort -RemotePort $port)
        $mine = @($result | Where-Object { $_.ProcessId -eq $PID -and $_.RemotePort -eq $port })
        $mine.Count | Should -BeGreaterThan 0
        $mine[0].LocalPort | Should -Not -Be $port
    }

    It 'rejects -RemotePort with -Protocol UDP' {
        { Get-ProcessByPort -RemotePort $port -Protocol UDP } | Should -Throw '*only applies to TCP*'
    }
}

Describe 'Test-TlsCertificate' {
    BeforeAll {
        # Self-signed cert for test.local + 127.0.0.1, expiring in 10 days
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            'CN=test.local', $rsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $san = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
        $san.AddDnsName('test.local')
        $san.AddIpAddress([System.Net.IPAddress]::Loopback)
        $request.CertificateExtensions.Add($san.Build())
        $now = [DateTimeOffset]::Now
        $temp = $request.CreateSelfSigned($now.AddDays(-1), $now.AddDays(10))
        # Round-trip through PFX: SChannel on Windows can't use the ephemeral key CreateSelfSigned returns
        $pfx = $temp.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, 'test')
        $script:serverCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($pfx, 'test')

        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $tlsPort = $listener.LocalEndpoint.Port

        # Serve handshakes from a separate runspace so the test thread can be the client
        $server = [powershell]::Create()
        $null = $server.AddScript({
                param($Listener, $Cert)
                while ($true) {
                    try { $tcp = $Listener.AcceptTcpClient() } catch { break }
                    try {
                        $ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false)
                        $ssl.AuthenticateAsServer($Cert)
                        $ssl.Dispose()
                    }
                    catch { }
                    finally { $tcp.Dispose() }
                }
            }).AddArgument($listener).AddArgument($script:serverCert)
        $serverHandle = $server.BeginInvoke()
    }
    AfterAll {
        $listener.Stop()
        $null = $serverHandle.AsyncWaitHandle.WaitOne(5000)
        $server.Dispose()
    }

    It 'reads the certificate even though it is untrusted' {
        $result = Test-TlsCertificate -ComputerName "127.0.0.1:$tlsPort" -ServerName test.local
        $result.Subject | Should -Be 'CN=test.local'
        $result.Thumbprint | Should -Be $script:serverCert.Thumbprint
        $result.Valid | Should -BeFalse
        $result.ChainStatus | Should -Contain 'UntrustedRoot'
    }

    It 'parses SANs without platform prefixes' {
        $result = Test-TlsCertificate -ComputerName 127.0.0.1 -Port $tlsPort -ServerName test.local
        $result.SANs | Should -Contain 'test.local'
        $result.SANs | Should -Contain '127.0.0.1'
        $result.SANs | Where-Object { $_ -match 'DNS|=' } | Should -BeNullOrEmpty
    }

    It 'flags a name mismatch only when the name is not in the SANs' {
        $mismatch = Test-TlsCertificate -ComputerName "127.0.0.1:$tlsPort" -ServerName other.local
        $match = Test-TlsCertificate -ComputerName "127.0.0.1:$tlsPort" -ServerName test.local
        $mismatch.PolicyErrors.ToString() | Should -Match 'RemoteCertificateNameMismatch'
        $match.PolicyErrors.ToString() | Should -Not -Match 'RemoteCertificateNameMismatch'
    }

    It 'marks a cert inside the warning window as expiring' {
        $result = Test-TlsCertificate -ComputerName "https://127.0.0.1:$tlsPort/" -ServerName test.local
        $result.Port | Should -Be $tlsPort
        $result.DaysRemaining | Should -BeIn 9, 10
        $result.Expiring | Should -BeTrue
        (Test-TlsCertificate -ComputerName "127.0.0.1:$tlsPort" -ServerName test.local -WarningDays 5).Expiring | Should -BeFalse
    }

    It 'writes an error for a closed port' {
        $result = Test-TlsCertificate -ComputerName 127.0.0.1 -Port (Get-FreeTcpPort) -TimeoutMs 500 -ErrorAction SilentlyContinue -ErrorVariable tlsError
        $result | Should -BeNullOrEmpty
        $tlsError | Should -Not -BeNullOrEmpty
    }
}

Describe 'ConvertFrom-Jwt' {
    BeforeAll {
        $header = ConvertTo-Base64Url '{"alg":"HS256","typ":"JWT"}'
    }

    It 'decodes claims and converts exp to a future local time' {
        $exp = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
        # Non-ASCII claim, built from a char code so this file stays ASCII for Windows PowerShell 5.1
        $name = 'Zo' + [char]0xEB
        $payload = ConvertTo-Base64Url ('{"sub":"joe","iss":"psprofile","aud":"tests","exp":' + $exp + ',"name":"' + $name + '"}')
        $result = ConvertFrom-Jwt -Token "$header.$payload.signature"
        $result.Algorithm | Should -Be 'HS256'
        $result.Subject | Should -Be 'joe'
        $result.Payload.name | Should -BeExactly $name
        $result.Expired | Should -BeFalse
        $result.TimeRemaining.TotalMinutes | Should -BeGreaterThan 50
        $result.Signed | Should -BeTrue
    }

    It 'strips a Bearer prefix and reports an expired token' {
        $payload = ConvertTo-Base64Url '{"exp":1500000000}'
        $result = "Bearer $header.$payload." | ConvertFrom-Jwt
        $result.Expired | Should -BeTrue
        $result.TimeRemaining | Should -BeNullOrEmpty
        $result.Signed | Should -BeFalse
    }

    It 'writes an error for input that is not a JWT' {
        ConvertFrom-Jwt -Token 'not-a-token' -ErrorAction SilentlyContinue -ErrorVariable jwtError | Should -BeNullOrEmpty
        $jwtError | Should -Not -BeNullOrEmpty
    }

    It 'refuses an encrypted JWE' {
        ConvertFrom-Jwt -Token 'a.b.c.d.e' -ErrorAction SilentlyContinue -ErrorVariable jweError | Should -BeNullOrEmpty
        "$jweError" | Should -Match 'JWE'
    }
}

Describe 'Get-PathReport' {
    BeforeAll {
        $originalPath = $env:PATH
        $sep = [IO.Path]::PathSeparator
        $real = Join-Path $TestDrive 'bin'
        $null = New-Item -ItemType Directory -Path $real
        $missing = Join-Path $TestDrive 'missing'
        $env:PATH = ($real, $missing, ($real + [IO.Path]::DirectorySeparatorChar), '') -join $sep
        $report = @(Get-PathReport)
    }
    AfterAll { $env:PATH = $originalPath }

    It 'lists every entry in order' {
        $report.Order | Should -Be @(1, 2, 3, 4)
    }

    It 'flags a missing directory' {
        $report[0].Exists | Should -BeTrue
        $report[1].Exists | Should -BeFalse
    }

    It 'flags a duplicate that differs only by a trailing separator' {
        $report[2].Duplicate | Should -BeTrue
        $report[2].DuplicateOf | Should -Be 1
    }

    It 'flags an empty entry' {
        $report[3].Empty | Should -BeTrue
    }

    It '-Problems leaves out healthy entries' {
        $env:PATH = ($real, $missing) -join $sep
        $problems = @(Get-PathReport -Problems)
        $problems | Should -HaveCount 1
        $problems[0].Path | Should -Be $missing
    }
}

Describe 'Invoke-Retry' {
    It 'returns the output once an attempt succeeds' {
        $state = @{ Calls = 0 }
        $result = Invoke-Retry -DelaySeconds 0 -WarningAction SilentlyContinue {
            $state.Calls++
            if ($state.Calls -lt 3) { throw "fail $($state.Calls)" }
            'done'
        }
        $result | Should -Be 'done'
        $state.Calls | Should -Be 3
    }

    It 'retries a non-terminating error and rethrows after the last attempt' {
        $state = @{ Calls = 0 }
        { Invoke-Retry -MaxAttempts 2 -DelaySeconds 0 -WarningAction SilentlyContinue {
                $state.Calls++
                Get-Item -Path (Join-Path $TestDrive 'nope')
            } } | Should -Throw
        $state.Calls | Should -Be 2
    }

    It 'does not retry exceptions outside -RetryOn' {
        $state = @{ Calls = 0 }
        { Invoke-Retry -DelaySeconds 0 -RetryOn ([System.TimeoutException]) {
                $state.Calls++
                throw [System.IO.IOException]::new('io')
            } } | Should -Throw
        $state.Calls | Should -Be 1
    }
}

Describe 'Get-LastBootTime' {
    It 'returns a boot time in the past for the local computer' {
        $result = Get-LastBootTime
        $result.ComputerName | Should -Not -BeNullOrEmpty
        $result.LastBootUpTime | Should -BeOfType [datetime]
        $result.LastBootUpTime | Should -BeLessThan (Get-Date)
        $result.LastBootUpTime | Should -BeGreaterThan (Get-Date).AddYears(-5)
    }

    It 'treats localhost as the local computer' {
        (Get-LastBootTime -ComputerName localhost).LastBootUpTime | Should -BeOfType [datetime]
    }
}
