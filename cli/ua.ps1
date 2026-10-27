#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Upgrade system packages (Homebrew on macOS / winget on Windows), update Node.js (Active LTS via Vite+), and parallel-sync all Git repositories in the workspace.
.DESCRIPTION
    Cross-platform system & workspace updater for macOS and Windows 11 (PowerShell 7).
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$SkipBrew,
    [switch]$SkipWinget,
    [switch]$SkipVite,
    [switch]$SkipGit,

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
ua: Upgrade system packages (Homebrew / winget), update Node.js (Active LTS via Vite+), and sync git repositories
Usage: ua [options]
Options:
  --skip-brew     Skip Homebrew upgrade (macOS)
  --skip-winget   Skip winget upgrade (Windows)
  --skip-vite     Skip Vite+ and Node.js LTS update
  --skip-git      Skip workspace Git repositories sync
  -h, --help      Show this help message
"@
}

if ($RemainingArgs) {
    foreach ($arg in $RemainingArgs) {
        if ($arg -match '^--?h(elp)?$') { $Help = [switch]::new($true) }
        elseif ($arg -match '^--?skip-?brew$') { $SkipBrew = [switch]::new($true) }
        elseif ($arg -match '^--?skip-?winget$') { $SkipWinget = [switch]::new($true) }
        elseif ($arg -match '^--?skip-?vite$') { $SkipVite = [switch]::new($true) }
        elseif ($arg -match '^--?skip-?git$') { $SkipGit = [switch]::new($true) }
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if ($IsWindows) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:PATH = "$userPath;$machinePath;$env:PATH"
}

$PROJECTS_DIR = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

# 1. Upgrade OS Packages
if ($IsMacOS -and (-not $SkipBrew)) {
    if (-not (Get-Command 'brew' -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine('Error: brew is not installed')
        exit 1
    }
    Push-Location $HOME
    try {
        $env:HOMEBREW_NO_ENV_HINTS = '1'
        $env:HOMEBREW_NO_ASK = '1'
        $env:HOMEBREW_AUTO_UPDATE_QUIET = '1'
        $env:HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS = '1'
        & brew upgrade
        & brew cleanup
    }
    finally {
        Pop-Location
    }
}
elseif ($IsWindows -and (-not $SkipWinget)) {
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        & winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
    }
}

# 2. Update Node.js & Vite+ Toolchain (Active LTS via vp)
if (-not $SkipVite) {
    if (-not (Get-Command 'vp' -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine('Error: vp is not installed')
        exit 1
    }

    & vp upgrade
    $oldNode = (& vp node -v 2>$null)
    $installOut = (& vp env install lts 2>&1)
    $newNode = (& vp node -v 2>$null)

    if ($oldNode -and ($oldNode -ne $newNode)) {
        Write-Output $installOut
        & vp env clean 2>&1 | Out-Null
    }

    $legacyNodeDir = Join-Path $HOME '.local/opt/node'
    if ($IsMacOS -and (Test-Path -LiteralPath $legacyNodeDir)) {
        Remove-Item -Path (Join-Path $HOME '.local/opt/node*') -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Output "`nnode: $newNode`n"
}

# 3. Sync Git projects in workspace in parallel
if (-not $SkipGit) {
    $repos = @(Get-ChildItem -Directory -LiteralPath $PROJECTS_DIR | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName '.git')
    })

    $total = $repos.Count
    if ($total -gt 0) {
        $results = @($repos | ForEach-Object -Parallel {
            $dir = $_.FullName
            $name = $_.Name
            $pullOut = @(& git -C $dir pull --all 2>&1)
            $isSuccess = ($LASTEXITCODE -eq 0)
            $outText = $pullOut -join "`n"
            $isUpdated = ($outText -match 'Updating |Fast-forward')

            [PSCustomObject]@{
                Name    = $name
                Success = $isSuccess
                Updated = $isUpdated
                Output  = $outText
            }
        } -ThrottleLimit 6)

        $updatedCount = @($results | Where-Object { $_.Updated }).Count
        $failedCount = @($results | Where-Object { -not $_.Success }).Count

        foreach ($res in $results) {
            if (-not $res.Success) {
                [Console]::Error.WriteLine("Sync $($res.Name) failed")
            }
            elseif ($res.Updated) {
                Write-Output "Sync $($res.Name) updated"
            }
        }

        if ($failedCount -eq 0) {
            if ($updatedCount -eq 0) {
                Write-Output "Sync workspace repositories ok ($total projects up to date)"
            }
            else {
                $upToDate = $total - $updatedCount
                Write-Output "Sync workspace repositories ok ($updatedCount updated, $upToDate up to date)"
            }
        }
    }
}
