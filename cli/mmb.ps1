#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Open current build workspace in Visual Studio Code (My Machine Build / My macOS Build).
.DESCRIPTION
    Cross-platform shortcut to open the build repository in Visual Studio Code.
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
mmb: Open current build workspace in Visual Studio Code
Usage: mmb
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

if (-not (Get-Command 'code' -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Error: code is not installed')
    exit 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& code $repoRoot
