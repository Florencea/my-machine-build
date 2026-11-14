#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Zero-dependency unit and CLI contract test suite for cli/ PowerShell scripts and helpers.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$cliDir = Join-Path $repoRoot 'cli'
$commonModule = Join-Path $cliDir 'helpers' 'CliCommon.psm1'
Import-Module -Name $commonModule -Force

$script:passed = 0
$script:failed = 0

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [bool]$Condition,
        [string]$Detail = ''
    )

    if ($Condition) {
        $script:passed++
    }
    else {
        $script:failed++
        $suffix = $Detail ? " ($Detail)" : ''
        [Console]::Error.WriteLine("[FAIL] ${Name}${suffix}")
    }
}

function Assert-Throw {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    $threw = $false
    try {
        & $Action | Out-Null
    }
    catch {
        $threw = $true
    }
    Assert-Condition -Name $Name -Condition $threw -Detail 'expected exception was not thrown'
}

function Invoke-PwshCaptured {
    param(
        [Parameter(Mandatory)]
        [string[]]$PwshArgs
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath 'pwsh' -ArgumentList $PwshArgs -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $outText = [System.IO.File]::ReadAllText($stdoutFile)
        $errText = [System.IO.File]::ReadAllText($stderrFile)
        return [PSCustomObject]@{
            ExitCode = $proc.ExitCode
            Stdout   = $outText
            Stderr   = $errText
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

# 1. Unit tests for CliCommon.psm1
Assert-Condition -Name 'Convert-TimeToSecond HH:MM:SS.ms' -Condition ([Math]::Abs((Convert-TimeToSecond -TimeText '01:02:03.5') - 3723.5) -lt 0.0001)
Assert-Condition -Name 'Convert-TimeToSecond MM:SS' -Condition ([Math]::Abs((Convert-TimeToSecond -TimeText '02:30') - 150.0) -lt 0.0001)
Assert-Condition -Name 'Convert-TimeToSecond numeric seconds' -Condition ([Math]::Abs((Convert-TimeToSecond -TimeText '12.5') - 12.5) -lt 0.0001)

Assert-Throw -Name 'Convert-TimeToSecond rejects negative' -Action { Convert-TimeToSecond -TimeText '-1' }
Assert-Throw -Name 'Convert-TimeToSecond rejects >=60 seconds' -Action { Convert-TimeToSecond -TimeText '01:60' }
Assert-Throw -Name 'Convert-TimeToSecond rejects non-positive duration' -Action { Convert-TimeToSecond -TimeText '0' -PositiveOnly }
Assert-Throw -Name 'Convert-TimeToSecond rejects invalid text' -Action { Convert-TimeToSecond -TimeText 'not-a-time' }

Assert-Condition -Name 'ConvertTo-ValidatedInt valid' -Condition ((ConvertTo-ValidatedInt -Value '50' -OptionName '--quality' -MinValue 0 -MaxValue 100) -eq 50)
Assert-Throw -Name 'ConvertTo-ValidatedInt rejects non-int' -Action { ConvertTo-ValidatedInt -Value 'abc' -OptionName '--quality' -MinValue 0 -MaxValue 100 }
Assert-Throw -Name 'ConvertTo-ValidatedInt rejects out-of-range' -Action { ConvertTo-ValidatedInt -Value '101' -OptionName '--quality' -MinValue 0 -MaxValue 100 }

Assert-Condition -Name 'Format-ByteSize KB' -Condition ((Format-ByteSize -ByteCount 1024) -eq '1K')
Assert-Condition -Name 'Format-ByteSize MB' -Condition ((Format-ByteSize -ByteCount 1572864) -eq '1.5M')
Assert-Condition -Name 'Format-ByteSize GB' -Condition ((Format-ByteSize -ByteCount 2147483648) -eq '2.0G')

Assert-Condition -Name 'Test-RequiredCommand finds pwsh' -Condition (Test-RequiredCommand -Name 'pwsh' -Quiet)
Assert-Condition -Name 'Test-RequiredCommand returns false for missing command' -Condition (-not (Test-RequiredCommand -Name 'nonexistent-cmd-xyz-999' -Quiet))

# 2. Symlink resolution test via temporary extensionless symlink
$tempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) ('mmb_test_' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempTestDir | Out-Null

try {
    $symlinkPath = Join-Path $tempTestDir 'mmb_link'
    $targetScript = Join-Path $cliDir 'mmb.ps1'
    $linkCreated = $false
    try {
        New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $targetScript -ErrorAction Stop | Out-Null
        $linkCreated = $true
    }
    catch {
        $linkCreated = $false
    }

    if ($linkCreated) {
        $resolvedDir = Resolve-CliScriptDirectory -CommandPath $symlinkPath
        Assert-Condition -Name 'Resolve-CliScriptDirectory resolves symlink target' -Condition ($resolvedDir -eq $cliDir) -Detail "got '$resolvedDir'"

        $symHelp = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', $symlinkPath, '--help')
        Assert-Condition -Name 'Extensionless symlink --help exits 0' -Condition ($symHelp.ExitCode -eq 0) -Detail "exit $($symHelp.ExitCode): $($symHelp.Stderr)"
        Assert-Condition -Name 'Extensionless symlink --help prints usage' -Condition ($symHelp.Stdout -match 'mmb:')
    }

    # 3. Contract tests for all cli/*.ps1 scripts (--help and unknown option rejection)
    $cliScripts = @(Get-ChildItem -LiteralPath $cliDir -Filter '*.ps1' -File | Sort-Object Name)
    foreach ($scriptFile in $cliScripts) {
        $cmdName = $scriptFile.BaseName
        $helpRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', $scriptFile.FullName, '--help')
        Assert-Condition -Name "$($scriptFile.Name) --help exit 0" -Condition ($helpRes.ExitCode -eq 0) -Detail "exit $($helpRes.ExitCode): $($helpRes.Stderr)"
        Assert-Condition -Name "$($scriptFile.Name) --help outputs usage" -Condition ($helpRes.Stdout -match [regex]::Escape($cmdName))

        $badRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', $scriptFile.FullName, '--unknown-flag-test')
        Assert-Condition -Name "$($scriptFile.Name) rejects unknown option" -Condition ($badRes.ExitCode -ne 0) -Detail 'expected non-zero exit'
        Assert-Condition -Name "$($scriptFile.Name) writes unknown option error to stderr" -Condition ($badRes.Stderr -match 'Unknown option')
    }

    # 4. rea.ps1 safety guard: refuse deleting directory with multiple .mkv files
    if (Get-Command 'ffmpeg' -ErrorAction SilentlyContinue) {
        $reaDir = Join-Path $tempTestDir 'multi_mkv'
        New-Item -ItemType Directory -Force -Path $reaDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $reaDir 'a.mkv'), '')
        [System.IO.File]::WriteAllText((Join-Path $reaDir 'b.mkv'), '')
        [System.IO.File]::WriteAllText((Join-Path $reaDir 'a.cht.ass'), '')

        $reaRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', (Join-Path $cliDir 'rea.ps1'), $reaDir)
        Assert-Condition -Name 'rea.ps1 rejects directory with multiple mkv files' -Condition ($reaRes.ExitCode -ne 0)
        Assert-Condition -Name 'rea.ps1 outputs multiple mkv error' -Condition ($reaRes.Stderr -match 'Multiple \.mkv files')
        Assert-Condition -Name 'rea.ps1 preserves directory when aborted' -Condition (Test-Path -LiteralPath $reaDir -PathType Container)
    }

    # 5. webread.ps1 rejects invalid --max-chars cleanly
    $webreadBadMax = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', (Join-Path $cliDir 'webread.ps1'), '--max-chars', 'abc', 'https://example.com')
    Assert-Condition -Name 'webread.ps1 rejects non-integer --max-chars' -Condition ($webreadBadMax.ExitCode -ne 0)
    Assert-Condition -Name 'webread.ps1 reports --max-chars validation error' -Condition ($webreadBadMax.Stderr -match 'Invalid integer for --max-chars')
}
finally {
    if (Test-Path -LiteralPath $tempTestDir) {
        Remove-Item -LiteralPath $tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "PowerShell tests: $($script:passed) passed, $($script:failed) failed"
if ($script:failed -gt 0) {
    exit 1
}
