#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Multi-dig: Check A records (via IPv4) and AAAA records (via IPv6) across multiple DNS resolvers in parallel.
.DESCRIPTION
    Cross-platform multi-resolver DNS checker for macOS and Windows 11 (PowerShell 7).
    Uses 'dig' when available (macOS / BIND tools), or Windows built-in 'Resolve-DnsName' cmdlet.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @"
mdig: Multi-dig: Check DNS records on different DNS servers at once
Usage: mdig [domain]
       mdig 'is1-ssl.mzstatic.com'
"@
}

$Domain = ''
if ($RemainingArgs) {
    foreach ($arg in $RemainingArgs) {
        if ($arg -match '^--?h(elp)?$') {
            $Help = [switch]::new($true)
        }
        elseif (-not $Domain) {
            $Domain = $arg
        }
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

$results = @($dnsServers | ForEach-Object -Parallel {
        $srv = $_
        $targetDomain = $using:Domain
        $useDig = $using:hasDig

        function Invoke-SingleDnsQuery {
            param([string]$DomainName, [string]$RecordType, [string]$ServerIp, [bool]$UseDigTool)

            if ($UseDigTool) {
                $digArgs = @()
                if ($ServerIp) {
                    $digArgs += "@$ServerIp"
                }
                $digArgs += @($DomainName, $RecordType, '+noclass', '+nottl', '+noall', '+answer', '+stats', '+time=2', '+tries=1')
                $out = @(& dig @digArgs 2>$null)
                if ($LASTEXITCODE -ne 0 -or $out.Count -eq 0) {
                    return [PSCustomObject]@{ Key = "[$RecordType timeout]"; Time = '' }
                }

                $records = [System.Collections.Generic.List[string]]::new()
                $queryTime = ''
                foreach ($line in $out) {
                    $parts = @($line -split '\s+' | Where-Object { $_ -ne '' })
                    if ($parts.Count -ge 3 -and $parts[1] -eq $RecordType) {
                        $records.Add($parts[2])
                    }
                    elseif ($parts.Count -ge 4 -and $parts[0] -eq ';;' -and $parts[1] -eq 'Query' -and $parts[2] -eq 'time:') {
                        $queryTime = $parts[3]
                    }
                }

                if ($records.Count -eq 0) {
                    return [PSCustomObject]@{ Key = "[no $RecordType record]"; Time = $queryTime }
                }
                $sortedIps = ($records | Sort-Object) -join ','
                return [PSCustomObject]@{ Key = $sortedIps; Time = $queryTime }
            }
            else {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $params = @{
                        Name         = $DomainName
                        Type         = $RecordType
                        DnsOnly      = $true
                        QuickTimeout = $true
                        NoHostsFile  = $true
                        ErrorAction  = 'Stop'
                    }
                    if ($ServerIp) {
                        $params['Server'] = $ServerIp
                    }
                    $dnsOut = @(Resolve-DnsName @params)
                    $sw.Stop()
                    $queryTime = [string][Math]::Round($sw.Elapsed.TotalMilliseconds)

                    $ips = @($dnsOut | Where-Object { $_.Type -eq $RecordType } | ForEach-Object { $_.IPAddress } | Where-Object { $_ })
                    if ($ips.Count -eq 0) {
                        return [PSCustomObject]@{ Key = "[no $RecordType record]"; Time = $queryTime }
                    }
                    $sortedIps = ($ips | Sort-Object) -join ','
                    return [PSCustomObject]@{ Key = $sortedIps; Time = $queryTime }
                }
                catch {
                    $sw.Stop()
                    $msg = $_.Exception.Message
                    if ($msg -match 'timeout|timed out|1460') {
                        return [PSCustomObject]@{ Key = "[$RecordType timeout]"; Time = '' }
                    }
                    return [PSCustomObject]@{ Key = "[no $RecordType record]"; Time = [string][Math]::Round($sw.Elapsed.TotalMilliseconds) }
                }
            }
        }

        $resA = Invoke-SingleDnsQuery -DomainName $targetDomain -RecordType 'A' -ServerIp $srv.IPv4 -UseDigTool $useDig
        $resAAAA = Invoke-SingleDnsQuery -DomainName $targetDomain -RecordType 'AAAA' -ServerIp $srv.IPv6 -UseDigTool $useDig

        [PSCustomObject]@{
            Index    = $srv.Index
            Name     = $srv.Name
            IPv4     = $srv.IPv4
            IPv6     = $srv.IPv6
            AKey     = $resA.Key
            ATime    = $resA.Time
            AAAAKey  = $resAAAA.Key
            AAAATime = $resAAAA.Time
        }
    } -ThrottleLimit 5 | Sort-Object Index)

function Write-DnsSection {
    param([string]$Title, [object[]]$Items, [string]$KeyProp, [string]$IpProp, [string]$TimeProp)

    Write-Output "── $Title ──"
    $order = [System.Collections.Generic.List[string]]::new()
    $groups = @{}

    foreach ($item in $Items) {
        $k = $item.$KeyProp
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
            $ipVal = $entry.$IpProp
            $timeVal = $entry.$TimeProp
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

Write-DnsSection -Title 'A Records' -Items $results -KeyProp 'AKey' -IpProp 'IPv4' -TimeProp 'ATime'
Write-DnsSection -Title 'AAAA Records' -Items $results -KeyProp 'AAAAKey' -IpProp 'IPv6' -TimeProp 'AAAATime'
