#Requires -Version 5.1
<#
.SYNOPSIS
    Idempotent Windows 11 & Windows 10 IoT LTSC modern development environment setup script.
.DESCRIPTION
    Compatible with both Windows PowerShell 5.1 (in-box default on Windows 10/11) and PowerShell 7+ (pwsh).
    Strictly avoids PowerShell 7-only syntax operators (? :, ??, ?., &&, ||) so it can bootstrap a fresh machine.
    Automatically self-elevates to Administrator, bootstraps winget on LTSC, and configures modern toolchains.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enforce TLS 1.2 for network downloads in Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

# Self-elevation to Administrator if running under standard user
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Administrator privileges required. Requesting elevation...' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Ensure persistent ExecutionPolicy for subsequent sessions and CLI utilities
if ((Get-ExecutionPolicy -Scope CurrentUser) -in @('Restricted', 'Undefined')) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}
if ((Get-ExecutionPolicy -Scope LocalMachine) -in @('Restricted', 'Undefined')) {
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
}

# Enable Windows OS LongPaths support
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -Type DWord -Force

# Enable App Sideloading (required for Win10 LTSC Add-AppxPackage)
$appUnlockPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path -LiteralPath $appUnlockPath)) {
    New-Item -Path $appUnlockPath -Force | Out-Null
}
Set-ItemProperty -Path $appUnlockPath -Name 'AllowAllTrustedApps' -Value 1 -Type DWord -Force

# Workspace & VP_HOME directory resolution (Fallback to $HOME\_Workspace if E: is absent)
if (Test-Path 'E:\') {
    $workspaceDir = 'E:\_Workspace'
    $vpHome = 'E:\vite-plus'
}
else {
    $workspaceDir = Join-Path $HOME '_Workspace'
    $vpHome = Join-Path $HOME '.vite-plus'
}

# Helper function to refresh PATH inside current process
function Update-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = @(
        ($machinePath -split ';') + ($userPath -split ';') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    ) | Select-Object -Unique

    $extraPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'),
        'C:\Program Files\Git\cmd',
        'C:\Program Files\PowerShell\7',
        (Join-Path $vpHome 'bin'),
        (Join-Path $HOME '.vite-plus\bin')
    )
    foreach ($p in $extraPaths) {
        if ((Test-Path -LiteralPath $p) -and ($combined -notcontains $p)) {
            $combined += $p
        }
    }
    $env:Path = $combined -join ';'
}

# Helper function to download files safely
function Download-FileSecure {
    param(
        [string]$Uri,
        [string]$OutFile
    )
    if (Get-Command 'curl.exe' -ErrorAction SilentlyContinue) {
        & curl.exe -sSL -o $OutFile $Uri
    }
    else {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
    }
}

Write-Host '=== Starting Windows Modern Dev Environment Setup ===' -ForegroundColor Cyan

# 1. Workspace Directory Initialization
if (-not (Test-Path -LiteralPath $workspaceDir)) {
    Write-Host "[1/9] Creating Workspace Directory: $workspaceDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
}
else {
    Write-Host "[1/9] Workspace Directory verified: $workspaceDir" -ForegroundColor DarkGray
}

# 2. Internal Root CAs (Private PKI for *.internal)
Write-Host '[2/9] Checking & Trusting Internal Root CAs...' -ForegroundColor Cyan

$bhpdRootCaB64 = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='
$bhgsRootCaB64 = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FVUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='

function Install-InternalRootCA {
    param(
        [string]$Name,
        [string]$Base64Cert
    )
    $rawCert = [System.Convert]::FromBase64String($Base64Cert)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (, $rawCert)
    $thumbprint = $cert.Thumbprint

    $inUser = @(Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint })
    $inMachine = @(Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint })
    if ($inUser.Count -gt 0 -or $inMachine.Count -gt 0) {
        Write-Host "      [OK] $Name is already trusted." -ForegroundColor DarkGray
        return
    }

    Write-Host "      [+] Trusting $Name ($thumbprint)..." -ForegroundColor Green

    $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', $storeLocation)
    try {
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($cert)
    }
    finally {
        $store.Close()
    }
}

Install-InternalRootCA -Name 'BHPD Internal Root CA' -Base64Cert $bhpdRootCaB64
Install-InternalRootCA -Name 'BHGS Internal Root CA' -Base64Cert $bhgsRootCaB64

# 3. Vite+ Home & Cache Relocation
if ([Environment]::GetEnvironmentVariable('VP_HOME', 'User') -ne $vpHome) {
    Write-Host "[3/9] Setting VP_HOME to $vpHome..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable('VP_HOME', $vpHome, 'User')
    $env:VP_HOME = $vpHome
}
$env:VP_NODE_MANAGER = 'yes'
$env:VP_PM_MANAGER = 'yes'
if (-not (Get-Command 'vp' -ErrorAction SilentlyContinue)) {
    Write-Host '      Installing Vite+ toolchain...' -ForegroundColor Yellow
    Invoke-RestMethod -Uri 'https://vite.plus/ps1' | Invoke-Expression
    Update-SessionPath
    if (Get-Command 'vp' -ErrorAction SilentlyContinue) {
        & vp env default lts
        & vp env install lts
    }
}
else {
    Write-Host '[3/9] Vite+ toolchain is ready.' -ForegroundColor DarkGray
}

# 4. WinGet Bootstrap & Package Installation
function Ensure-Winget {
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        return
    }
    $windowsAppsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    $localAppsWinget = Join-Path $windowsAppsDir 'winget.exe'
    if (Test-Path -LiteralPath $localAppsWinget) {
        if ($env:Path -notmatch [regex]::Escape($windowsAppsDir)) {
            $env:Path = "$windowsAppsDir;$env:Path"
        }
        if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
            return
        }
    }

    Write-Host '      [+] WinGet not detected. Bootstrapping dependencies on Windows 10 LTSC...' -ForegroundColor Yellow
    $tempDir = Join-Path $env:TEMP "winget-bootstrap-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        $vclibsUrl = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        $uiXamlUrl = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
        $wingetUrl = 'https://aka.ms/getwinget'

        $vclibsPath = Join-Path $tempDir 'Microsoft.VCLibs.x64.appx'
        $uiXamlPath = Join-Path $tempDir 'Microsoft.UI.Xaml.2.8.x64.appx'
        $wingetPath = Join-Path $tempDir 'Microsoft.DesktopAppInstaller.msixbundle'

        Write-Host '      Downloading Microsoft.VCLibs...' -ForegroundColor DarkGray
        Download-FileSecure -Uri $vclibsUrl -OutFile $vclibsPath
        Write-Host '      Downloading Microsoft.UI.Xaml 2.8...' -ForegroundColor DarkGray
        Download-FileSecure -Uri $uiXamlUrl -OutFile $uiXamlPath
        Write-Host '      Downloading WinGet DesktopAppInstaller...' -ForegroundColor DarkGray
        Download-FileSecure -Uri $wingetUrl -OutFile $wingetPath

        Write-Host '      Registering VCLibs & UI.Xaml dependencies...' -ForegroundColor DarkGray
        Add-AppxPackage -Path $vclibsPath
        Add-AppxPackage -Path $uiXamlPath

        Write-Host '      Registering WinGet App Installer package...' -ForegroundColor DarkGray
        Add-AppxPackage -Path $wingetPath -DependencyPath @($vclibsPath, $uiXamlPath)

        if (Test-Path -LiteralPath $windowsAppsDir) {
            if ($env:Path -notmatch [regex]::Escape($windowsAppsDir)) {
                $env:Path = "$windowsAppsDir;$env:Path"
            }
        }

        Write-Host '      Initializing WinGet package source agreements...' -ForegroundColor DarkGray
        & winget source update --disable-interactivity 2>$null | Out-Null
        Write-Host '      [OK] WinGet bootstrapped successfully.' -ForegroundColor Green
    }
    finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Ensure-Winget

function Install-WingetIdempotent {
    param([string]$Id, [string]$Name)
    if ($Id -eq 'AgileBits.1Password') {
        $check1P = & winget list 1Password --accept-source-agreements --disable-interactivity 2>$null
        if ($check1P -match '1Password') {
            Write-Host "      [OK] $Name is already installed." -ForegroundColor DarkGray
            return
        }
    }
    $check = & winget list --id $Id -e --accept-source-agreements --disable-interactivity 2>$null
    if ($check -match [regex]::Escape($Id)) {
        Write-Host "      [OK] $Name ($Id) is already installed." -ForegroundColor DarkGray
    }
    else {
        Write-Host "      [+] Installing $Name ($Id)..." -ForegroundColor Green
        & winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
}

Write-Host '[4/9] Checking & Installing Modern CLI Tools and Desktop Apps...' -ForegroundColor Cyan

$cliPackages = @(
    @{ Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7' },
    @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep (rg)' },
    @{ Id = 'sharkdp.fd'; Name = 'fd' },
    @{ Id = 'ast-grep.ast-grep'; Name = 'ast-grep' },
    @{ Id = 'jqlang.jq'; Name = 'jq' },
    @{ Id = 'MikeFarah.yq'; Name = 'yq' },
    @{ Id = 'sharkdp.bat'; Name = 'bat' },
    @{ Id = 'chmln.sd'; Name = 'sd' },
    @{ Id = 'mvdan.shfmt'; Name = 'shfmt' },
    @{ Id = 'oschwartz10612.Poppler'; Name = 'Poppler (pdftotext)' },
    @{ Id = 'XAMPPRocky.Tokei'; Name = 'tokei' },
    @{ Id = 'BurntSushi.xsv.MSVC'; Name = 'xsv' },
    @{ Id = 'SQLite.SQLite'; Name = 'SQLite (sqlite3)' },
    @{ Id = 'ducaale.xh'; Name = 'xh' },
    @{ Id = 'bootandy.dust'; Name = 'dust' },
    @{ Id = 'DuckDB.cli'; Name = 'DuckDB CLI' },
    @{ Id = 'rhysd.actionlint'; Name = 'actionlint' },
    @{ Id = 'sharkdp.hyperfine'; Name = 'hyperfine' },
    @{ Id = 'Gyan.FFmpeg'; Name = 'FFmpeg' },
    @{ Id = 'yt-dlp.yt-dlp'; Name = 'yt-dlp' },
    @{ Id = 'ImageOptim.gifski'; Name = 'gifski' },
    @{ Id = 'AgileBits.1Password.CLI'; Name = '1Password CLI (op)' }
)
foreach ($pkg in $cliPackages) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

$desktopPackages = @(
    @{ Id = 'Git.Git'; Name = 'Git for Windows' },
    @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' },
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' },
    @{ Id = 'AgileBits.1Password'; Name = '1Password' },
    @{ Id = 'WinMerge.WinMerge'; Name = 'WinMerge' },
    @{ Id = 'RevoUninstaller.RevoUninstaller'; Name = 'Revo Uninstaller' },
    @{ Id = '7zip.7zip'; Name = '7-Zip' }
)
foreach ($pkg in $desktopPackages) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

& winget pin add --id Microsoft.Edge --blocking 2>$null | Out-Null

# Refresh in-process PATH so git, pwsh, code etc. are immediately visible
Update-SessionPath

# 5. Global Git Configuration & Pre-Commit Safety Hook
Write-Host '[5/9] Configuring Global Git Settings & Pre-Commit Hook...' -ForegroundColor Cyan
$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptDir

& git config --global user.name 'Florencea'
& git config --global user.email 'bearflorencea@gmail.com'
& git config --global core.editor 'code --wait'
& git config --global core.quotepath false
& git config --global core.longpaths true
& git config --global core.autocrlf false

$systemSsh = 'C:\Windows\System32\OpenSSH\ssh.exe'
if (-not (Test-Path -LiteralPath $systemSsh)) {
    Write-Host '      Checking OpenSSH Client Capability...' -ForegroundColor DarkGray
    try {
        Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Could not install OpenSSH Client capability: $_"
    }
}

if (Test-Path -LiteralPath $systemSsh) {
    & git config --global core.sshCommand 'C:/Windows/System32/OpenSSH/ssh.exe'
}
else {
    & git config --global --unset-all core.sshCommand 2>$null
}

& git config --global --unset-all core.fsmonitor 2>$null
& git config --global --unset-all core.untrackedcache 2>$null
& git config --global init.defaultBranch main
& git config --global push.autoSetupRemote true
& git config --global pull.rebase false
& git config --global fetch.prune true
& git config --global http.sslBackend schannel
& git config --global alias.st 'status -sb'
& git config --global alias.co 'checkout'
& git config --global alias.br 'branch'
& git config --global alias.ci 'commit'
& git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
& git config --global alias.remote-init '!f() { name=$(basename $(pwd)); remote=D:/Data/_GitRemote/${name}.git; git init --bare "$remote" && git remote add origin "$remote" && git push -u origin --all && git push origin --tags; }; f'

$gitHooksDir = Join-Path $HOME '.config\git\hooks'
if (-not (Test-Path -LiteralPath $gitHooksDir)) {
    New-Item -ItemType Directory -Force -Path $gitHooksDir | Out-Null
}
$srcPreCommit = Join-Path $repoRoot 'configs\git\hooks\pre-commit.sh'
$destPreCommit = Join-Path $gitHooksDir 'pre-commit'
if (Test-Path -LiteralPath $srcPreCommit) {
    Copy-Item -LiteralPath $srcPreCommit -Destination $destPreCommit -Force
    & git config --global core.hooksPath ($gitHooksDir -replace '\\', '/')
}

# 6. Windows Terminal & VS Code Configuration
Write-Host '[6/9] Configuring Terminal Defaults to PowerShell 7...' -ForegroundColor Cyan

$wtLocalState = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$wtSettings = Join-Path $wtLocalState 'settings.json'
if (-not (Test-Path -LiteralPath $wtLocalState)) {
    $wtPkg = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe'
    if (Test-Path -LiteralPath $wtPkg) {
        New-Item -ItemType Directory -Force -Path $wtLocalState | Out-Null
    }
}

if (Test-Path -LiteralPath $wtSettings) {
    try {
        $json = Get-Content -LiteralPath $wtSettings -Raw | ConvertFrom-Json
        if ($json.defaultProfile -ne '{574e775e-4f2a-5b96-ac1e-a2962a402336}') {
            $json.defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
            [System.IO.File]::WriteAllText($wtSettings, ($json | ConvertTo-Json -Depth 10), $utf8NoBom)
        }
    }
    catch {
        Write-Warning "Could not update Windows Terminal settings automatically: $_"
    }
}
elseif (Test-Path -LiteralPath $wtLocalState) {
    $initialWt = @{
        '$schema' = 'https://aka.ms/terminal-profiles-schema'
        defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText($wtSettings, $initialWt, $utf8NoBom)
}

$codeUserDir = Join-Path $env:APPDATA 'Code\User'
if (-not (Test-Path -LiteralPath $codeUserDir)) {
    New-Item -ItemType Directory -Force -Path $codeUserDir | Out-Null
}
$codeSettings = Join-Path $codeUserDir 'settings.json'
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
else {
    $initialCode = "{\r\n  `"terminal.integrated.defaultProfile.windows`": `"PowerShell`"\r\n}\r\n"
    [System.IO.File]::WriteAllText($codeSettings, $initialCode, $utf8NoBom)
}

# 7. PowerShell Profiles Setup ($PROFILE for PowerShell 7 and Windows PowerShell 5.1)
Write-Host "[7/9] Setting up PowerShell Profile..." -ForegroundColor Cyan

$docsDir = [Environment]::GetFolderPath('MyDocuments')
if (-not (Test-Path -LiteralPath $docsDir)) {
    $docsDir = Join-Path $HOME 'Documents'
}

$profileDirs = @(
    (Join-Path $docsDir 'PowerShell'),
    (Join-Path $docsDir 'WindowsPowerShell')
)

$profileContent = @'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$env:COLORTERM = 'truecolor'
$env:FORCE_COLOR = '3'
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key "Shift+Tab" -Function TabCompletePrevious
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop
    } catch {}
}
'@

foreach ($pDir in $profileDirs) {
    if (-not (Test-Path -LiteralPath $pDir)) {
        New-Item -ItemType Directory -Force -Path $pDir | Out-Null
    }
    $pPath = Join-Path $pDir 'Microsoft.PowerShell_profile.ps1'
    if (Test-Path -LiteralPath $pPath) {
        $existing = Get-Content -LiteralPath $pPath -Raw
        if ($existing.Trim() -ne $profileContent.Trim()) {
            [System.IO.File]::WriteAllText($pPath, $profileContent, $utf8NoBom)
        }
    }
    else {
        [System.IO.File]::WriteAllText($pPath, $profileContent, $utf8NoBom)
    }
}

# 8. Sync Antigravity Plugins (common-modern-tools, win11-modern-tools & modern-web-stack)
Write-Host '[8/9] Syncing Antigravity Plugins...' -ForegroundColor Cyan
$pluginsDestRoot = Join-Path $HOME '.gemini\config\plugins'
if (-not (Test-Path -LiteralPath $pluginsDestRoot)) {
    New-Item -ItemType Directory -Force -Path $pluginsDestRoot | Out-Null
}

foreach ($pluginName in @('common-modern-tools', 'win11-modern-tools', 'modern-web-stack')) {
    $srcPlugin = Join-Path $repoRoot "plugins\$pluginName"
    $destPlugin = Join-Path $pluginsDestRoot $pluginName
    if (Test-Path -LiteralPath $srcPlugin) {
        if (Test-Path -LiteralPath $destPlugin) {
            Remove-Item -LiteralPath $destPlugin -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Force -Path $destPlugin | Out-Null
        Copy-Item -Path (Join-Path $srcPlugin '*') -Destination $destPlugin -Recurse -Force
    }
}

# Clean up legacy standalone rules/skills directories if present
foreach ($legacyDir in @('rules', 'skills')) {
    $legacyPath = Join-Path $HOME ".gemini\config\$legacyDir"
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 9. Register Repository CLI Directory & Prune Stale User PATH
Write-Host '[9/9] Registering CLI Directory and Pruning Stale User PATH Entries...' -ForegroundColor Cyan
$cliDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..\cli')).Path
$rawUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$currentUserPath = @()
if ($rawUserPath) {
    $currentUserPath = @(
        $rawUserPath -split ';' |
            ForEach-Object { $_.Trim().TrimEnd('\') } |
            Where-Object {
                if (-not $_) { return $false }
                $expanded = [Environment]::ExpandEnvironmentVariables($_)
                Test-Path -LiteralPath $expanded
            }
    )
}

if ($currentUserPath -notcontains $cliDir) {
    $currentUserPath += $cliDir
    Write-Host "Added $cliDir to User PATH." -ForegroundColor Green
}

$cleanPath = ($currentUserPath | Select-Object -Unique) -join ';'
[Environment]::SetEnvironmentVariable('Path', $cleanPath, 'User')

Write-Host '=== Setup Completed Successfully! ===' -ForegroundColor Green
