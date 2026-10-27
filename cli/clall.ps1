#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Clone all GitHub Repositories for the authenticated user in parallel.
.DESCRIPTION
    Cross-platform GitHub repository batch cloner for macOS and Windows 11 (PowerShell 7).
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
clall: Clone all GitHub Repositories for the authenticated user
Usage: clall [GITHUB_ACCESS_TOKEN]
       clall ghp_000000000000000000000000000000000000
"@
}

$Token = ''
if ($RemainingArgs) {
    foreach ($arg in $RemainingArgs) {
        if ($arg -match '^--?h(elp)?$') {
            $Help = [switch]::new($true)
        }
        elseif (-not $Token) {
            $Token = $arg
        }
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not $Token) {
    [Console]::Error.WriteLine('clall: Clone all GitHub Repositories')
    [Console]::Error.WriteLine('Usage: clall [GITHUB_ACCESS_TOKEN]')
    [Console]::Error.WriteLine('       clall ghp_000000000000000000000000000000000000')
    exit 1
}

if (-not (Get-Command 'git' -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Error: git is not installed')
    exit 1
}

$headers = @{
    'Accept'               = 'application/vnd.github+json'
    'Authorization'        = "Bearer $Token"
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'pwsh-clall'
}

$response = Invoke-RestMethod -Uri 'https://api.github.com/user/repos?type=owner&per_page=100' -Headers $headers -Method Get
$repos = @($response | ForEach-Object { $_.ssh_url } | Where-Object { $_ })

$total = $repos.Count
if ($total -eq 0) {
    exit 0
}

$counter = [ref]0
$repos | ForEach-Object -Parallel {
    $repoUrl = $_
    $repoName = [System.IO.Path]::GetFileNameWithoutExtension($repoUrl)
    $totalCount = $using:total
    $countRef = $using:counter

    & git clone --quiet $repoUrl
    if ($LASTEXITCODE -eq 0) {
        $done = [System.Threading.Interlocked]::Increment($countRef)
        Write-Output "Clone [$done/$totalCount] $repoName ok"
    }
    else {
        [Console]::Error.WriteLine("Clone $repoName failed")
    }
} -ThrottleLimit 6
