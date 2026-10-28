#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Multi-dig: Check A records (via IPv4) and AAAA records (via IPv6) across multiple DNS resolvers in parallel.
.DESCRIPTION
    Cross-platform multi-resolver DNS checker for macOS and Windows 11 (PowerShell 7).
    Uses 'dig' when available (macOS / BIND tools), or Windows built-in 'Resolve-DnsName' cmdlet.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @'
mdig: Multi-dig: Check DNS records on different DNS servers at once
Usage: mdig [domain]
       mdig 'is1-ssl.mzstatic.com'
'@
}

$Domain = ''
$Help = $false

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif (-not $Domain) {
        $Domain = $arg
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not $Domain) {
    [Console]::Error.WriteLine('mdig: Multi-dig: Check DNS records on different DNS servers at once.')
    [Console]::Error.WriteLine('Usage: mdig [domain]')
    [Console]::Error.WriteLine("       mdig 'is1-ssl.mzstatic.com'")
    exit 1
}

$hasDig = $null -ne (Get-Command 'dig' -ErrorAction SilentlyContinue)
$hasResolveDns = $null -ne (Get-Command 'Resolve-DnsName' -ErrorAction SilentlyContinue)

if (-not $hasDig -and -not $hasResolveDns) {
    [Console]::Error.WriteLine('Error: Neither dig nor Resolve-DnsName is available on this system.')
    exit 1
}

$dnsServers = @(
    [PSCustomObject]@{ Index = 0; Name = 'Google'; IPv4 = '8.8.8.8'; IPv6 = '2001:4860:4860::8888' }
    [PSCustomObject]@{ Index = 1; Name = 'Cloudflare'; IPv4 = '1.1.1.1'; IPv6 = '2606:4700:4700::1111' }
    [PSCustomObject]@{ Index = 2; Name = 'Hinet'; IPv4 = '168.95.192.1'; IPv6 = '2001:b000:168::1' }
    [PSCustomObject]@{ Index = 3; Name = 'Hinet'; IPv4 = '168.95.1.1'; IPv6 = '2001:b000:168::2' }
    [PSCustomObject]@{ Index = 4; Name = 'System'; IPv4 = ''; IPv6 = '' }
)

$queries = [System.Collections.Generic.List[object]]::new()
foreach ($srv in $dnsServers) {
    $queries.Add([PSCustomObject]@{ Index = $srv.Index; Name = $srv.Name; RecordType = 'A'; ServerIp = $srv.IPv4 })
    $queries.Add([PSCustomObject]@{ Index = $srv.Index; Name = $srv.Name; RecordType = 'AAAA'; ServerIp = $srv.IPv6 })
}

$rawResults = @($queries | ForEach-Object -Parallel {
        $q = $_
        $targetDomain = $using:Domain
        $useDig = $using:hasDig
        $recType = $q.RecordType
        $srvIp = $q.ServerIp

        if ($useDig) {
            $digArgs = @()
            if ($srvIp) {
                $digArgs += "@$srvIp"
            }
            $digArgs += @($targetDomain, $recType, '+noclass', '+nottl', '+noall', '+answer', '+stats', '+time=2', '+tries=1')
            $out = @(& dig @digArgs 2>$null)
            if ($LASTEXITCODE -ne 0 -or $out.Count -eq 0) {
                return [PSCustomObject]@{ Index = $q.Index; Name = $q.Name; RecordType = $recType; ServerIp = $srvIp; Key = "[$recType timeout]"; Time = '' }
            }

            $records = [System.Collections.Generic.List[string]]::new()
            $queryTime = ''
            foreach ($line in $out) {
                $parts = @($line -split '\s+' | Where-Object { $_ -ne '' })
                if ($parts.Count -ge 3 -and $parts[1] -eq $recType) {
                    $records.Add($parts[2])
                }
                elseif ($parts.Count -ge 4 -and $parts[0] -eq ';;' -and $parts[1] -eq 'Query' -and $parts[2] -eq 'time:') {
                    $queryTime = $parts[3]
                }
            }

            $key = ($records.Count -eq 0) ? "[no $recType record]" : (($records | Sort-Object) -join ',')
            return [PSCustomObject]@{ Index = $q.Index; Name = $q.Name; RecordType = $recType; ServerIp = $srvIp; Key = $key; Time = $queryTime }
        }
        else {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $params = @{
                    Name         = $targetDomain
                    Type         = $recType
                    DnsOnly      = $true
                    QuickTimeout = $true
                    NoHostsFile  = $true
                    ErrorAction  = 'Stop'
                }
                if ($srvIp) {
                    $params['Server'] = $srvIp
                }
                $dnsOut = @(Resolve-DnsName @params)
                $sw.Stop()
                $queryTime = [string][Math]::Round($sw.Elapsed.TotalMilliseconds)

                $ips = @($dnsOut | Where-Object { $_.Type -eq $recType } | ForEach-Object { $_.IPAddress } | Where-Object { $_ })
                $key = ($ips.Count -eq 0) ? "[no $recType record]" : (($ips | Sort-Object) -join ',')
                return [PSCustomObject]@{ Index = $q.Index; Name = $q.Name; RecordType = $recType; ServerIp = $srvIp; Key = $key; Time = $queryTime }
            }
            catch {
                $sw.Stop()
                $msg = $_.Exception.Message
                if ($msg -match 'timeout|timed out|1460') {
                    return [PSCustomObject]@{ Index = $q.Index; Name = $q.Name; RecordType = $recType; ServerIp = $srvIp; Key = "[$recType timeout]"; Time = '' }
                }
                return [PSCustomObject]@{ Index = $q.Index; Name = $q.Name; RecordType = $recType; ServerIp = $srvIp; Key = "[no $recType record]"; Time = [string][Math]::Round($sw.Elapsed.TotalMilliseconds) }
            }
        }
    } -ThrottleLimit 10)

function Write-DnsSection {
    param([string]$Title, [object[]]$Items)

    Write-Output "── $Title ──"
    $order = [System.Collections.Generic.List[string]]::new()
    $groups = @{}

    foreach ($item in ($Items | Sort-Object Index)) {
        $k = $item.Key
        if (-not $groups.ContainsKey($k)) {
            $order.Add($k)
            $groups[$k] = [System.Collections.Generic.List[object]]::new()
        }
        $groups[$k].Add($item)
    }

    foreach ($k in $order) {
        if ($k.StartsWith('[')) {
            Write-Output $k
        }
        else {
            foreach ($ip in ($k -split ',')) {
                Write-Output $ip
            }
        }

        foreach ($entry in $groups[$k]) {
            $ipVal = $entry.ServerIp
            $timeVal = $entry.Time
            $desc = $ipVal ? "$($entry.Name) ($ipVal)" : $entry.Name
            if ($timeVal) {
                Write-Output "  - $desc [$timeVal ms]"
            }
            else {
                Write-Output "  - $desc"
            }
        }
        Write-Output ''
    }
}

Write-DnsSection -Title 'A Records' -Items @($rawResults | Where-Object { $_.RecordType -eq 'A' })
Write-DnsSection -Title 'AAAA Records' -Items @($rawResults | Where-Object { $_.RecordType -eq 'AAAA' })
