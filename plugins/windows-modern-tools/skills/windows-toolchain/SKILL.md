---
name: windows-toolchain
description: Windows platform execution rules for Windows 11 and Windows 10 IoT LTSC, subshell stdin safety guardrails, PowerShell 5.1 vs 7 runtime isolation, double-shell quote-stripping defense, defensive path assertions, binary inspection protocol, and Git-first disaster recovery. Use when executing commands, debugging scripts, or configuring environment settings on Windows.
compatibility: Windows 11, Windows 10 IoT LTSC, PowerShell 7+, PowerShell 5.1, Vite+
---

# Windows Platform Toolchain & Execution Guidelines (Windows 11 & Windows 10 IoT LTSC)

> [!NOTE]
> For universal CLI binaries (`rg`, `fd`, `bat`, `sd`, `jq`, `yq`, `duckdb`, `xsv`, `xh`, Vite+), refer to the **`common-toolchain`** skill.
> For PowerShell authoring, AST verification, and `PSScriptAnalyzerSettings.psd1` rules, refer to the **`modern-powershell`** skill.

---

## 1. Double-Shell Invocation & Quote-Stripping Defense

In Antigravity's Windows execution environment, the host shell is **Windows PowerShell 5.1** (`powershell.exe`). When launching `pwsh.exe -NoLogo -NoProfile -Command '...'`, Windows PowerShell 5.1 strips internal double quotes from the command string.

### Safe Invocation Patterns

- **Single-Quote Literals**:
  Use single quotes for inner string literals:
  ```powershell
  pwsh -NoLogo -NoProfile -Command '$src = ''C:\path\to\dir''; Get-ChildItem -LiteralPath $src'
  ```
- **Base64 `-EncodedCommand` (Recommended for Multi-Line Scripts)**:
  Bypass outer shell quote-stripping by encoding UTF-16LE bytes to Base64:
  ```powershell
  $script = @'
  $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
  $src = 'C:\path\to\dir'
  $dest = 'C:\path\to\target'
  if (-not (Test-Path -LiteralPath $src)) { throw "Source missing: $src" }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
  '@
  $bytes = [System.Text.Encoding]::Unicode.GetBytes($script)
  $b64 = [Convert]::ToBase64String($bytes)
  pwsh -NoLogo -NoProfile -EncodedCommand $b64
  ```

---

## 2. Dev Drive (ReFS) & Windows 10 IoT LTSC Capability Matrix

- **Dev Drive (ReFS)**:
  - Supported exclusively on Windows 11 Build 22621+. Uses ReFS Copy-on-Write (Block Cloning) and asynchronous Defender inspection.
  - Prioritize placing workspace repositories and package caches on Dev Drive (`E:\_Workspace`, `VP_HOME = E:\vite-plus`).
- **Windows 10 IoT LTSC Fallback**:
  - Dev Drive (`fsutil devdrv`) is strictly unavailable. Use standard NTFS storage (`$HOME\_Workspace`, `VP_HOME = $HOME\.vite-plus`) without querying `fsutil devdrv`.
  - Native `sudo.exe` is absent on Windows 10. Operations requiring elevation must use `Start-Process -Verb RunAs` or self-elevating script wrappers.
  - WinGet must be bootstrapped with framework dependencies (VCLibs, WindowsAppRuntime) and `AppXSvc` enablement.

---

## 3. Windows 10 IoT LTSC: PowerShell 7 AppX Barrier & Cmdlet Delegation

On Windows 10, the in-box `Appx` PowerShell module cannot run under .NET Core (PowerShell 7+), throwing `PlatformNotSupportedException` (`0x80131539`).

When inspecting or managing AppX packages from PowerShell 7 on Windows 10, delegate the call to Windows PowerShell 5.1 and deserialize JSON output:

```powershell
function Get-AppxPackageCompat {
    param(
        [string]$Name,
        [switch]$AllUsers
    )
    $isWin10 = ([System.Environment]::OSVersion.Version.Major -eq 10 -and [System.Environment]::OSVersion.Version.Build -lt 22000)
    if ($isWin10 -and ($PSVersionTable.PSEdition -eq 'Core')) {
        $allArg = if ($AllUsers) { '-AllUsers' } else { '' }
        $cmd = "Get-AppxPackage -Name '$Name' $allArg | Select-Object -Property Name, PackageFullName, InstallLocation | ConvertTo-Json -Compress"
        $raw = (& powershell.exe -NoLogo -NoProfile -Command $cmd 2>$null)
        if ($raw) {
            return ($raw | ConvertFrom-Json)
        }
        return $null
    }
    if ($AllUsers) {
        return (Get-AppxPackage -Name $Name -AllUsers -ErrorAction SilentlyContinue)
    }
    return (Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue)
}
```

---

## 4. Safe Directory Copying Without Unanchored Wildcards

Avoid using unanchored wildcards (`Copy-Item -Path (Join-Path $src '*')`). Enumerate child items explicitly using `-LiteralPath` to prevent glob expansion failures on paths containing square brackets:

```powershell
if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) {
    throw "Source directory missing or invalid: '$src'"
}
if ([string]::IsNullOrWhiteSpace($dest)) {
    throw "Destination directory cannot be empty"
}
if (Test-Path -LiteralPath $dest) {
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Get-ChildItem -LiteralPath $src | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
}
```

---

## 5. Windows Defender Developer Exclusions

In local development environments, verify that modern toolchain executables and build directories are excluded from real-time monitoring to prevent file-locking hangs and I/O bottlenecks:

- Excluded processes: `pwsh.exe`, `vp.exe`, `node.exe`, `git.exe`
- Excluded directories: `dist/`, `build/`, `node_modules/`

---

## 6. Array Unrolling & String Indexing Guard

PowerShell pipelines unroll single-item outputs into scalar objects. Indexing `[0]` on a scalar `System.String` returns a single `[char]`. Always wrap pipeline or filtering expressions in `@(...)`:

```powershell
$lines = @($output | Where-Object { $_ -match "https" })
if ($lines.Count -gt 0) {
    $firstUrl = $lines[0]
}
```

---

## 7. Defensive Path Assertions & Fail-Fast Header

Every script block executed via `pwsh -Command` or `-EncodedCommand` must begin with strict error stopping:

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
```

Before executing destructive recursive operations (`Copy-Item -Recurse`, `Remove-Item -Recurse`), defensively assert that paths are non-null and exist:

```powershell
if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) {
    throw "Source path is null, whitespace, or non-existent: '$src'"
}
if ([string]::IsNullOrWhiteSpace($dest)) {
    throw "Destination path cannot be null or whitespace"
}
```
