#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Sync and update Node.js version in package.json engines.node for all local workspace projects.
.DESCRIPTION
    Cross-platform workspace engines.node synchronizer for macOS and Windows 11 (PowerShell 7).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @"
unodev: Sync and update Node.js version in package.json engines.node for all local workspace projects
Usage: unodev
"@
}

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        Show-Help
        exit 0
    }
}

function Get-ScriptDirectory {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $cmdArgs = [Environment]::GetCommandLineArgs()
        for ($i = 1; $i -lt $cmdArgs.Count; $i++) {
            $candidate = $cmdArgs[$i]
            if ($candidate -and (-not $candidate.StartsWith('-')) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $scriptPath = $candidate
                break
            }
        }
    }
    if (-not $scriptPath) {
        throw 'Unable to determine script path.'
    }
    $fileInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $scriptPath).Path)
    $targetInfo = $fileInfo.ResolveLinkTarget($true)
    $realPath = $targetInfo ? $targetInfo.FullName : $fileInfo.FullName
    return (Split-Path -Parent $realPath)
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
$currentLocalVersion = [string]$currentLocalVersion
$currentLocalVersion = $currentLocalVersion.Trim()
Write-Output "`nnode: $currentLocalVersion`n"
$nodeVersion = $currentLocalVersion.TrimStart('v')

$scriptDir = Get-ScriptDirectory
$projectsDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir '../..')).Path
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
        $oldVer = ([string]$oldVer).Trim().Trim('"')
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
