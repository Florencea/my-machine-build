---
name: win11-toolchain
description: Windows 11 platform execution rules, subshell stdin safety guardrails, PowerShell 5.1 vs 7 runtime isolation, double-shell quote-stripping defense, defensive path assertions, binary inspection protocol, and Git-first disaster recovery. Use when executing commands, debugging scripts, or configuring environment settings on Windows 11.
compatibility: Windows 11, PowerShell 7+, Vite+
---

# Windows 11 Platform Toolchain & Execution Guidelines

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
  - AppX module: On Windows 10, run AppX package queries via Windows PowerShell 5.1 (`powershell.exe`) due to .NET Core `PlatformNotSupportedException` in PS 7.

---

## 3. Windows Defender Developer Exclusions

In local development environments, verify that modern toolchain executables and build directories are excluded from real-time monitoring to prevent file-locking hangs and I/O bottlenecks:

- Excluded processes: `pwsh.exe`, `vp.exe`, `node.exe`, `git.exe`
- Excluded directories: `dist/`, `build/`, `node_modules/`

---

## 4. Array Unrolling & String Indexing Guard

PowerShell pipelines unroll single-item outputs into scalar objects. Indexing `[0]` on a scalar `System.String` returns a single `[char]`. Always wrap pipeline or filtering expressions in `@(...)`:

```powershell
$lines = @($output | Where-Object { $_ -match "https" })
if ($lines.Count -gt 0) {
    $firstUrl = $lines[0]
}
```

---

## 5. Defensive Path Assertions & Fail-Fast Header

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
