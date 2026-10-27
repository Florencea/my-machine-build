#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Open current build workspace in Visual Studio Code (My Machine Build / My macOS Build).
.DESCRIPTION
    Cross-platform shortcut to open the build repository in Visual Studio Code.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @"
mmb: Open current build workspace in Visual Studio Code
Usage: mmb
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

if (-not (Get-Command 'code' -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Error: code is not installed')
    exit 1
}

$scriptDir = Get-ScriptDirectory
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
& code $repoRoot
