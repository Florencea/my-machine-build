# Windows 11 Platform Execution Rules & Safety Guardrails

## 1. Subshell Stdin Protection (Prevent Hangs)

- **Subshell Stdin Protection**:
  - Automated background processes pipe standard input. Never invoke commands that wait for stdin stream when omitted with arguments.
  - ALWAYS specify search paths or inputs explicitly:
    - Use `rg -n -M 200 "pattern" .` instead of bare `rg "pattern"`.
    - Use `tokei .` instead of bare `tokei`.
    - Use `sd "pattern" "replacement" <file>` with explicit file targets.
    - Provide input or file to `jq`, `yq`, `xsv`, `ast-grep`.

---

## 2. PowerShell 7 (`pwsh`) Execution & Double-Shell Invocation Protocol

- **Runtime Isolation**:
  - Strictly distinguish between legacy in-box **Windows PowerShell 5.1** (`powershell.exe`) and high-performance **PowerShell 7+** (`pwsh.exe`).
  - NEVER modify, replace, or symlink `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
  - Bootstrap scripts like `scripts/install.ps1` that bootstrap fresh machines must remain strictly compatible with Windows PowerShell 5.1 (no `? :`, `??`, `&&`, `||`, `ForEach-Object -Parallel`).
- **Double-Shell Invocation & Quote-Stripping Defense**:
  - In Antigravity's Windows execution environment, the host shell is **Windows PowerShell 5.1** (`powershell.exe`).
  - When executing `pwsh.exe -NoLogo -NoProfile -Command '...'`, Windows PowerShell 5.1 strips double quotes inside single quotes when launching external native processes.
  - **Safe Invocation Patterns**:
    - **Single-Quote Literals**: Use single quotes for string literals inside the script (e.g., `$p = 'C:\path\to\dir'`).
    - **Base64 Encoded Command (`-EncodedCommand`)**: For multi-line logic or complex expressions containing multiple quote levels, encode UTF-16LE bytes to Base64 to bypass outer shell quote-stripping:
      ```powershell
      $cmd = @'
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      # script logic...
      '@
      $bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
      $b64 = [Convert]::ToBase64String($bytes)
      pwsh -NoLogo -NoProfile -EncodedCommand $b64
      ```
    - **Atomic Commands**: Prefer composing atomic single-action tool calls over long, fragile multi-statement string scripts.
- **Modern PowerShell 7 Invocations**:
  - Whenever parallel processing, modern language operators, or UTF-8 non-ASCII output streams are required, explicitly invoke `pwsh -NoLogo -NoProfile -Command '...'`.
  - **Native UTF-8 Stream Enforcement**: PowerShell 7 defaults to UTF-8 without BOM. Ensure outer console decoding guard: `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)`.
  - **Modern Syntax Utilization (PS 7+ Only)**: Leverage ternary operators (`$cond ? $a : $b`), null-coalescing (`$a ?? $b`, `$a ??= $b`), and pipeline chain operators (`&&`, `||`) in `pwsh` scripts.
  - **Array Unrolling & Indexing Guard**: Pipeline outputs unroll single items into scalar values. Indexing `[0]` on a scalar string extracts `[char]` (e.g. `'https://...'[0] == 'h'`). ALWAYS wrap pipeline or split outputs with `@(...)` before accessing `[0]`.
  - **Dual-Style CLI Flag Binding**: Cross-platform `cli/*.ps1` scripts should parse `$args` directly (avoiding `[CmdletBinding()]` CommonParameters collisions) to support both GNU-style `--flag` and PowerShell `-Flag` options.
  - **Parallel Batch Processing**: Utilize `ForEach-Object -Parallel` with `-ThrottleLimit` for batch operations (e.g. multi-file queries, hash calculation, multi-repo git sync) to minimize execution latency.

---

## 3. Fail-Fast & Script Safety Invariant

- **Mandatory Fail-Fast Declaration**:
  - Every multi-step, multi-line, or non-trivial script executed via `pwsh -Command` or `pwsh -EncodedCommand` MUST declare fail-fast error handling at the very beginning:
    ```powershell
    $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
    ```
  - Never allow a script to continue execution if a prior variable assignment, path resolution, or command fails.
- **Explicit Exit Codes**:
  - Scripts must signal errors via non-zero exit codes or exceptions (`throw "..."`), never silently swallowing errors or continuing with `$null` state.

---

## 4. Destructive File Operation Guardrails & Defensive Assertions

- **Strict Ban on Bare Recursive Operations**:
  - `Copy-Item -Recurse`, `Remove-Item -Recurse`, and `robocopy /MIR` are STRICTLY FORBIDDEN without prior defensive path validation.
- **Defensive Path Assertion Guard**:
  - Prior to invoking recursive copy, move, or delete operations, the script MUST explicitly assert that source and destination paths are non-null, non-whitespace, and valid:
    ```powershell
    if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) {
        throw "Source path is null, whitespace, or non-existent: '$src'"
    }
    if ([string]::IsNullOrWhiteSpace($dest)) {
        throw "Destination path cannot be null or whitespace"
    }
    ```
- **Ban on Ambiguous Wildcards**:
  - Never use unanchored wildcards (such as `"$src\*"` or `*.*`) with unverified destination paths. Explicit directory structures must be pre-created via `New-Item -ItemType Directory -Force` before copy operations.

---

## 5. Binary & Large File Ingestion Ban (Resource Exhaustion Guard)

- **Strict Ban on In-Memory Ingestion of Large Files & Binaries**:
  - NEVER call `[System.IO.File]::ReadAllBytes`, `ReadAllText`, or `Get-Content -Raw` in PowerShell on files exceeding **1 MB** or binary executables (`.exe`, `.dll`, `.bin`, `.iso`, `.zip`).
  - Loading large binaries into .NET strings and executing unanchored regular expressions causes massive memory allocation (hundreds of MBs) and pins CPU at 100%, causing terminal deadlocks.
- **Native Streaming CLI SSOT for Binary Inspection**:
  - Always inspect binary files or search for embedded strings using native, streaming Rust/C CLI tools:
    ```bash
    rg -a -M 200 "pattern" <binary-file>
    ```
  - Native `rg -a` executes with near-zero memory footprint in milliseconds without managed heap allocation.
- **File Size Gate**:
  - If a script must read file content into memory, verify the file size before reading:
    ```powershell
    if ((Get-Item -LiteralPath $filePath).Length -gt 1MB) {
        throw "File size exceeds 1MB limit for in-memory processing: $filePath"
    }
    ```

---

## 6. Git-First Incident Recovery Protocol

- **Immediate Halt on Directory Pollution**:
  - When unexpected directory trees, massive untracked files, or accidental copies occur inside a Git repository, **IMMEDIATELY STOP** all file-system operations.
  - STRICTLY FORBIDDEN to attempt manual recursive deletion (`Remove-Item -Recurse`, `rd /s /q`, `robocopy /purge`). In Windows, deeply nested paths (such as `.pnpm` or `node_modules`) exceed the 260-character `MAX_PATH` limit and often trigger file locking, causing process hangs.
- **Standard Git Clean Recovery**:
  - Restore repository integrity cleanly and safely using Git's built-in long-path-aware commands:
    ```bash
    git -c core.longpaths=true clean -ffdx
    git checkout -- .
    ```
- **Transparent Reporting**:
  - If Git recovery encounters locked files or permission issues, immediately report the exact status to the user rather than running repeated brute-force deletion loops.

---

## 7. Windows 11 Native Utilities & Dev Drive

- **Native Utilities**:
  - Windows 11 includes native `tar.exe` and `curl.exe` in `System32`.
  - In PowerShell, always call `curl.exe` with the `.exe` extension to avoid invoking the legacy `Invoke-WebRequest` alias.
- **Dev Drive (`E:\`) & ReFS Performance Mode**:
  - Workspace `E:\_Workspace` and Vite+ toolchain directory `VP_HOME = E:\vite-plus` reside on ReFS Dev Drive (`E:`).
  - Microsoft Defender operates in asynchronous Performance Mode on Dev Drive volumes, significantly accelerating I/O.

---

## 8. Mandatory PowerShell Script Quality Gate & VS Code Formatter Alignment

- **Post-Edit Verification & Formatting Invariant**:
  - Whenever you create, modify, or refactor any PowerShell script (`*.ps1`, `*.psm1`, `*.psd1`), you MUST execute static analysis and formatting using `PSScriptAnalyzer` before taking further actions, staging changes, or concluding the task.
  - Verification must achieve **0 Errors and 0 Warnings** against `PSScriptAnalyzerSettings.psd1`.
- **VS Code Global Formatting Parity**:
  - Code formatting must strictly adhere to the user's VS Code configuration:
    - **Preset**: `Stroustrup` style (opening brace `{` on the same line as statements, closing brace `}` on a separate line).
    - **Indentation**: 4 spaces (`Kind = 'space'`, `IndentationSize = 4`, `PipelineIndentation = 0`). Tabs are prohibited.
    - **Line Endings & Encoding**: LF (`\n`) and UTF-8 without BOM. Trailing whitespace must be stripped, and files must end with a single newline.
    - **Whitespace & Delimiters**: Space around pipes (`|`), operators, parameter separators, and parentheses. Semicolons as line terminators (`;`) are prohibited.
    - **Syntax Conventions**: Constant strings without variable interpolation must use single quotes (`'...'`). Cmdlet names and keywords must use canonical PascalCase. Hashtable assignment operators (`=`) must be aligned.
- **Static Analysis Quality Gate (Zero Fixable Warnings)**:
  - All common script warnings must be completely resolved:
    - `PSAvoidUsingCmdletAliases`: Cmdlet aliases (`select`, `where`, `dir`, `echo`, `gc`, `sc`) are strictly banned in script files. Use full cmdlet names (`Select-Object`, `Where-Object`, `Get-ChildItem`, etc.).
    - `PSAvoidUsingEmptyCatchBlock`: Catch blocks must never be left empty. Always log, rethrow, or record errors.
    - `PSUseUsingScopeModifierInNewRunspaces`: Variables referenced inside `ForEach-Object -Parallel` or background runspaces must use the `$using:` scope modifier.
    - `PSUseDeclaredVarsMoreThanAssignments`: Unused or abandoned variables must be removed.
- **Rule Exclusions & Suppressions**:
  - `PSUseBOMForUnicodeEncodedFile` is excluded because cross-platform shebang scripts (`#!/usr/bin/env -S pwsh`) break under UTF-8 BOM on Unix kernels (`exec: format error`).
  - `PSAvoidUsingWriteHost`: Permitted in user-facing CLI utilities or installer scripts that require colored terminal output, guarded by `[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]`. In internal utility functions or non-interactive automation, use `Write-Output` or pipeline objects.
- **Standard Verification Commands**:
  - Run static analysis:
    ```powershell
    pwsh -NoLogo -NoProfile -Command "Invoke-ScriptAnalyzer -Path <file.ps1> -Settings ./PSScriptAnalyzerSettings.psd1"
    ```
  - Format script definition:
    ```powershell
    pwsh -NoLogo -NoProfile -Command "$content = Get-Content -LiteralPath <file.ps1> -Raw; $formatted = Invoke-Formatter -ScriptDefinition $content -Settings ./PSScriptAnalyzerSettings.psd1; [System.IO.File]::WriteAllText((Resolve-Path <file.ps1>), $formatted.TrimEnd() + \"`n\", [System.Text.UTF8Encoding]::new($false))"
    ```
