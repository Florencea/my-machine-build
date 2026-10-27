---
name: win11-toolchain
description: Pre-installed high-performance Windows 11 CLI tools (rg, fd, ast-grep, tokei, xsv, sqlite3, xh, dust, jq, yq, bat, sd, shfmt, pdftotext, duckdb, actionlint, hyperfine, pwsh / PowerShell 7), Vite+ toolchain (vp, vpx, vpr), PowerShell execution safety, and live query endpoints. Use when running terminal commands, inspecting docs/PDFs, or refactoring code on Windows 11.
compatibility: Windows 11, PowerShell 7+, Vite+
---

# Windows 11 Modern Toolchain & Agent Guidelines

## 1. Tool Selection Decision Tree & Hierarchy

When executing tasks on Windows 11, always follow this prioritized 4-tier selection hierarchy instead of slow legacy commands (`Get-ChildItem -Recurse`, `Select-String`, `findstr`, `type`, `sed`) or polluting the workspace with throwaway scripts:

### Tier 1: Modern Standalone CLI Binaries (Zero Runtime Overhead)

Always prefer high-performance single-purpose CLI binaries for instant execution with minimum tokens:

- **Codebase Reconnaissance & Fingerprinting**:
  - Instant language, file count, and SLOC breakdown $\rightarrow$ `tokei .` (obtains full codebase makeup in < 100 tokens; use before traversing unfamiliar projects).
- **Structural Code Analysis & Refactoring**:
  - Semantic AST matching or structural rewrites $\rightarrow$ `ast-grep run -p "PATTERN" -l <lang> <file>`.
  - Fast regex content search $\rightarrow$ `rg -n -M 200 "PATTERN" .` (ALWAYS pass `-M 200` to prevent minified line blowup; pass explicit path `.`; use `-g "!dist/**"` or `-g "!node_modules/**"` to skip build outputs).
  - Scope targeting (file list only) $\rightarrow$ `rg -l "PATTERN" .` or `rg -c "PATTERN" .`.
- **Path Traversal & File Discovery**:
  - Finding files and directories $\rightarrow$ `fd -e <ext>` or `fd -H "pattern" .` (use `-d <depth>` to prevent unbounded traversal; avoid `Get-ChildItem -Recurse` or `dir /s`).
- **File Preview & Content Inspection**:
  - Non-interactive line-ranged previews $\rightarrow$ `bat --paging=never --style=plain -r <start>:<end> <file>` (use `--style=plain` or `--style=numbers` to strip decorative borders).
  - PDF document inspection $\rightarrow$ `pdftotext -f <start_page> -l <end_page> <file.pdf> -` (extracts specific page ranges to stdout without exhausting context memory).
- **Tabular Data Analysis (CSV/TSV/Parquet)**:
  - Header inspection & stats $\rightarrow$ `xsv headers <file.csv>`, `xsv count <file.csv>`, `xsv stats <file.csv>` (never dump raw CSV into context).
  - Slice sampling $\rightarrow$ `xsv slice -i 1-5 <file.csv> | xsv table` (preview top records with minimal tokens).
  - OLAP & Analytical SQL Querying (DuckDB) $\rightarrow$ `duckdb <file.db>` or `duckdb -c "SELECT ... FROM 'data.parquet' LIMIT 5;"`.
- **Embedded Database & State Inspection (SQLite)**:
  - Schema inspection $\rightarrow$ `sqlite3 <file.db> ".schema"` or `sqlite3 <file.db> ".tables"`.
  - Sample querying $\rightarrow$ `sqlite3 -header -column <file.db> "SELECT * FROM <table> LIMIT 5;"`.
- **Network & HTTP API Probing**:
  - Modern concise API testing $\rightarrow$ `xh --headers GET <url>` or `xh POST <url> key=value` (avoids verbose curl flags; use `--headers` or `--body` to restrict output).
- **Disk & Storage Diagnostics**:
  - Directory tree space visualization $\rightarrow$ `dust -d 2 -p` (instantly spots oversized build folders, caches, or dependencies).
- **Structured Data Manipulation**:
  - JSON querying and formatting $\rightarrow$ `jq -c "<filter>" <file>` (prefer compact `-c` output to minimize token consumption; validate syntax via `jq empty <file>`).
  - YAML / XML / TOML querying and in-place editing $\rightarrow$ `yq "<filter>" <file>` (or `yq -i "<filter>" <file>`).
- **Text Replacement**:
  - Fast, safe in-place regex or string literal replacement $\rightarrow$ `sd "pattern" "replacement" <file>` (use `sd -F "literal" "replacement" <file>` for fixed strings). STRICTLY FORBIDDEN to use `sed`.
- **CI/CD Workflow Static Analysis (`actionlint`)**:
  - Lint GitHub Actions workflows $\rightarrow$ `actionlint` (verifies syntax, matrix definitions, runner directives).
- **Execution Benchmarking (`hyperfine`)**:
  - High-precision command runtime benchmarking $\rightarrow$ `hyperfine '<cmd1>' '<cmd2>'` (replaces ad-hoc `Measure-Command`).
- **Pre-installed Custom CLI Tools (`cli/*.ps1` on PATH)**:
  - ALWAYS treat custom CLI scripts as black boxes and run `<cmd> --help` or `<cmd> -h` first:
  - `webread`: Token-efficient clean Markdown extraction (`webread <url>`, `webread --llms <url>`, `webread --raw <url> -o <file>`).
  - `ua`: One-click toolchain upgrade (`winget`, Vite+, Node.js LTS) and parallel Git repository pull (`ua --help`).
  - `up`: Automated Node.js / Vite+ dependency upgrade and verification gatekeeper (`up --help`).
  - `unodev`: Synchronize `engines.node` in `package.json` across all workspace projects (`unodev --help`).
  - `mkclp`: Video clipping with stream copy / hardware or `libx264` fallback and browser cookie support (`mkclp --help`).
  - `mkgif`: High-quality GIF creation via `gifski` or 256-color diff palette (`mkgif --help`).
  - `mdig`: Parallel multi-server DNS A & AAAA query and grouping (`mdig --help`).
  - `clall`: Parallel GitHub repository cloner (`clall --help`).
  - `ebk`: Browser extension config backup and git sync (`ebk --help`).
  - `rea`: MKV ASS subtitle combiner (`rea --help`).
  - `mmb`: Open current build repository in VS Code (`mmb --help`).

### Tier 2: PowerShell 7 In-Memory Glue & Parallel Processing (`pwsh`)

- **Zero Throwaway Script Mandate**:
  - NEVER create ephemeral script files (`temp.py`, `scratch.js`, `test.ps1`) on disk for ad-hoc queries, transformations, or glue logic.
  - Execute multi-command automation strictly in-memory via `pwsh -NoLogo -NoProfile -Command '...'`.
- **High-Speed Batch Parallelism**:
  - Run multi-file or multi-endpoint tasks using `$items | ForEach-Object -Parallel { ... } -ThrottleLimit 8`.
- **Native UTF-8 Output Guard**:
  - Prefix execution with `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)` to prevent CP950 mojibake.
- **Modern Language Operators**:
  - Leverage ternary (`$cond ? $a : $b`), null-coalescing (`$a ?? $b`, `$a ??= $b`), and pipeline chaining (`&&`, `||`).
- **Fast Hashtable Parsing**:
  - Use `ConvertFrom-Json -AsHashtable` to manipulate structured JSON directly in-memory without `PSCustomObject` overhead.

### Tier 3: Node.js & Frontend Toolchain (Vite+ Native Only)

- **Immediate Post-Edit Formatting**:
  - Run `vpx oxfmt <files>` (or `vp fmt <files>`) immediately after modifying Markdown, JSON, TypeScript, or CSS files.
- **Type Checking & Linting**:
  - Run `vp lint -f agent` or `vpx oxlint -f agent`.
- **Project Script Execution**:
  - Run `vpr <script>` or `vp run <script>`.
  - STRICTLY FORBIDDEN to invoke `npx`, `pnpm dlx`, `bunx`, or `npm run`.

### Tier 4: Heavy Compute & Domain Libraries (Python)

- Reserve Python strictly for project-native workflows (e.g. machine learning, heavy numerical analysis, PyTorch, Pandas, OpenCV).
- Do NOT generate throwaway Python scripts for file iteration, string parsing, or JSON extraction tasks that are already covered by Tier 1 and Tier 2.

---

## 2. Progressive Reconnaissance & Token-Saving Protocols

To maximize agent precision and eliminate context bloat, execute tasks along five progressive levels:

```text
[L0: Macro Recon]    tokei .                  -> Languages, file counts, code size (< 100 tokens)
[L1: Scope Filter]   rg -l "query" .          -> Target file paths only (no matching lines)
[L2: Syntax Outline] ast-grep run -p "..."    -> Function/class signatures only
[L3: Window Preview] bat --style=plain -r N:M -> Read exact line window (< 100 lines)
[L4: Verification]   <test> | Select -First 50 -> Terminal circuit breaker prevents log deluge
```

---

## 3. Windows 11 & PowerShell Execution Guardrails

1. **Subshell Stdin Protection**:
   - Background subshells pipe standard input. Commands like `rg`, `jq`, `sd`, `xsv`, or `tokei` will hang indefinitely if invoked without a target path or input stream.
   - ALWAYS provide explicit file or directory paths (e.g. `rg -n "TODO" .`, `tokei .`).
2. **PowerShell 7 (`pwsh`) vs Windows PowerShell 5.1 (`powershell.exe`)**:
   - Reserve `powershell.exe` exclusively as the Windows OS in-box host shell. NEVER attempt to replace, overwrite, or symlink `powershell.exe` in `System32`.
   - Note that fresh Windows 11 systems default to Windows PowerShell 5.1 (`powershell.exe`); bootstrap scripts (`scripts/install.ps1`) must remain compatible with both PowerShell 5.1 and PowerShell 7+.
   - Prefer `pwsh` for CLI tools (`cli/*.ps1`) and automation requiring parallel execution (`ForEach-Object -Parallel`), modern syntax operators (`? :`, `??`, `&&`, `||`), or consistent UTF-8 pipeline output.
3. **Native Windows 11 Utilities**:
   - Archive extraction & streaming: Windows 11 ships with native `tar.exe` (`C:\Windows\System32\tar.exe`) and `curl.exe` (`C:\Windows\System32\curl.exe`). In PowerShell, invoke `curl.exe` explicitly (with `.exe`) to avoid hitting PowerShell's `Invoke-WebRequest` alias if ever needed.
4. **Dev Drive (`E:\`) Awareness**:
   - High-I/O workspaces (`E:\_Workspace`) and toolchains (`VP_HOME = E:\vite-plus`) reside on the ReFS Dev Drive (`E:`) with Microsoft Defender asynchronous Performance Mode enabled.
5. **Array Unrolling & String Indexing Pitfall**:
   - In PowerShell, pipeline filters (e.g. `Where-Object`) unroll single-element results into a scalar `System.String`. Indexing a scalar string with `[0]` extracts the first character (`[char]'h'`) instead of the line. ALWAYS wrap pipeline outputs with `@(...)` before accessing `[0]`.
6. **Dual-Style CLI Flag Binding (PowerShell `-Param` & POSIX `--param`)**:
   - Always include `[Parameter(ValueFromRemainingArguments = $true)] [string[]]$RemainingArgs` and parse GNU-style `--flag` options into parameter variables.
7. **YouTube Protected Streaming & Section Downloads**:
   - Modern YouTube stream URLs (`googlevideo.com`) use Sabr/TVHTML5 token binding. Attempting direct playback via `ffmpeg -i <url>` results in `403 Forbidden`. Always use `yt-dlp --download-sections "*<START>-<END>"` (with browser cookie support `--cookies-from-browser chrome` and cookie-less fallback) to fetch snippet media directly to disk before processing with `ffmpeg` or `gifski`.

---

## 4. Pre-Execution Live Query & Authoritative Endpoints

- **PowerShell 7 (`pwsh`) Cmdlet Inspection**:
  - Syntax outline: `pwsh -NoLogo -NoProfile -Command "Get-Command <cmdlet> -Syntax"`
  - Parameter list: `pwsh -NoLogo -NoProfile -Command "(Get-Command <cmdlet>).Parameters.Keys"`
  - Official reference: `webread https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters`
- **Vite+ Toolchain (`vp`, `vpx`, `vpr`)**:
  - LLM Full Reference: `webread --llms https://viteplus.dev`
  - CLI Help: `vp help` / `vp --help`
- **Oxc (`oxfmt`, `oxlint`)**:
  - LLM Reference: `webread --llms https://oxc.rs`
  - CLI Help: `vpx oxlint --help`, `vpx oxfmt --help`
- **ast-grep (`ast-grep`)**:
  - LLM Reference: `webread --llms https://ast-grep.github.io`
  - CLI Help: `ast-grep --help`
