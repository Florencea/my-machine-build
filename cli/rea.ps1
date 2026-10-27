#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    ASS-Combiner: combine .cht.ass into original mkv as default subtitle track, move up, and clean up directory.
.DESCRIPTION
    Cross-platform MKV subtitle combiner for macOS and Windows 11 (PowerShell 7).
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
rea: ASS-Combiner: combine .cht.ass into original mkv as default subtitle track
Usage: rea [input_dir]
       rea 'input'
"@
}

$InputDir = ''
if ($RemainingArgs) {
    foreach ($arg in $RemainingArgs) {
        if ($arg -match '^--?h(elp)?$') {
            $Help = [switch]::new($true)
        }
        elseif (-not $InputDir) {
            $InputDir = $arg
        }
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not $InputDir) {
    [Console]::Error.WriteLine('rea: ASS-Combiner: combine .cht.ass into original mkv as default subtitle track, move up, and clean up directory')
    [Console]::Error.WriteLine('Usage: rea [input_dir]')
    [Console]::Error.WriteLine("       rea 'input'")
    exit 1
}

if (-not (Get-Command 'ffmpeg' -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Error: ffmpeg is not installed')
    exit 1
}

if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
    [Console]::Error.WriteLine("Error: Directory $InputDir does not exist")
    exit 1
}

$absInputDir = (Resolve-Path -LiteralPath $InputDir).Path
$inputBase = Split-Path -Leaf $absInputDir
$parentDir = Split-Path -Parent $absInputDir
$rootPath = [System.IO.Path]::GetPathRoot($absInputDir)

if (-not $absInputDir -or ($absInputDir -eq $rootPath) -or (-not $parentDir)) {
    [Console]::Error.WriteLine('Error: Input directory cannot be root or empty')
    exit 1
}

$mkvFiles = @(Get-ChildItem -LiteralPath $absInputDir -Filter '*.mkv' -File)
if ($mkvFiles.Count -eq 0) {
    [Console]::Error.WriteLine("Error: No .mkv file found in $InputDir")
    exit 1
}

$allAssFiles = @(Get-ChildItem -LiteralPath $absInputDir -Filter '*.ass' -File)
if ($allAssFiles.Count -eq 0) {
    [Console]::Error.WriteLine("Error: No .ass subtitle file found in $InputDir")
    exit 1
}

$preferredAss = @($allAssFiles | Where-Object { $_.Name -match '(?i)(cht|tc|zh-tw)' })
$inputFile = $mkvFiles[0].FullName
$inputAssTw = ($preferredAss.Count -gt 0) ? $preferredAss[0].FullName : $allAssFiles[0].FullName

$tmpFile = Join-Path $parentDir ".tmp_rea_${PID}.mkv"
$outputFile = Join-Path $parentDir "${inputBase}.mkv"

try {
    & ffmpeg -y `
        -hide_banner `
        -loglevel error `
        -sn `
        -i "$inputFile" `
        -i "$inputAssTw" `
        -map 0:v:0 `
        -map '0:a:0?' `
        -map 1:s:0 `
        -c copy `
        -disposition:s:0 default `
        -metadata:s:s:0 language=chi `
        -metadata:s:s:0 title='繁體中文' `
        "$tmpFile"

    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: ffmpeg failed with exit code $LASTEXITCODE")
        exit $LASTEXITCODE
    }

    Move-Item -LiteralPath $tmpFile -Destination $outputFile -Force
    Remove-Item -LiteralPath $absInputDir -Recurse -Force

    $size = (Get-Item -LiteralPath $outputFile).Length
    $readableSize = ($size -ge 1GB) ? ('{0:N1}G' -f ($size / 1GB)) : (($size -ge 1MB) ? ('{0:N1}M' -f ($size / 1MB)) : ('{0:N0}K' -f ($size / 1KB)))
    Write-Output "$(Split-Path -Leaf $outputFile) $readableSize ok"
}
finally {
    if (Test-Path -LiteralPath $tmpFile) {
        Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
    }
}
