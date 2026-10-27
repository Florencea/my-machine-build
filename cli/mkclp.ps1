#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Fast video clip maker supporting local files and YouTube streaming.
.DESCRIPTION
    Cross-platform video clip maker for macOS and Windows 11 (PowerShell 7).
    - Zero-second lossless stream copying (-Copy or compatible local MP4)
    - Hardware-accelerated HEVC (hevc_videotoolbox -tag:v hvc1) on macOS (default Quality: 50)
    - Universal libx264 + AAC fallback on Windows/Linux (default Quality: 23)
    - Uses yt-dlp --download-sections with browser cookies (default: chrome) and automatic cookie-less fallback
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Alias('q')]
    [Nullable[int]]$Quality = $null,

    [Alias('c')]
    [switch]$Copy,

    [Alias('b')]
    [string]$Browser,

    [Alias('o')]
    [string]$Output,

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
mkclp: Clip Maker (Supports --quality [value], --copy, --browser, local files and YouTube videos)
Usage: mkclp [options] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]
Options:
  -q, --quality <num>   Set video quality factor (default: 50 on macOS HEVC, 23 on Windows x264)
  -c, --copy            Force lossless stream copy without re-encoding
  -b, --browser <name>  Browser for YouTube cookies (default: chrome, or `$env:YT_DLP_BROWSER)
  -o, --output <file>   Custom output file path
  -h, --help            Show this help message
Examples:
  mkclp 'input.mp4' 01:02:08 11.0
  mkclp 'input.mp4' 00:00:10 5.0 --copy
  mkclp JoSY6AWKqHs 00:01:59 2 --quality 45
"@
}

$positionals = [System.Collections.Generic.List[string]]::new()
$qualityExplicitlySet = ($null -ne $Quality)

if ($RemainingArgs) {
    for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {
        $arg = $RemainingArgs[$i]
        if ($arg -match '^--?h(elp)?$') {
            $Help = [switch]::new($true)
        }
        elseif ($arg -match '^--?q(uality)?$') {
            if ($i + 1 -ge $RemainingArgs.Count) {
                [Console]::Error.WriteLine('Error: --quality requires a value')
                exit 1
            }
            $Quality = [int]$RemainingArgs[++$i]
            $qualityExplicitlySet = $true
        }
        elseif ($arg -match '^--?c(opy)?$') {
            $Copy = [switch]::new($true)
        }
        elseif ($arg -match '^--?b(rowser)?$') {
            if ($i + 1 -ge $RemainingArgs.Count) {
                [Console]::Error.WriteLine('Error: --browser requires a browser name')
                exit 1
            }
            $Browser = $RemainingArgs[++$i]
        }
        elseif ($arg -match '^--?o(utput)?$') {
            if ($i + 1 -ge $RemainingArgs.Count) {
                [Console]::Error.WriteLine('Error: --output requires a file path')
                exit 1
            }
            $Output = $RemainingArgs[++$i]
        }
        else {
            $positionals.Add($arg)
        }
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if ($positionals.Count -ge 4 -and $positionals[0] -match '^mkclp(\.ps1)?$') {
    $positionals.RemoveAt(0)
}

if ($positionals.Count -lt 3) {
    Show-Help | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}

$InputFile = $positionals[0]
$Start = $positionals[1]
$Duration = $positionals[2]
$effectiveQuality = ($null -ne $Quality) ? [int]$Quality : ($IsMacOS ? 50 : 23)

if ($IsWindows -and (-not (Get-Command 'ffmpeg' -ErrorAction SilentlyContinue) -or -not (Get-Command 'yt-dlp' -ErrorAction SilentlyContinue))) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:PATH = "$userPath;$machinePath;$env:PATH"
}

foreach ($cmd in @('ffmpeg', 'ffprobe')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Error: $cmd is not installed")
        exit 1
    }
}

function Convert-TimeToSeconds {
    param([string]$TimeStr)
    if ($TimeStr -match '^(\d+):(\d{2}):(\d{2}(?:\.\d+)?)$') {
        return [double]$Matches[1] * 3600 + [double]$Matches[2] * 60 + [double]$Matches[3]
    }
    elseif ($TimeStr -match '^(\d+):(\d{2}(?:\.\d+)?)$') {
        return [double]$Matches[1] * 60 + [double]$Matches[2]
    }
    $parsed = 0.0
    if ([double]::TryParse($TimeStr, [ref]$parsed)) {
        return $parsed
    }
    [Console]::Error.WriteLine("Error: Invalid time value '$TimeStr' (expected HH:MM:SS, MM:SS, or seconds).")
    exit 1
}

$isLocal = Test-Path -LiteralPath $InputFile -PathType Leaf
$inputSource = $InputFile
$ffmpegStart = $Start
$tempBase = $null

try {
    if (-not $isLocal) {
        if (-not (Get-Command 'yt-dlp' -ErrorAction SilentlyContinue)) {
            [Console]::Error.WriteLine("Error: File $InputFile does not exist and yt-dlp is not installed")
            exit 1
        }

        $startSec = Convert-TimeToSeconds -TimeStr $Start
        $durSec = [double]$Duration
        $endSec = $startSec + $durSec
        $targetBrowser = $Browser ? $Browser : ($env:YT_DLP_BROWSER ? $env:YT_DLP_BROWSER : 'chrome')

        $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) ("yt_clip_" + [System.Guid]::NewGuid().ToString('N'))
        $ytFormat = 'bestvideo[height<=1080]+bestaudio/best[height<=1080]'

        # Try with browser cookies first (default: chrome), then fallback without cookies
        & yt-dlp --quiet --no-warnings `
            --cookies-from-browser $targetBrowser `
            --force-overwrites `
            --no-playlist `
            --download-sections "*${startSec}-${endSec}" `
            --force-keyframes-at-cuts `
            -f $ytFormat `
            -o "$tempBase.%(ext)s" `
            "$InputFile" 2>$null

        $downloadedFile = (Get-ChildItem -Path "$tempBase.*" -ErrorAction SilentlyContinue | Select-Object -First 1)?.FullName
        if (-not $downloadedFile) {
            & yt-dlp --quiet --no-warnings `
                --force-overwrites `
                --no-playlist `
                --download-sections "*${startSec}-${endSec}" `
                --force-keyframes-at-cuts `
                -f $ytFormat `
                -o "$tempBase.%(ext)s" `
                "$InputFile"

            $downloadedFile = (Get-ChildItem -Path "$tempBase.*" -ErrorAction SilentlyContinue | Select-Object -First 1)?.FullName
        }

        if (-not $downloadedFile) {
            [Console]::Error.WriteLine("Error: Failed to download YouTube video segment for input: $InputFile")
            exit 1
        }

        $inputSource = $downloadedFile
        $ffmpegStart = '0'
    }

    $ffmpegInputs = @('-ss', $ffmpegStart, '-i', $inputSource)
    $mapArgs = @('-map', '0:v:0', '-map', '0:a?')
    $vcArgs = @()

    $format = (& ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$inputSource" 2>$null)
    $codec = (& ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$inputSource" 2>$null)

    if ($Copy -or ($isLocal -and ($format -match 'mp4') -and ($codec -in @('h264', 'hevc')) -and (-not $qualityExplicitlySet))) {
        $vcArgs = @('-c:v', 'copy', '-c:a', 'copy')
    }
    elseif ($IsMacOS) {
        $vcArgs = @(
            '-c:v', 'hevc_videotoolbox',
            '-q:v', "$effectiveQuality",
            '-profile:v', 'main',
            '-pix_fmt', 'yuv420p',
            '-tag:v', 'hvc1',
            '-c:a', 'aac',
            '-b:a', '192k'
        )
    }
    else {
        $vcArgs = @(
            '-c:v', 'libx264',
            '-crf', "$effectiveQuality",
            '-preset', 'fast',
            '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            '-b:a', '192k'
        )
    }

    $outputFile = $Output ? $Output : ((Get-Date -Format 'yyyyMMddHHmmss') + '_clip.mp4')

    & ffmpeg -y -hide_banner `
        -loglevel error `
        @ffmpegInputs `
        -t $Duration `
        @mapArgs `
        @vcArgs `
        -map_chapters -1 `
        -movflags +faststart `
        "$outputFile"

    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: ffmpeg failed with exit code $LASTEXITCODE")
        exit $LASTEXITCODE
    }

    if (Test-Path -LiteralPath $outputFile -PathType Leaf) {
        $size = (Get-Item -LiteralPath $outputFile).Length
        $readableSize = ($size -ge 1MB) ? ('{0:N1}M' -f ($size / 1MB)) : ('{0:N0}K' -f ($size / 1KB))
        Write-Output "$outputFile $readableSize"
    }
}
finally {
    if ($tempBase) {
        Remove-Item -Path "$tempBase.*" -Force -ErrorAction SilentlyContinue
    }
}
