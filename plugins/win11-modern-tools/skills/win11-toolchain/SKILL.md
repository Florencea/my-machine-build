---
name: win11-toolchain
description: Windows 11 platform execution rules, subshell stdin safety guardrails, PowerShell 5.1 vs 7 runtime isolation, double-shell quote-stripping defense, defensive path assertions, binary inspection protocol, and Git-first disaster recovery. Use when executing commands, debugging scripts, or configuring environment settings on Windows 11.
compatibility: Windows 11, PowerShell 7+, Vite+
---

# Windows 11 Platform Toolchain & Execution Guidelines

> [!NOTE]
> For universal high-performance CLI tools (`rg`, `fd`, `bat`, `sd`, `jq`, `yq`, `duckdb`, `sqlite3`, `xsv`, `xh`, `dust`, `pdftotext`, `shfmt`, `actionlint`, `hyperfine`, Vite+), refer to the **`common-toolchain`** skill.

## 1. Subshell Stdin Defense & Automation Patterns

### 1.1 Background Subshell Stdin Pitfall

Background subshells pipe standard input. Commands like `rg`, `jq`, `sd`, `xsv`, or `tokei` will hang indefinitely waiting for an EOF stream if executed without explicit target paths:

```powershell
# BAD: Subshell hangs indefinitely
rg "pattern"
tokei

# GOOD: Explicit paths or input sources
rg -n -M 200 "pattern" .
tokei .
```

### 1.2 Pipeline Array Unrolling & String Indexing Guard

In PowerShell, filtering operations (like `Where-Object` or regex splits) that return a single result unroll into a scalar `System.String`. Indexing `[0]` on a scalar string extracts the first character (`[char]`):

```powershell
# BAD: If only one line matches, $lines[0] returns [char]'h' instead of the line!
$lines = $output | Where-Object { $_ -match "https" }
$firstUrl = $lines[0]

# GOOD: Wrap in @(...) array subexpression
$lines = @($output | Where-Object { $_ -match "https" })
$firstUrl = $lines[0]
```

---

## 2. PowerShell 5.1 vs PowerShell 7+ Compatibility

### 2.1 Bootstrap Scripts vs Advanced Automation

- **Bootstrap Scripts (`scripts/install.ps1`)**:
  - Must run cleanly on out-of-the-box Windows 11 with default Windows PowerShell 5.1 (`powershell.exe`).
  - Prohibited in bootstrap scripts:
    - Ternary operators: `$cond ? $a : $b`
    - Null-coalescing operators: `$a ?? $b`, `$a ??= $b`
    - Safe navigation: `$a?.b`
    - Pipeline chain operators: `&&`, `||`
    - Parallel loop: `ForEach-Object -Parallel`
    - Hashtable conversion: `ConvertFrom-Json -AsHashtable`
- **Modern Automation & CLI Scripts (`cli/*.ps1`)**:
  - Always run under PowerShell 7 (`pwsh.exe`) and leverage modern syntax freely.

### 2.2 UTF-8 Pipeline Encoding

Ensure UTF-8 without BOM stream encoding for all console outputs:

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
```

---

## 3. Dev Drive (`E:\`) & ReFS Performance Optimization

- Dev Drive utilizes the ReFS filesystem with asynchronous Microsoft Defender filter inspection.
- When creating workspace directories or caches, place them under `E:\_Workspace` or `VP_HOME = E:\vite-plus` to maximize build and disk throughput.

---

## 4. YouTube Protected Streaming Workaround

Modern YouTube media stream URLs (`googlevideo.com`) use Sabr/TVHTML5 token binding. Direct playback via `ffmpeg -i <url>` fails with HTTP `403 Forbidden`. Always download snippets via `yt-dlp` first:

```powershell
yt-dlp --download-sections "*00:01:00-00:01:30" --cookies-from-browser edge -o "clip.mp4" "<url>"
```

---

## 5. Safe Multi-Statement Execution & Defensive Path Assertions

### 5.1 Fail-Fast Header Invariant

Every multi-command block executed via `pwsh -Command` or `pwsh -EncodedCommand` MUST begin with strict error stopping:

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
```

If any command, variable assignment, or path evaluation fails, the script aborts immediately rather than continuing into downstream destructive operations with uninitialized (`$null`) variables.

### 5.2 Defensive Path Assertion Recipe

Never execute recursive copy, move, or delete without validating that both source and destination are non-null and valid:

```powershell
# BANNED: Dangerous unchecked copy
Copy-Item -Path "$src\*" -Destination $dest -Recurse -Force

# REQUIRED: Defensive assertion pattern
$src = 'C:\path\to\source'
$dest = 'relative\path\to\target'

if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) {
    throw "Source path is null, whitespace, or non-existent: '$src'"
}
if ([string]::IsNullOrWhiteSpace($dest)) {
    throw "Destination path cannot be null or whitespace"
}

# Ensure destination exists before copying
if (-not (Test-Path -LiteralPath $dest)) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
```

---

## 6. Windows Double-Shell Quoting Pitfalls & Solutions

### 6.1 The Quote-Stripping Mechanism

In Antigravity on Windows, commands run inside an outer **Windows PowerShell 5.1** (`powershell.exe`) host session. When calling `pwsh.exe -NoLogo -NoProfile -Command '...'`, Windows PowerShell 5.1 strips internal double quotes before launching `pwsh.exe`:

```powershell
# BAD: Windows PowerShell 5.1 strips "..." before passing to pwsh.exe!
pwsh -NoLogo -NoProfile -Command '
$src = "C:\Users\name\folder"
# pwsh actually receives: $src = C:\Users\name\folder
# Throws: "Cannot find cmdlet C:\Users\name\folder" and leaves $src as $null!
'
```

### 6.2 Solutions

#### Solution A: Single-Quote Literals

Use single quotes for inner string literals, or escape properly:

```powershell
pwsh -NoLogo -NoProfile -Command '$src = ''C:\Users\name\folder''; ...'
```

#### Solution B: Base64 `-EncodedCommand` (Recommended for Complex Scripts)

For multi-line scripts or commands containing multiple quote styles, encode the script as a UTF-16LE Base64 string. This guarantees zero quote stripping or parameter mangling by the outer shell:

```powershell
$script = @'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$src = 'C:\Users\name\folder'
$dest = 'target\folder'
if (-not (Test-Path -LiteralPath $src)) { throw "Source missing" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
'@

$bytes = [System.Text.Encoding]::Unicode.GetBytes($script)
$b64 = [Convert]::ToBase64String($bytes)
pwsh -NoLogo -NoProfile -EncodedCommand $b64
```

---

## 7. Safe Binary & Large File Inspection Protocol

### 7.1 The CPU / Memory Deadlock Anti-Pattern

Attempting to read large binaries or files (>1MB) into PowerShell memory to run regex patterns is strictly prohibited:

```powershell
# BANNED ANTI-PATTERN: Consumes 600MB+ RAM and pegs CPU at 100%
$bytes = [System.IO.File]::ReadAllBytes("path\to\huge.exe")
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
[regex]::Matches($text, "pattern")
```

### 7.2 Native Streaming Tool SSOT (`rg -a`)

Always inspect binary files, DLLs, and executables using native, streaming Rust CLI tools:

```bash
# REQUIRED: Near-zero memory, streaming, completes in milliseconds
rg -a -M 200 "pattern" path\to\huge.exe
```

### 7.3 In-Memory Read File-Size Gate

If PowerShell code must read file contents into memory, enforce an explicit 1MB safety threshold:

```powershell
$fileInfo = Get-Item -LiteralPath $targetFile
if ($fileInfo.Length -gt 1MB) {
    throw "File '$targetFile' ($([math]::Round($fileInfo.Length / 1MB, 2)) MB) exceeds 1MB in-memory threshold. Use native CLI tools instead."
}
$content = Get-Content -LiteralPath $targetFile -Raw
```

---

## 8. Git-First Incident Recovery & MAX_PATH Defense

### 8.1 Why Filesystem Recursion Fails on Windows

When an erroneous recursive copy or directory creation occurs inside a repository:

1. Deeply nested paths (such as `.pnpm` packages or `node_modules`) easily exceed the default 260-character Windows `MAX_PATH` limit.
2. Background indexers, language servers, or anti-virus filters often hold file handles, causing `Remove-Item -Recurse`, `rd /s /q`, or `robocopy /purge` to fail with "Access Denied" or "Directory not empty", hanging the terminal session.

### 8.2 Git-First Recovery Pattern

Git has native long-path support. Instead of manual deletion, always recover the clean repository state via Git:

```bash
# 1. Immediately halt all filesystem mutations
# 2. Clean all untracked files and directories with long-path bypass:
git -c core.longpaths=true clean -ffdx

# 3. Discard all unstaged tracked file modifications:
git checkout -- .

# 4. Verify clean working tree:
git status
```
