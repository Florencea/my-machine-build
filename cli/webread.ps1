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

function Show-Help {
    Write-Output @"
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
"@
}

# Resolve script root (handles extensionless symlinks on macOS ~/.local/bin/webread)
$realScriptDir = $PSScriptRoot
if (-not $realScriptDir) {
    try {
        $cmdArgs = [Environment]::GetCommandLineArgs()
        if ($cmdArgs.Length -gt 1) {
            $rawPath = $cmdArgs[1]
            $item = Get-Item -LiteralPath $rawPath -ErrorAction SilentlyContinue
            if ($item) {
                if ($item.LinkType) {
                    $target = $item.ResolveLinkTarget($true)
                    if ($target) { $realScriptDir = $target.DirectoryName }
                }
                else {
                    $realScriptDir = $item.DirectoryName
                }
            }
        }
    }
    catch {}
}
if (-not $realScriptDir) {
    $realScriptDir = [System.IO.Path]::GetDirectoryName((Get-Process -Id $PID).Path)
}

$parserScript = Join-Path $realScriptDir "helpers" "webread-parser.ts"
if (-not (Test-Path -LiteralPath $parserScript)) {
    # Fallback to search relative to current directory
    $candidate = Join-Path (Get-Location) "cli" "helpers" "webread-parser.ts"
    if (Test-Path -LiteralPath $candidate) {
        $parserScript = $candidate
    }
}

$Selector = ''
$Llms = $false
$Raw = $false
$Output = ''
$Help = $false
$UseJina = $false
$NoEnclosure = $false
$MaxChars = '64000'
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
        $MaxChars = [string]$args[++$i]
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
$curlCmd = (Get-Command $curlBin -ErrorAction SilentlyContinue)?.Source
if (-not $curlCmd) {
    [Console]::Error.WriteLine("Error: $curlBin is required but not installed.")
    exit 1
}

$nullDevice = $IsWindows ? 'NUL' : '/dev/null'
$userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'

function Invoke-LocalParser {
    param([string]$RawInput, [string]$SourceUrl)

    if (Test-Path -LiteralPath $parserScript) {
        $parserArgs = @(
            'node',
            $parserScript,
            '--url', $SourceUrl,
            '--max-chars', $MaxChars
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

        # Pipe stdin to vp node parser
        $output = $RawInput | & vp @parserArgs
        if ($LASTEXITCODE -eq 0) {
            return ($output -join "`n")
        }
    }

    # Fallback to direct output if parser is not available
    [Console]::Error.WriteLine("Notice: webread-parser.ts not found, outputting direct fetch.")
    return $RawInput
}

function Get-WebreadContent {
    param([string]$UrlToFetch, [string]$CurrentMode)

    # 1. Probing /llms-full.txt or /llms.txt
    if ($CurrentMode -eq 'llms') {
        try {
            $uri = [System.Uri]$UrlToFetch
            $origin = "$($uri.Scheme)://$($uri.Authority)"
        }
        catch {
            [Console]::Error.WriteLine("Error: Invalid URI '$UrlToFetch'")
            return $null
        }

        $fullTxt = "$origin/llms-full.txt"
        $stdTxt = "$origin/llms.txt"

        $statusCode = & $curlCmd -sL -w '%{http_code}' -o $nullDevice "$fullTxt"
        if ($statusCode -eq '200') {
            $content = & $curlCmd -sL -A $userAgent "$fullTxt"
            return (Invoke-LocalParser -RawInput $content -SourceUrl $fullTxt)
        }

        $statusCode = & $curlCmd -sL -w '%{http_code}' -o $nullDevice "$stdTxt"
        if ($statusCode -eq '200') {
            $content = & $curlCmd -sL -A $userAgent "$stdTxt"
            return (Invoke-LocalParser -RawInput $content -SourceUrl $stdTxt)
        }

        [Console]::Error.WriteLine("Notice: Neither /llms-full.txt nor /llms.txt found on $origin, falling back to local reader...")
        $CurrentMode = 'local'
    }

    # 2. Opt-in External Jina Reader
    if ($UseJina) {
        [Console]::Error.WriteLine("Notice: Using external Jina Reader service (r.jina.ai)...")
        $jinaUrl = "https://r.jina.ai/$UrlToFetch"
        $content = & $curlCmd -sL --max-time 15 -H 'X-No-Cache: true' "$jinaUrl" 2>$null

        if ($LASTEXITCODE -eq 0 -and $content -and ($content -notmatch 'Request failed with status code')) {
            return (Invoke-LocalParser -RawInput $content -SourceUrl $UrlToFetch)
        }
        [Console]::Error.WriteLine("Notice: External Jina Reader unavailable, falling back to local reader...")
    }

    # 3. Local-First Safe Fetch (Default)
    $fetchedHtml = & $curlCmd -sL --max-time 20 -A $userAgent "$UrlToFetch" 2>$null
    if (-not $fetchedHtml) {
        [Console]::Error.WriteLine("Error: Failed to fetch content from $UrlToFetch")
        return $null
    }

    return (Invoke-LocalParser -RawInput $fetchedHtml -SourceUrl $UrlToFetch)
}

$activeMode = $Llms ? 'llms' : 'local'
$result = Get-WebreadContent -UrlToFetch $targetUrl -CurrentMode $activeMode

if (-not $result) {
    exit 1
}

if ($Output) {
    $newline = $IsWindows ? "`r`n" : "`n"
    [System.IO.File]::WriteAllText($Output, ($result -join $newline), [System.Text.UTF8Encoding]::new($false))
    Write-Output "Content saved to $Output"
}
else {
    $result
}
