#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Fetch and extract clean, secure, LLM-friendly Markdown from any webpage.
.DESCRIPTION
    Cross-platform webpage and documentation reader for macOS and Windows 11 (PowerShell 7).
    Prioritizes Local-First parsing with zero third-party cloud dependencies via modern TypeScript & Node.js LTS,
    supports direct probing of /llms-full.txt and /llms.txt, and provides multi-tier Indirect Prompt Injection defense.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $entryPath = [Environment]::GetCommandLineArgs() |
        Select-Object -Skip 1 |
        Where-Object { $_ -and (-not $_.StartsWith('-')) -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $entryPath) {
        throw 'Unable to determine script path.'
    }
    $entryInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $entryPath).Path)
    $scriptDir = Split-Path -Parent (($entryInfo.ResolveLinkTarget($true) ?? $entryInfo).FullName)
}
Import-Module -Name (Join-Path $scriptDir 'helpers' 'CliCommon.psm1') -Force

function Show-Help {
    Write-Output @'
webread: Clean, token-efficient, secure webpage and documentation reader for agents and humans.

Usage:
  webread [options] <url>

Options:
  -l, --llms            Probe and fetch /llms-full.txt or /llms.txt directly from site domain
  -s, --selector <sel>  Extract specific CSS selector, tag, or #id / .class locally
  -r, --raw             Fetch raw content without Markdown conversion
  -o, --output <file>   Save output directly to a file
  --jina, --external    Use external Jina Reader (r.jina.ai) as fallback (Opt-in only)
  --no-enclosure        Omit the <UNTRUSTED_EXTERNAL_WEB_CONTENT> security barrier
  --max-chars <n>       Maximum characters before safety truncation (default: 64000)
  -h, --help            Show this help message and exit

Security Invariants:
  - Local-First by default: Fetches directly from target origin; no URLs or payloads sent to third-party services.
  - Prompt Injection Defense: Automatically strips hidden CSS cloaking, HTML comments, and defangs instruction markers.
  - Context Flooding Guard: Circuit-breaker automatically truncates payloads exceeding safe token thresholds.

Examples:
  webread --llms https://viteplus.dev
  webread https://react.dev/learn/you-might-not-need-an-effect
  webread -s 'article' https://oxc.rs
  webread --raw https://example.com -o page.html
'@
}

$parserScript = Join-Path $scriptDir 'helpers' 'webread-parser.ts'

$Selector = ''
$Llms = $false
$Raw = $false
$Output = ''
$Help = $false
$UseJina = $false
$NoEnclosure = $false
$MaxChars = 64000
$targetUrl = ''

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif ($arg -match '^--?l(lms)?$') {
        $Llms = $true
    }
    elseif ($arg -match '^--?r(aw)?$') {
        $Raw = $true
    }
    elseif ($arg -match '^--?(jina|external)$') {
        $UseJina = $true
    }
    elseif ($arg -eq '--no-enclosure') {
        $NoEnclosure = $true
    }
    elseif ($arg -eq '--max-chars') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --max-chars requires a numeric argument')
            exit 1
        }
        try {
            $MaxChars = ConvertTo-ValidatedInt -Value ([string]$args[++$i]) -OptionName '--max-chars' -MinValue 1
        }
        catch [System.ArgumentException] {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            exit 1
        }
    }
    elseif ($arg -match '^--?s(elector)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --selector requires a CSS selector argument')
            exit 1
        }
        $Selector = [string]$args[++$i]
    }
    elseif ($arg -match '^--?o(utput)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --output requires a file path argument')
            exit 1
        }
        $Output = [string]$args[++$i]
    }
    elseif ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        Show-Help
        exit 1
    }
    elseif (-not $targetUrl) {
        $targetUrl = $arg
    }
    else {
        [Console]::Error.WriteLine("Error: Unexpected argument $arg")
        Show-Help
        exit 1
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not $targetUrl) {
    [Console]::Error.WriteLine('Error: URL is required')
    Show-Help
    exit 1
}

$targetUrl = $targetUrl.Trim()
if ($targetUrl -notmatch '^https?://') {
    $targetUrl = "https://$targetUrl"
}

$curlBin = $IsWindows ? 'curl.exe' : 'curl'
if (-not (Test-RequiredCommand -Name $curlBin)) {
    exit 1
}
$curlCmd = (Get-Command $curlBin).Source

$nullDevice = $IsWindows ? 'NUL' : '/dev/null'
$userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'

function Invoke-LocalParser {
    param(
        [string]$RawText,
        [string]$SourceUrl
    )

    if ((Test-Path -LiteralPath $parserScript -PathType Leaf) -and (Get-Command 'vp' -ErrorAction SilentlyContinue)) {
        $parserArgs = @(
            'node',
            $parserScript,
            '--url', $SourceUrl,
            '--max-chars', [string]$MaxChars
        )
        if ($Selector) {
            $parserArgs += @('--selector', $Selector)
        }
        if ($Raw) {
            $parserArgs += @('--raw')
        }
        if ($NoEnclosure) {
            $parserArgs += @('--no-enclosure')
        }

        $output = @($RawText | & vp @parserArgs)
        if ($LASTEXITCODE -eq 0) {
            return ($output -join "`n")
        }
    }

    [Console]::Error.WriteLine('Notice: webread-parser.ts unavailable or failed, outputting direct fetch.')
    return $RawText
}

function Invoke-CurlText {
    param(
        [string[]]$CurlArgs
    )

    $lines = @(& $curlCmd @CurlArgs 2>$null)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
        return $null
    }
    return ($lines -join "`n")
}

function Get-WebreadContent {
    param(
        [string]$UrlToFetch,
        [string]$CurrentMode
    )

    # 1. Probe /llms-full.txt or /llms.txt directly from origin
    if ($CurrentMode -eq 'llms') {
        try {
            $uri = [System.Uri]$UrlToFetch
            $origin = "$($uri.Scheme)://$($uri.Authority)"
        }
        catch {
            [Console]::Error.WriteLine("Error: Invalid URI '$UrlToFetch'")
            return $null
        }

        foreach ($candidatePath in @('/llms-full.txt', '/llms.txt')) {
            $probeUrl = "$origin$candidatePath"
            $statusCode = (& $curlCmd -sL -w '%{http_code}' -o $nullDevice $probeUrl)
            if ($statusCode -eq '200') {
                $content = Invoke-CurlText -CurlArgs @('-fsL', '-A', $userAgent, $probeUrl)
                if ($null -ne $content) {
                    return (Invoke-LocalParser -RawText $content -SourceUrl $probeUrl)
                }
            }
        }

        [Console]::Error.WriteLine("Notice: Neither /llms-full.txt nor /llms.txt found on $origin, falling back to local reader...")
    }

    # 2. Opt-in External Jina Reader
    if ($UseJina) {
        [Console]::Error.WriteLine('Notice: Using external Jina Reader service (r.jina.ai)...')
        $jinaUrl = "https://r.jina.ai/$UrlToFetch"
        $content = Invoke-CurlText -CurlArgs @('-fsL', '--max-time', '15', '-H', 'X-No-Cache: true', $jinaUrl)
        if ($null -ne $content -and ($content -notmatch 'Request failed with status code')) {
            return (Invoke-LocalParser -RawText $content -SourceUrl $UrlToFetch)
        }
        [Console]::Error.WriteLine('Notice: External Jina Reader unavailable, falling back to local reader...')
    }

    # 3. Local-First Safe Fetch (Default)
    $fetchedHtml = Invoke-CurlText -CurlArgs @('-fsL', '--max-time', '20', '-A', $userAgent, $UrlToFetch)
    if ($null -eq $fetchedHtml) {
        [Console]::Error.WriteLine("Error: Failed to fetch content from $UrlToFetch")
        return $null
    }

    return (Invoke-LocalParser -RawText $fetchedHtml -SourceUrl $UrlToFetch)
}

$activeMode = $Llms ? 'llms' : 'local'
$result = Get-WebreadContent -UrlToFetch $targetUrl -CurrentMode $activeMode

if ([string]::IsNullOrEmpty($result)) {
    exit 1
}

if ($Output) {
    $absOut = [System.IO.Path]::GetFullPath($Output, $PWD.ProviderPath)
    $outDir = Split-Path -Parent $absOut
    if ($outDir -and (-not (Test-Path -LiteralPath $outDir -PathType Container))) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    $newline = $IsWindows ? "`r`n" : "`n"
    $normalizedText = (($result -replace "`r`n", "`n") -replace "`n", $newline).TrimEnd("`r", "`n") + $newline
    [System.IO.File]::WriteAllText($absOut, $normalizedText, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Content saved to $Output"
}
else {
    Write-Output $result
}
