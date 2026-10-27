#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    High-quality GIF maker supporting local video files and YouTube streaming.
.DESCRIPTION
    Cross-platform GIF maker for macOS and Windows 11 (PowerShell 7).
    - Generates high-quality animated GIFs from local videos or YouTube URLs
    - Uses yt-dlp --download-sections with browser cookies (default: chrome) and cookie-less fallback
    - Uses gifski via yuv4mpegpipe when available, or FFmpeg 256-color diff palette + Bayer dithering fallback
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Alias('w')]
    [int]$Width = 720,

    [int]$Fps = 10,

    [Alias('q')]
    [int]$Quality = 70,

    [Alias('l')]
    [switch]$Lossy,

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
mkgif: High-quality Gif Maker via gifski / FFmpeg palette
Usage: mkgif [-w 720] [--fps 10] [-q 70] [-l] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]
Options:
  -w, --width <num>     Output gif width in pixels (default: 720)
  --fps <num>           Frame rate per second (default: 10)
  -q, --quality <num>   Gifski encoding quality 1-100 (default: 70)
  -l, --lossy           Enable lossy optimization
  -b, --browser <name>  Browser for YouTube cookies (default: chrome, or `$env:YT_DLP_BROWSER)
  -o, --output <file>   Custom output file path
  -h, --help            Show this help message
Examples:
  mkgif 'input.mp4' 01:02:08 11.0
  mkgif JoSY6AWKqHs 00:01:59 20 --fps 10 -w 720
"@
}

$positionals = [System.Collections.Generic.List[string]]::new()

if ($RemainingArgs) {
    for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {
        $arg = $RemainingArgs[$i]
        if ($arg -match '^--?h(elp)?$') {
            $Help = [switch]::new($true)
        }
        elseif ($arg -match '^--?fps$') {
            if ($i + 1 -ge $RemainingArgs.Count) {
                [Console]::Error.WriteLine('Error: --fps requires a value')
                exit 1
            }
            $Fps = [int]$RemainingArgs[++$i]
        }
        elseif ($arg -match '^--?w(idth)?$') {
            if ($i + 1 -ge $RemainingArgs.Count) {
                [Console]::Error.WriteLine('Error: -w/--width requires a value')
                exit 1
            }
            $Width = [int]$RemainingArgs[++$i]
        }
        elseif ($arg -match '^--?q(uality)?$') {
            if ($i + 1 -ge $RemainingArgs.Count) {
                [Console]::Error.WriteLine('Error: -q/--quality requires a value')
                exit 1
            }
            $Quality = [int]$RemainingArgs[++$i]
        }
        elseif ($arg -match '^--?l(ossy)?$') {
            $Lossy = [switch]::new($true)
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
                [Console]::Error.WriteLine('Error: -o/--output requires a file path')
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

if ($positionals.Count -lt 3) {
    Show-Help | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}

$InputFile = $positionals[0]
$Start = $positionals[1]
$Duration = $positionals[2]

if ($IsWindows -and (-not (Get-Command 'ffmpeg' -ErrorAction SilentlyContinue) -or -not (Get-Command 'yt-dlp' -ErrorAction SilentlyContinue))) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:PATH = "$userPath;$machinePath;$env:PATH"
}

if (-not (Get-Command 'ffmpeg' -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Error: ffmpeg is not installed')
    exit 1
}

function Convert-TimeToSeconds {
    param([string]$TimeStr)
    if ($TimeStr -match '^(\d+):(\d{2}):(\d{2}(?:\.\d+)?)$') {
        return [double]$Matches[1] * 3600 + [double]$Matches[2] * 60 + [double]$Matches[3]
    }
    elseif ($TimeStr -match '^(\d+):(\d{2}(?:\.\d+)?)$') {
        return [double]$Matches[1] * 60 + [double]$Matches[2]
    }
    return [double]$TimeStr
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
        $ytHeight = ($Width -le 480) ? 480 : (($Width -le 720) ? 720 : (($Width -le 1280) ? 1080 : 2160))
        $targetBrowser = $Browser ? $Browser : ($env:YT_DLP_BROWSER ? $env:YT_DLP_BROWSER : 'chrome')

        $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) ("yt_gif_" + [System.Guid]::NewGuid().ToString('N'))
        $ytFormat = "bestvideo[height<=$ytHeight]/best[height<=$ytHeight]/bestvideo/best"

        # Try with browser cookies first (default: chrome), then fallback without cookies
        & yt-dlp --quiet --no-warnings `
            --cookies-from-browser $targetBrowser `
            --force-overwrites `
            --no-playlist `
            --download-sections "*${startSec}-${endSec}" `
            -f $ytFormat `
            -o "$tempBase.%(ext)s" `
            "$InputFile" 2>$null

        $downloadedFile = (Get-ChildItem -Path "$tempBase.*" -ErrorAction SilentlyContinue | Select-Object -First 1)?.FullName
        if (-not $downloadedFile) {
            & yt-dlp --quiet --no-warnings `
                --force-overwrites `
                --no-playlist `
                --download-sections "*${startSec}-${endSec}" `
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

    $outputFile = $Output ? $Output : ((Get-Date -Format 'yyyyMMddHHmmss') + "_fps${Fps}.gif")

    # Detect CLI-capable gifski binary
    $gifskiCmd = Get-Command 'gifski' -ErrorAction SilentlyContinue
    $hasGifskiCli = $false

    if ($gifskiCmd) {
        if ($IsWindows) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($gifskiCmd.Source)
                $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
                $subsystem = [BitConverter]::ToUInt16($bytes, $peOffset + 0x5C)
                if ($subsystem -eq 3) {
                    $hasGifskiCli = $true
                }
            }
            catch {}
        }
        else {
            $hasGifskiCli = $true
        }
    }

    if ($hasGifskiCli) {
        $lossyArg = $Lossy ? '--lossy-quality 75' : ''
        $cmdLine = "ffmpeg -y -hide_banner -loglevel error -ss $ffmpegStart -i `"$inputSource`" -t $Duration -vf `"fps=$Fps,scale=${Width}:-2:flags=lanczos,format=yuv420p`" -f yuv4mpegpipe - | gifski -q -Q $Quality -W $Width $lossyArg -o `"$outputFile`" -"
        if ($IsWindows) {
            & cmd.exe /c $cmdLine
        }
        else {
            & sh -c $cmdLine
        }
    }
    else {
        & ffmpeg -y -hide_banner -loglevel error `
            -ss $ffmpegStart `
            -i "$inputSource" `
            -t $Duration `
            -filter_complex "[0:v] fps=$Fps,scale=${Width}:-1:flags=lanczos,split [a][b];[a] palettegen=max_colors=256:stats_mode=diff [p];[b][p] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" `
            "$outputFile"
    }

    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: GIF generation failed with exit code $LASTEXITCODE")
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
