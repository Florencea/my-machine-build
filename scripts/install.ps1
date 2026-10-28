#Requires -Version 5.1
<#
.SYNOPSIS
    Idempotent Windows 11 modern development environment & Antigravity setup script.
.DESCRIPTION
    Compatible with both Windows PowerShell 5.1 (in-box default on Windows 11) and PowerShell 7+ (pwsh).
    Strictly avoids PowerShell 7-only syntax operators (? :, ??, ?., &&, ||) so it can bootstrap a fresh Windows 11 machine.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "=== Starting Windows 11 Modern Dev Environment Setup ===" -ForegroundColor Cyan

# 1. Dev Drive & Workspace Initialization
$workspaceDir = "E:\_Workspace"
if (-not (Test-Path -LiteralPath $workspaceDir)) {
    Write-Host "[1/8] Creating Workspace Directory: $workspaceDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
}
else {
    Write-Host "[1/8] Workspace Directory verified: $workspaceDir" -ForegroundColor DarkGray
}

# 2. Vite+ Home & Cache Relocation (E:\vite-plus)
$vpHome = "E:\vite-plus"
if ([Environment]::GetEnvironmentVariable("VP_HOME", "User") -ne $vpHome) {
    Write-Host "[2/8] Setting VP_HOME to $vpHome..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("VP_HOME", $vpHome, "User")
    $env:VP_HOME = $vpHome
}
$env:VP_NODE_MANAGER = "yes"
$env:VP_PM_MANAGER = "yes"
if (-not (Get-Command "vp" -ErrorAction SilentlyContinue)) {
    Write-Host "      Installing Vite+ toolchain..." -ForegroundColor Yellow
    Invoke-RestMethod -Uri "https://vite.plus/ps1" | Invoke-Expression
    if (Get-Command "vp" -ErrorAction SilentlyContinue) {
        & vp env default lts
        & vp env install lts
    }
}
else {
    Write-Host "[2/8] Vite+ toolchain is ready." -ForegroundColor DarkGray
}

# 3. Idempotent Winget Package Installation
function Install-WingetIdempotent {
    param([string]$Id, [string]$Name)
    if ($Id -eq "AgileBits.1Password") {
        $check1P = & winget list 1Password 2>$null
        if ($check1P -match "1Password") {
            Write-Host "      [OK] $Name is already installed." -ForegroundColor DarkGray
            return
        }
    }
    $check = & winget list --id $Id -e 2>$null
    if ($check -match [regex]::Escape($Id)) {
        Write-Host "      [OK] $Name ($Id) is already installed." -ForegroundColor DarkGray
    }
    else {
        Write-Host "      [+] Installing $Name ($Id)..." -ForegroundColor Green
        & winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
}

Write-Host "[3/8] Checking & Installing Modern CLI Tools and Desktop Apps..." -ForegroundColor Cyan

$cliPackages = @(
    @{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7" },
    @{ Id = "BurntSushi.ripgrep.MSVC"; Name = "ripgrep (rg)" },
    @{ Id = "sharkdp.fd"; Name = "fd" },
    @{ Id = "ast-grep.ast-grep"; Name = "ast-grep" },
    @{ Id = "jqlang.jq"; Name = "jq" },
    @{ Id = "MikeFarah.yq"; Name = "yq" },
    @{ Id = "sharkdp.bat"; Name = "bat" },
    @{ Id = "chmln.sd"; Name = "sd" },
    @{ Id = "mvdan.shfmt"; Name = "shfmt" },
    @{ Id = "oschwartz10612.Poppler"; Name = "Poppler (pdftotext)" },
    @{ Id = "XAMPPRocky.Tokei"; Name = "tokei" },
    @{ Id = "BurntSushi.xsv.MSVC"; Name = "xsv" },
    @{ Id = "SQLite.SQLite"; Name = "SQLite (sqlite3)" },
    @{ Id = "ducaale.xh"; Name = "xh" },
    @{ Id = "bootandy.dust"; Name = "dust" },
    @{ Id = "DuckDB.cli"; Name = "DuckDB CLI" },
    @{ Id = "rhysd.actionlint"; Name = "actionlint" },
    @{ Id = "sharkdp.hyperfine"; Name = "hyperfine" },
    @{ Id = "Gyan.FFmpeg"; Name = "FFmpeg" },
    @{ Id = "yt-dlp.yt-dlp"; Name = "yt-dlp" },
    @{ Id = "ImageOptim.gifski"; Name = "gifski" },
    @{ Id = "AgileBits.1Password.CLI"; Name = "1Password CLI (op)" }
)
foreach ($pkg in $cliPackages) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

$desktopPackages = @(
    @{ Id = "Git.Git"; Name = "Git for Windows" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "Google.Chrome"; Name = "Google Chrome" },
    @{ Id = "AgileBits.1Password"; Name = "1Password" },
    @{ Id = "WinMerge.WinMerge"; Name = "WinMerge" },
    @{ Id = "RevoUninstaller.RevoUninstaller"; Name = "Revo Uninstaller" },
    @{ Id = "7zip.7zip"; Name = "7-Zip" }
)
foreach ($pkg in $desktopPackages) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

& winget pin add --id Microsoft.Edge --blocking 2>$null | Out-Null

# 4. Global Git Configuration & Pre-Commit Safety Hook
Write-Host "[4/8] Configuring Global Git Settings & Pre-Commit Hook..." -ForegroundColor Cyan
$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptDir

& git config --global user.name "Florencea"
& git config --global user.email "bearflorencea@gmail.com"
& git config --global core.editor "code --wait"
& git config --global core.quotepath false
& git config --global core.longpaths true
& git config --global core.autocrlf false
& git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
& git config --global core.fsmonitor true
& git config --global core.untrackedcache true
& git config --global init.defaultBranch main
& git config --global push.autoSetupRemote true
& git config --global pull.rebase false
& git config --global fetch.prune true
& git config --global http.sslBackend schannel
& git config --global alias.st "status -sb"
& git config --global alias.co "checkout"
& git config --global alias.br "branch"
& git config --global alias.ci "commit"
& git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
& git config --global alias.remote-init '!f() { name=$(basename $(pwd)); remote=$HOME/Documents/_GitRemote/${name}.git; git init --bare "$remote" && git remote add origin "$remote" && git push -u origin --all && git push origin --tags; }; f'

$gitHooksDir = Join-Path $HOME ".config\git\hooks"
if (-not (Test-Path -LiteralPath $gitHooksDir)) {
    New-Item -ItemType Directory -Force -Path $gitHooksDir | Out-Null
}
$srcPreCommit = Join-Path $repoRoot "configs\git\hooks\pre-commit.sh"
$destPreCommit = Join-Path $gitHooksDir "pre-commit"
if (Test-Path -LiteralPath $srcPreCommit) {
    Copy-Item -LiteralPath $srcPreCommit -Destination $destPreCommit -Force
    & git config --global core.hooksPath ($gitHooksDir -replace '\\', '/')
}

# 5. Windows Terminal & VS Code Configuration
Write-Host "[5/8] Configuring Terminal Defaults to PowerShell 7..." -ForegroundColor Cyan
$wtSettings = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path -LiteralPath $wtSettings) {
    try {
        $json = Get-Content -LiteralPath $wtSettings -Raw | ConvertFrom-Json
        $json.defaultProfile = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
        [System.IO.File]::WriteAllText($wtSettings, ($json | ConvertTo-Json -Depth 10), $utf8NoBom)
    }
    catch {
        Write-Warning "Could not update Windows Terminal settings automatically: $_"
    }
}

$codeSettings = Join-Path $env:APPDATA "Code\User\settings.json"
if (Test-Path -LiteralPath $codeSettings) {
    $content = Get-Content -LiteralPath $codeSettings -Raw
    if ($content -notmatch '"terminal\.integrated\.defaultProfile\.windows"') {
        $idx = $content.LastIndexOf('}')
        if ($idx -ge 0) {
            $prefix = $content.Substring(0, $idx).TrimEnd(" `t`r`n")
            $comma = ','
            if ($prefix.EndsWith(',')) {
                $comma = ''
            }
            $new = "$prefix$comma`r`n  `"terminal.integrated.defaultProfile.windows`": `"PowerShell`"`r`n}`r`n"
            [System.IO.File]::WriteAllText($codeSettings, $new, $utf8NoBom)
        }
    }
}

# 6. PowerShell 7 Profile Setup ($PROFILE)
Write-Host "[6/8] Setting up PowerShell 7 `$PROFILE..." -ForegroundColor Cyan
$ps7Dir = Join-Path $HOME "Documents\PowerShell"
if (-not (Test-Path -LiteralPath $ps7Dir)) {
    New-Item -ItemType Directory -Force -Path $ps7Dir | Out-Null
}
$profilePath = Join-Path $ps7Dir "Microsoft.PowerShell_profile.ps1"
$profileContent = @'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key "Shift+Tab" -Function TabCompletePrevious
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop
    } catch {}
}
'@
[System.IO.File]::WriteAllText($profilePath, $profileContent, $utf8NoBom)

# 7. Sync Antigravity Plugins (common-modern-tools, win11-modern-tools & modern-web-stack)
Write-Host "[7/8] Syncing Antigravity Plugins..." -ForegroundColor Cyan
$pluginsDestRoot = Join-Path $HOME ".gemini\config\plugins"
if (-not (Test-Path -LiteralPath $pluginsDestRoot)) {
    New-Item -ItemType Directory -Force -Path $pluginsDestRoot | Out-Null
}

foreach ($pluginName in @("common-modern-tools", "win11-modern-tools", "modern-web-stack")) {
    $srcPlugin = Join-Path $repoRoot "plugins\$pluginName"
    $destPlugin = Join-Path $pluginsDestRoot $pluginName
    if (Test-Path -LiteralPath $srcPlugin) {
        if (Test-Path -LiteralPath $destPlugin) {
            Remove-Item -LiteralPath $destPlugin -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Force -Path $destPlugin | Out-Null
        Copy-Item -Path (Join-Path $srcPlugin "*") -Destination $destPlugin -Recurse -Force
    }
}

# Clean up legacy standalone rules/skills directories if present
foreach ($legacyDir in @("rules", "skills")) {
    $legacyPath = Join-Path $HOME ".gemini\config\$legacyDir"
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 8. Register Repository CLI Directory & Prune Stale User PATH
Write-Host "[8/8] Registering CLI Directory and Pruning Stale User PATH Entries..." -ForegroundColor Cyan
$cliDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..\cli")).Path
$rawUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$currentUserPath = @()
if ($rawUserPath) {
    $currentUserPath = @(
        $rawUserPath -split ';' |
        ForEach-Object { $_.Trim().TrimEnd('\') } |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    )
}

if ($currentUserPath -notcontains $cliDir) {
    $currentUserPath += $cliDir
    Write-Host "Added $cliDir to User PATH." -ForegroundColor Green
}

$cleanPath = ($currentUserPath | Select-Object -Unique) -join ';'
[Environment]::SetEnvironmentVariable("Path", $cleanPath, "User")

Write-Host "=== Setup Completed Successfully! ===" -ForegroundColor Green
