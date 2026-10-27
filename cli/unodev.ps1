#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Sync and update Node.js version in package.json engines.node for all local workspace projects.
.DESCRIPTION
    Cross-platform workspace engines.node synchronizer for macOS and Windows 11 (PowerShell 7).
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
unodev: Sync and update Node.js version in package.json engines.node for all local workspace projects
Usage: unodev
"@
}

if ($RemainingArgs) {
    foreach ($arg in $RemainingArgs) {
        if ($arg -match '^--?h(elp)?$') {
            $Help = [switch]::new($true)
        }
    }
}

if ($Help) {
    Show-Help
    exit 0
}

foreach ($cmd in @('git', 'vp')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Error: $cmd is not installed")
        exit 1
    }
}

$env:VP_LOG = 'error'
$currentLocalVersion = (& vp node -v 2>$null)
if (-not $currentLocalVersion) {
    $currentLocalVersion = (& node -v 2>$null)
}
$currentLocalVersion = $currentLocalVersion.Trim()
Write-Output "`nnode: $currentLocalVersion`n"
$nodeVersion = $currentLocalVersion.TrimStart('v')

$projectsDir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$projects = @(Get-ChildItem -Directory -LiteralPath $projectsDir | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'package.json') -PathType Leaf)
    })

$projects | ForEach-Object -Parallel {
    $projDir = $_.FullName
    $projName = $_.Name
    $targetVer = $using:nodeVersion
    $env:VP_LOG = 'error'

    $oldVer = (& vp -C $projDir pm pkg get engines.node 2>$null)
    if ($oldVer) {
        $oldVer = $oldVer.Trim().Trim('"')
    }

    if ($oldVer -ne $targetVer) {
        & vp -C $projDir pm pkg set "engines.node=$targetVer" >$null 2>&1
        $status = (& git -C $projDir status --short package.json 2>$null)
        if ($status) {
            & git -C $projDir add package.json
            & git -C $projDir commit -q -m "chore(node): Update engines.node $oldVer -> $targetVer"
            if ($LASTEXITCODE -eq 0) {
                & git -C $projDir push -q >$null 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Output "engines.node ${projName}: $oldVer -> $targetVer ok"
                }
                else {
                    [Console]::Error.WriteLine("engines.node ${projName}: failed to push")
                }
            }
        }
    }
    else {
        Write-Output "engines.node ${projName}: $oldVer ok"
    }
} -ThrottleLimit 6
