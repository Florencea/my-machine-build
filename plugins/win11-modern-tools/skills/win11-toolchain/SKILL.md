---
name: win11-toolchain
description: Windows 11 platform execution rules, subshell stdin safety guardrails, PowerShell 5.1 vs 7 runtime isolation, Dev Drive optimization, and pipeline array unwrapping recipes. Use when executing commands, debugging scripts, or configuring environment settings on Windows 11.
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
