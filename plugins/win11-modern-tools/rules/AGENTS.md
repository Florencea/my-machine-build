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

## 2. PowerShell 7 (`pwsh`) Execution & Automation Protocol

- **Runtime Isolation**:
  - Strictly distinguish between legacy in-box **Windows PowerShell 5.1** (`powershell.exe`) and high-performance **PowerShell 7+** (`pwsh.exe`).
  - NEVER modify, replace, or symlink `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
  - Bootstrap scripts like `scripts/install.ps1` that bootstrap fresh machines must remain strictly compatible with Windows PowerShell 5.1 (no `? :`, `??`, `&&`, `||`, `ForEach-Object -Parallel`).
- **Modern PowerShell 7 Invocations**:
  - Whenever parallel processing, modern language operators, or UTF-8 non-ASCII output streams are required, explicitly invoke `pwsh -NoLogo -NoProfile -Command '...'`.
  - **Outer Shell Quoting**: Always wrap `pwsh -Command` parameters in single quotes (`'...'`) when called from an outer shell to prevent premature variable expansion.
  - **Native UTF-8 Stream Enforcement**: PowerShell 7 defaults to UTF-8 without BOM. Ensure outer console decoding guard: `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)`.
  - **Modern Syntax Utilization (PS 7+ Only)**: Leverage ternary operators (`$cond ? $a : $b`), null-coalescing (`$a ?? $b`, `$a ??= $b`), and pipeline chain operators (`&&`, `||`) in `pwsh` scripts.
  - **Array Unrolling & Indexing Guard**: Pipeline outputs unroll single items into scalar values. Indexing `[0]` on a scalar string extracts `[char]` (e.g. `'https://...'[0] == 'h'`). ALWAYS wrap pipeline or split outputs with `@(...)` before accessing `[0]`.
  - **Dual-Style CLI Flag Binding**: Cross-platform `cli/*.ps1` scripts should parse `$args` directly (avoiding `[CmdletBinding()]` CommonParameters collisions) to support both GNU-style `--flag` and PowerShell `-Flag` options.
  - **Parallel Batch Processing**: Utilize `ForEach-Object -Parallel` with `-ThrottleLimit` for batch operations (e.g. multi-file queries, hash calculation, multi-repo git sync) to minimize execution latency.

---

## 3. Windows 11 Native Utilities & Dev Drive

- **Native Utilities**:
  - Windows 11 includes native `tar.exe` and `curl.exe` in `System32`.
  - In PowerShell, always call `curl.exe` with the `.exe` extension to avoid invoking the legacy `Invoke-WebRequest` alias.
- **Dev Drive (`E:\`) & ReFS Performance Mode**:
  - Workspace `E:\_Workspace` and Vite+ toolchain directory `VP_HOME = E:\vite-plus` reside on ReFS Dev Drive (`E:`).
  - Microsoft Defender operates in asynchronous Performance Mode on Dev Drive volumes, significantly accelerating I/O.
