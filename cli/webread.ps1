#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Fetch and extract clean, LLM-friendly Markdown or structured HTML from any webpage.
.DESCRIPTION
    Cross-platform webpage and documentation reader for macOS and Windows 11 (PowerShell 7).
    Extracts webpage contents into clean Markdown using Jina Reader (r.jina.ai),
    supports automatic probing of /llms-full.txt and /llms.txt, and CSS selectors via htmlq.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @"
webread: Clean, token-efficient webpage and documentation reader for agents and humans.

Usage:
  webread [options] <url>

Options:
  -s, --selector <sel>  Extract specific DOM element using htmlq CSS selector
  -l, --llms            Probe and fetch /llms-full.txt or /llms.txt from site domain
  -r, --raw             Fetch raw HTML without Jina Reader markdown conversion
  -o, --output <file>   Save output directly to a file
  -h, --help            Show this help message and exit

Examples:
  webread https://react.dev/learn/you-might-not-need-an-effect
  webread -s 'article' https://oxc.rs
  webread --llms https://viteplus.dev
  webread --raw https://example.com -o page.html
"@
}

$Selector = ''
$Llms = $false
$Raw = $false
$Output = ''
$Help = $false
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

if ($Selector -and -not (Get-Command 'htmlq' -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Error: htmlq is required for CSS selectors.')
    exit 1
}

$nullDevice = $IsWindows ? 'NUL' : '/dev/null'
$userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'

function Get-WebreadContent {
    param([string]$UrlToFetch, [string]$CurrentMode)

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
            return (& $curlCmd -sL -A $userAgent "$fullTxt")
        }

        $statusCode = & $curlCmd -sL -w '%{http_code}' -o $nullDevice "$stdTxt"
        if ($statusCode -eq '200') {
            return (& $curlCmd -sL -A $userAgent "$stdTxt")
        }

        [Console]::Error.WriteLine("Notice: Neither /llms-full.txt nor /llms.txt found on $origin, falling back to Reader...")
        $CurrentMode = 'jina'
    }

    if ($Selector) {
        return (& $curlCmd -sL -A $userAgent "$UrlToFetch" | & htmlq $Selector)
    }

    if ($CurrentMode -eq 'raw') {
        return (& $curlCmd -sL -A $userAgent "$UrlToFetch")
    }

    $jinaUrl = "https://r.jina.ai/$UrlToFetch"
    $content = & $curlCmd -sL --max-time 15 -H 'X-No-Cache: true' "$jinaUrl" 2>$null

    if ($LASTEXITCODE -eq 0 -and $content -and ($content -notmatch 'Request failed with status code')) {
        return $content
    }

    [Console]::Error.WriteLine('Notice: Jina Reader unavailable, falling back to direct fetch...')
    if (Get-Command 'htmlq' -ErrorAction SilentlyContinue) {
        return (& $curlCmd -sL -A $userAgent "$UrlToFetch" | & htmlq 'body')
    }
    return (& $curlCmd -sL -A $userAgent "$UrlToFetch")
}

$activeMode = $Llms ? 'llms' : ($Raw ? 'raw' : 'jina')
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
