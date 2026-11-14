#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Clone all GitHub Repositories for the authenticated user in parallel.
.DESCRIPTION
    Cross-platform GitHub repository batch cloner for macOS and Windows 11 (PowerShell 7).
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
clall: Clone all GitHub Repositories for the authenticated user
Usage: clall [GITHUB_ACCESS_TOKEN]
       clall ghp_000000000000000000000000000000000000
       GITHUB_TOKEN=... clall
'@
}

$Token = ''
$Help = $false

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        Show-Help
        exit 1
    }
    elseif (-not $Token) {
        $Token = $arg
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

if (-not $Token) {
    $Token = $env:GITHUB_TOKEN ? $env:GITHUB_TOKEN : ($env:GH_TOKEN ? $env:GH_TOKEN : '')
}

if (-not $Token) {
    [Console]::Error.WriteLine('clall: Clone all GitHub Repositories')
    [Console]::Error.WriteLine('Usage: clall [GITHUB_ACCESS_TOKEN]')
    [Console]::Error.WriteLine('       GITHUB_TOKEN=... clall')
    exit 1
}

if (-not (Test-RequiredCommand -Name 'git')) {
    exit 1
}

$headers = @{
    'Accept'               = 'application/vnd.github+json'
    'Authorization'        = "Bearer $Token"
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'pwsh-clall'
}

$repos = [System.Collections.Generic.List[string]]::new()
$page = 1
while ($true) {
    $uri = "https://api.github.com/user/repos?type=owner&per_page=100&page=$page"
    $response = @(Invoke-RestMethod -Uri $uri -Headers $headers -Method Get)
    if ($response.Count -eq 0) {
        break
    }
    foreach ($item in $response) {
        if ($item.ssh_url) {
            $repos.Add([string]$item.ssh_url)
        }
    }
    if ($response.Count -lt 100) {
        break
    }
    $page++
}

$total = $repos.Count
if ($total -eq 0) {
    exit 0
}

$targetRoot = $PWD.ProviderPath
$syncState = [hashtable]::Synchronized(@{ Done = 0 })

$results = @($repos | ForEach-Object -Parallel {
        $repoUrl = $_
        $repoName = [System.IO.Path]::GetFileNameWithoutExtension($repoUrl)
        $destPath = Join-Path $using:targetRoot $repoName
        $totalCount = $using:total
        $state = $using:syncState

        if (Test-Path -LiteralPath $destPath) {
            [System.Threading.Monitor]::Enter($state)
            try {
                $state.Done++
                $done = $state.Done
            }
            finally {
                [System.Threading.Monitor]::Exit($state)
            }
            Write-Output "Skip [$done/$totalCount] $repoName (already exists)"
            return [PSCustomObject]@{ Name = $repoName; Success = $true }
        }

        $cloneErr = @(& git clone --quiet $repoUrl $destPath 2>&1)
        if ($LASTEXITCODE -eq 0) {
            [System.Threading.Monitor]::Enter($state)
            try {
                $state.Done++
                $done = $state.Done
            }
            finally {
                [System.Threading.Monitor]::Exit($state)
            }
            Write-Output "Clone [$done/$totalCount] $repoName ok"
            return [PSCustomObject]@{ Name = $repoName; Success = $true }
        }

        $detail = ($cloneErr | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() } | Select-Object -First 1) ?? "exit code $LASTEXITCODE"
        [Console]::Error.WriteLine("Clone $repoName failed: $detail")
        return [PSCustomObject]@{ Name = $repoName; Success = $false }
    } -ThrottleLimit 6)

$failedCount = @($results | Where-Object { -not $_.Success }).Count
if ($failedCount -gt 0) {
    exit 1
}
