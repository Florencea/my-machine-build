#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Backup and sync browser extension configuration files from Downloads to configs/.
.DESCRIPTION
    Cross-platform browser extension config backup script for macOS and Windows 11 (PowerShell 7).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @"
ebk: Backup and sync browser extension configuration files
Usage: ebk
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

foreach ($cmd in @('git', 'jq')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Error: $cmd is not installed")
        exit 1
    }
}

$scriptDir = Get-ScriptDirectory
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
$configHome = Join-Path $repoRoot 'configs'
$downloadsDir = Join-Path $HOME 'Downloads'
$script:needPush = $false

function Save-CommitFile {
    param([string]$FileName)
    & git -C $configHome add $FileName
    $status = (& git -C $configHome status --porcelain -- $FileName)
    if ($status) {
        & git -C $configHome commit -q -m "feat: Update $FileName by ebk"
        Write-Output "Backup $FileName ok"
        $script:needPush = $true
    }
    else {
        Write-Output "Backup $FileName ok (unchanged)"
    }
}

function Backup-RawFile {
    param([string]$Pattern, [string]$TargetName)
    $matches = @(Get-ChildItem -Path (Join-Path $downloadsDir $Pattern) -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($matches.Count -gt 0) {
        $latest = $matches[0].FullName
        $dest = Join-Path $configHome $TargetName
        Move-Item -LiteralPath $latest -Destination $dest -Force
        if ($matches.Count -gt 1) {
            foreach ($old in $matches[1..($matches.Count - 1)]) {
                Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        Save-CommitFile -FileName $TargetName
    }
}

function Backup-JsonFile {
    param([string]$Pattern, [string]$TargetName)
    $matches = @(Get-ChildItem -Path (Join-Path $downloadsDir $Pattern) -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($matches.Count -gt 0) {
        $latest = $matches[0].FullName
        $dest = Join-Path $configHome $TargetName
        $formatted = @(& jq . $latest 2>$null)
        if ($LASTEXITCODE -eq 0 -and $formatted.Count -gt 0) {
            [System.IO.File]::WriteAllText($dest, ($formatted -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
        }
        else {
            Move-Item -LiteralPath $latest -Destination $dest -Force
        }
        foreach ($m in $matches) {
            if (Test-Path -LiteralPath $m.FullName) {
                Remove-Item -LiteralPath $m.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        Save-CommitFile -FileName $TargetName
    }
}

Backup-RawFile -Pattern 'my-ublock-backup*.txt' -TargetName 'ubo-config.txt'
Backup-JsonFile -Pattern 'my-ubol-settings*.json' -TargetName 'ubol-config.json'
Backup-JsonFile -Pattern 'immersive-translate-config*.json' -TargetName 'immersive-translate-config.json'
Backup-JsonFile -Pattern 'tampermonkey-backup*.*' -TargetName 'tampermonkey.json'
Backup-JsonFile -Pattern 'tongwentang*.json' -TargetName 'tongwentang.json'
Backup-JsonFile -Pattern 'stylus*.json' -TargetName 'stylus.json'

if ($script:needPush) {
    & git -C $configHome push -q
}
