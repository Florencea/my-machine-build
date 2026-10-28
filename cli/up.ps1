#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Check and update Node.js / Vite+ package dependencies with automated verification and rollback.
.DESCRIPTION
    Cross-platform Node.js dependency updater for macOS and Windows 11 (PowerShell 7).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Help {
    Write-Output @'
up: Check and update Node.js package dependencies with clean spinner feedback
Usage: up
'@
}

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        Show-Help
        exit 0
    }
}

foreach ($cmd in @('git', 'jq', 'vp', 'vpr', 'vpx', 'yq')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Error: $cmd is not installed")
        exit 1
    }
}

if (-not (Test-Path -LiteralPath 'package.json' -PathType Leaf)) {
    [Console]::Error.WriteLine('Error: File package.json does not exist')
    exit 1
}

$currentBranch = ([string](& git rev-parse --abbrev-ref HEAD 2>$null)).Trim()
if ($currentBranch -ne 'main') {
    [Console]::Error.WriteLine("Error: Current branch is not 'main' ($currentBranch)")
    exit 1
}

$gitStatus = (& git status --porcelain 2>$null)
if ($gitStatus) {
    [Console]::Error.WriteLine('Error: Working directory is not clean. Please commit or stash your changes first.')
    exit 1
}

& git rev-parse --abbrev-ref '@{u}' >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    & git pull --ff-only --quiet
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine('Error: Cannot fast-forward with remote. Please sync your branch first.')
        exit 1
    }
}

function Invoke-Step {
    param(
        [string]$Message,
        [string]$Exe,
        [string[]]$Arguments = @()
    )
    $Arguments = $Arguments ?? @()
    $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $frameIdx = 0

    $prevLog = $env:VP_LOG
    $env:VP_LOG = 'error'

    $job = Start-ThreadJob -ScriptBlock {
        param($cmdExe, [string[]]$cmdArgs)
        try {
            $output = @(& $cmdExe @cmdArgs 2>&1)
            [PSCustomObject]@{
                Output   = $output
                ExitCode = ($LASTEXITCODE ?? 0)
            }
        }
        catch {
            [PSCustomObject]@{
                Output   = @($_.ToString())
                ExitCode = 1
            }
        }
    } -ArgumentList @($Exe, $Arguments)

    try {
        Write-Host -NoNewline "`e[?25l`r  $($frames[$frameIdx]) $Message..."
        $frameIdx = ($frameIdx + 1) % $frames.Count

        while (-not $job.Finished.WaitOne(80)) {
            Write-Host -NoNewline "`r  $($frames[$frameIdx]) $Message..."
            $frameIdx = ($frameIdx + 1) % $frames.Count
        }

        $res = Receive-Job -Job $job
        $resObj = ($res -is [array]) ? $res[-1] : $res
        $output = @()
        $code = 0
        if ($null -ne $resObj) {
            $output = $resObj.Output ?? @()
            $code = [int]($resObj.ExitCode ?? 0)
        }
        else {
            $code = 1
            $output = @("Step '$Message' terminated unexpectedly.")
        }

        Write-Host -NoNewline "`r`e[K"
        if ($code -ne 0) {
            foreach ($line in $output) {
                [Console]::Error.WriteLine($line)
            }
            throw "Step failed with exit code $code"
        }
    }
    finally {
        Write-Host -NoNewline "`e[?25h"
        if ($null -ne $job) {
            if ($job.JobStateInfo.State -eq [System.Management.Automation.JobState]::Running) {
                Stop-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        $env:VP_LOG = $prevLog
    }
}

$pkgJson = Get-Content -LiteralPath 'package.json' -Raw | ConvertFrom-Json -AsHashtable
$deps = $pkgJson['dependencies'] ?? @{}
$devDeps = $pkgJson['devDependencies'] ?? @{}
$peerDeps = $pkgJson['peerDependencies'] ?? @{}
$optDeps = $pkgJson['optionalDependencies'] ?? @{}
$scriptsMap = $pkgJson['scripts'] ?? @{}

$isVitePlus = $deps.ContainsKey('vite-plus') -or $devDeps.ContainsKey('vite-plus')
$vpToolchainUpgraded = $false
$vpOldVer = ''
$vpNewVer = ''

if ($isVitePlus) {
    $vpVerOut = @(& vp --version 2>$null)
    $globalVpVer = ''
    foreach ($line in $vpVerOut) {
        if ($line -match '^vp v([^\s]+)') {
            $globalVpVer = $Matches[1]
            break
        }
    }

    $localVpVer = $deps['vite-plus'] ?? $devDeps['vite-plus'] ?? ''
    if ($localVpVer -eq 'catalog:' -and (Test-Path -LiteralPath 'pnpm-workspace.yaml' -PathType Leaf)) {
        $localVpVer = ([string](& yq '.catalog.vite-plus // .catalogs.default.vite-plus // ""' pnpm-workspace.yaml 2>$null)).Trim()
    }

    if ($globalVpVer -and $localVpVer -and ($localVpVer -ne $globalVpVer)) {
        $vpToolchainUpgraded = $true
        $vpOldVer = $localVpVer
        $vpNewVer = $globalVpVer
    }
}

$ncuRaw = (& vpx -s npm-check-updates@latest -t minor --install never --jsonUpgraded 2>$null) -join "`n"
$ncuMap = @{}
if ($ncuRaw -and $ncuRaw.Trim() -notin @('', '{}')) {
    $ncuMap = $ncuRaw | ConvertFrom-Json -AsHashtable
}

if ((-not $isVitePlus -or -not $vpToolchainUpgraded) -and ($ncuMap.Count -eq 0)) {
    exit 0
}

$count = 0
$commitBodyLines = [System.Collections.Generic.List[string]]::new()
$singlePkgSummary = ''
$hasVitePlusInTargets = $false

foreach ($pkg in $ncuMap.Keys) {
    $newVer = $ncuMap[$pkg]
    $oldVer = $deps[$pkg] ?? $devDeps[$pkg] ?? $peerDeps[$pkg] ?? $optDeps[$pkg] ?? '?'
    if ($pkg -eq 'vite-plus') {
        $hasVitePlusInTargets = $true
    }
    Write-Output "  $pkg  $oldVer  ->  $newVer"
    $commitBodyLines.Add("- ${pkg}: ${oldVer} -> ${newVer}")
    $singlePkgSummary = "$pkg $oldVer -> $newVer"
    $count++
}

if ($vpToolchainUpgraded -and (-not $hasVitePlusInTargets)) {
    Write-Output "  vite-plus  $vpOldVer  ->  $vpNewVer"
    $commitBodyLines.Add("- vite-plus: ${vpOldVer} -> ${vpNewVer}")
    $singlePkgSummary = "vite-plus $vpOldVer -> $vpNewVer"
    $count++
}

$tempBranch = "chore/deps-upgrade-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
& git checkout -q -b $tempBranch
$failedStep = 'Verification'

try {
    if ($isVitePlus) {
        $failedStep = 'vp migrate --no-interactive'
        Invoke-Step -Message 'Aligning Vite+ toolchain (vp migrate)' -Exe 'vp' -Arguments @('migrate', '--no-interactive')

        if ($ncuMap.Count -gt 0) {
            $failedStep = 'vpx npm-check-updates'
            Invoke-Step -Message 'Updating packages (NCU)' -Exe 'vpx' -Arguments @('-s', 'npm-check-updates@latest', '-u', '-t', 'minor')
        }

        $failedStep = 'vp pm pkg fix'
        Invoke-Step -Message 'Normalizing manifest (vp pm pkg fix)' -Exe 'vp' -Arguments @('pm', 'pkg', 'fix')

        $failedStep = 'vp install'
        Invoke-Step -Message 'Syncing dependencies (vp install)' -Exe 'vp' -Arguments @('install')

        $failedStep = 'vp install (frozen verification)'
        Invoke-Step -Message 'Verifying frozen lockfile' -Exe 'vp' -Arguments @('install', '--frozen-lockfile')
    }
    else {
        if ($ncuMap.Count -gt 0) {
            $failedStep = 'vpx npm-check-updates'
            Invoke-Step -Message 'Updating packages (NCU)' -Exe 'vpx' -Arguments @('-s', 'npm-check-updates@latest', '-u', '-t', 'minor')
        }

        $failedStep = 'vp pm pkg fix'
        Invoke-Step -Message 'Normalizing manifest (vp pm pkg fix)' -Exe 'vp' -Arguments @('pm', 'pkg', 'fix')

        if (Test-Path -LiteralPath 'node_modules' -PathType Container) {
            Move-Item -LiteralPath 'node_modules' -Destination '.node_modules.bak' -Force
        }
        Remove-Item -LiteralPath 'package-lock.json' -Force -ErrorAction SilentlyContinue

        $failedStep = 'vp install (lockfile update)'
        Invoke-Step -Message 'Writing lockfile' -Exe 'vp' -Arguments @('install', '--lockfile-only', '--ignore-scripts')

        $failedStep = 'vp install'
        Invoke-Step -Message 'Syncing dependencies (vp install)' -Exe 'vp' -Arguments @('install', '--frozen-lockfile')
        Remove-Item -LiteralPath '.node_modules.bak' -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Re-read package.json scripts after migration/update
    $pkgJson = Get-Content -LiteralPath 'package.json' -Raw | ConvertFrom-Json -AsHashtable
    $deps = $pkgJson['dependencies'] ?? @{}
    $devDeps = $pkgJson['devDependencies'] ?? @{}
    $scriptsMap = $pkgJson['scripts'] ?? @{}

    $failedStep = 'vp fmt'
    Invoke-Step -Message 'Formatting code & configs (vp fmt)' -Exe 'vp' -Arguments @('fmt')

    $failedStep = 'vp check'
    Invoke-Step -Message 'Checking quality & lint (vp check)' -Exe 'vp' -Arguments @('check', '--quiet', '--no-error-on-unmatched-pattern')

    foreach ($s in @('lint:tailwind', 'agent:lint:ci')) {
        if ($scriptsMap.ContainsKey($s)) {
            $failedStep = "vpr $s (lint)"
            Invoke-Step -Message 'Verifying additional lint rules' -Exe 'vpr' -Arguments @($s)
            break
        }
    }

    $hasTypecheck = $false
    foreach ($s in @('agent:typecheck', 'typecheck')) {
        if ($scriptsMap.ContainsKey($s)) {
            $hasTypecheck = $true
            $failedStep = "vpr $s (typecheck)"
            Invoke-Step -Message 'Verifying types' -Exe 'vpr' -Arguments @($s)
            break
        }
    }

    if (-not $hasTypecheck -and ($deps.ContainsKey('typescript') -or $devDeps.ContainsKey('typescript'))) {
        $failedStep = 'vpx tsc --noEmit'
        Invoke-Step -Message 'Verifying types' -Exe 'vpx' -Arguments @('tsc', '--noEmit')
    }

    foreach ($s in @('check:deadcode', 'knip')) {
        if ($scriptsMap.ContainsKey($s)) {
            $failedStep = "vpr $s (deadcode)"
            Invoke-Step -Message 'Verifying dead code' -Exe 'vpr' -Arguments @($s)
            break
        }
    }

    foreach ($s in @('agent:verify:unit', 'agent:test:unit', 'test:unit')) {
        if ($scriptsMap.ContainsKey($s)) {
            $failedStep = "vpr $s (unit-test)"
            Invoke-Step -Message 'Verifying unit tests' -Exe 'vpr' -Arguments @($s)
            break
        }
    }

    $commitTitle = ($count -eq 1) ? "chore(deps): update dependency $singlePkgSummary" : "chore(deps): update dependencies ($count packages)"
    $commitMsg = ($count -eq 1) ? $commitTitle : ($commitTitle + "`n`nUpgrade details:`n" + ($commitBodyLines -join "`n"))

    $failedStep = 'git commit'
    & git add -A
    & git commit -q -m $commitMsg
    if ($LASTEXITCODE -ne 0) {
        throw 'git commit failed'
    }
}
catch {
    Write-Host -NoNewline "`r`e[K"
    [Console]::Error.WriteLine("Error: Pre-checks failed at step '$failedStep'. Rolling back changes to 'main'...")
    & git checkout -q main 2>$null
    & git branch -D $tempBranch >$null 2>&1
    if (Test-Path -LiteralPath '.node_modules.bak' -PathType Container) {
        Remove-Item -LiteralPath 'node_modules' -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath '.node_modules.bak' -Destination 'node_modules' -Force
    }
    else {
        $env:VP_LOG = 'error'
        & vp install --frozen-lockfile --silent 2>$null
    }
    exit 1
}

& git checkout -q main
& git merge --ff-only -q $tempBranch
& git branch -D -q $tempBranch

& git rev-parse --abbrev-ref '@{u}' >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    $failedStep = 'git push'
    Invoke-Step -Message 'Pushing to remote' -Exe 'git' -Arguments @('push', '-q', 'origin', 'main')
    Write-Output "Pushed: $commitTitle"
}
else {
    Write-Output "Committed and merged: $commitTitle"
}
