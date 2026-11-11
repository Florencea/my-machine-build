# Windows Platform Execution Rules & Safety Guardrails (Windows 11 & Windows 10 IoT LTSC)

## 1. PowerShell 7 (`pwsh`) Execution & Double-Shell Invocation Protocol

- **Runtime Isolation**:
  - Strictly distinguish between legacy in-box **Windows PowerShell 5.1** (`powershell.exe`) and high-performance **PowerShell 7+** (`pwsh.exe`).
  - NEVER modify, replace, or symlink `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
  - Bootstrap scripts (`scripts/install.ps1`) targeting fresh machines must remain strictly compatible with Windows PowerShell 5.1 (no `? :`, `??`, `&&`, `||`, `ForEach-Object -Parallel`).
- **Double-Shell Invocation & Quote-Stripping Defense**:
  - In Antigravity's Windows execution environment, the host shell is **Windows PowerShell 5.1** (`powershell.exe`).
  - When executing `pwsh.exe -NoLogo -NoProfile -Command '...'`, Windows PowerShell 5.1 strips double quotes inside single quotes when launching external native processes.
  - **Safe Invocation Patterns**:
    - Single-Quote Literals: Use single quotes for string literals inside the script (`$p = 'C:\path\to\dir'`).
    - Base64 Encoded Command (`-EncodedCommand`): For multi-line logic or complex expressions containing multiple quote levels, encode UTF-16LE bytes to Base64 to bypass outer shell quote-stripping:
      ```powershell
      $cmd = @'
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      # script logic...
      '@
      $bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
      $b64 = [Convert]::ToBase64String($bytes)
      pwsh -NoLogo -NoProfile -EncodedCommand $b64
      ```
    - Prefer composing atomic single-action tool calls over long, fragile multi-statement string scripts.
- **Fail-Fast & Output Encoding**:
  - Every script executed via `pwsh -Command` or `-EncodedCommand` MUST declare fail-fast error handling:
    ```powershell
    $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
    ```
  - Enforce native UTF-8 stream output: `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)`.
- **Array Unrolling & Indexing Guard**:
  - PowerShell pipelines unroll single items into scalar values. Indexing `[0]` on a scalar string extracts `[char]` (e.g. `'https://...'[0] == 'h'`). ALWAYS wrap pipeline or split outputs with `@(...)` before accessing `[0]` or checking `.Count`.

---

## 2. Cross-Version Compatibility Boundaries (PS 5.1 vs PS 7+)

- **`$IsWindows` StrictMode Guard**:
  - In dual-version scripts (`#Requires -Version 5.1`), `$IsWindows` is undefined in PS 5.1 and throws an error under `Set-StrictMode -Version Latest`. Guard with:
    ```powershell
    $isWin = ($PSVersionTable.PSEdition -ne 'Core') -or $IsWindows
    ```
- **Operator Compatibility**:
  - In scripts targeting Windows PowerShell 5.1, NEVER use PS 7-only operators (`? :`, `??`, `??=`, `?.`, `&&`, `||`), `ForEach-Object -Parallel`, or `ConvertFrom-Json -AsHashtable`.
- **`String.Split` Overload Portability**:
  - Never call `$str.Split('ab')` with a multi-character string (.NET Framework 4.x splits by `char[]`, whereas .NET 8+ splits by substring). Always use PowerShell's `-split` operator or an explicit `[char[]]` cast.

---

## 3. Destructive File Operation Guardrails & Defensive Assertions

- **Defensive Path Assertion Guard**:
  - `Copy-Item -Recurse`, `Remove-Item -Recurse`, and `robocopy /MIR` are STRICTLY FORBIDDEN without prior defensive path validation:
    ```powershell
    if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) {
        throw "Source path is null, whitespace, or non-existent: '$src'"
    }
    if ([string]::IsNullOrWhiteSpace($dest)) {
        throw "Destination path cannot be null or whitespace"
    }
    ```
- **Ban on Ambiguous Wildcards**:
  - Never use unanchored wildcards (`"$src\*"` or `*.*`) with unverified destination paths. Explicit directory structures must be pre-created via `New-Item -ItemType Directory -Force` before copy operations.
  - For directory synchronization or batch copying, enumerate child items explicitly using `Get-ChildItem -LiteralPath $src` and copy each item via `-LiteralPath $_.FullName` to `-Destination $dest`.

---

## 4. Dev Drive (ReFS), Windows 10 IoT LTSC Matrix & Performance

- **Windows 11 vs Windows 10 IoT LTSC Capability Matrix**:
  - **Dev Drive (ReFS)**: Supported exclusively on Windows 11 Build 22621+. Dev Drive (`fsutil devdrv`) is strictly unavailable on Windows 10 IoT LTSC. On Windows 10, use standard NTFS storage (`$HOME\_Workspace`, `~/.vite-plus`) without attempting Dev Drive queries.
  - **Sudo Command**: Native `sudo.exe` requires Windows 11 Build 26052+. On Windows 10 IoT LTSC, privileged operations must use `Start-Process -Verb RunAs` or self-elevating scripts.
  - **PowerShell 7 AppX Barrier**: On Windows 10, the in-box `Appx` module throws `PlatformNotSupportedException` (`0x80131539`) under PowerShell 7 (.NET Core). AppX queries or package installations must be delegated to Windows PowerShell 5.1 (`powershell.exe -NoLogo -NoProfile -Command "..."`).
  - **WinGet Bootstrap Matrix**: Windows 11 provides in-box DesktopAppInstaller. Windows 10 IoT LTSC requires dependency bootstrapping (VCLibs, WindowsAppRuntime, AppXSvc service enablement, and AppModelUnlock sideloading).
- **Dev Drive Optimization (Windows 11 Only)**:
  - Dev Drive volumes formatted with ReFS support Copy-on-Write (Block Cloning) and disable synchronous filter drivers. Prioritize placing package caches (`PNPM_HOME`, `VITE_CACHE_DIR`) and Git workspaces on Dev Drive.
- **Windows Defender Process Exclusion**:
  - In development environments, verify that modern developer processes (`pwsh.exe`, `vp.exe`, `node.exe`, `git.exe`) and build directories (`dist`, `node_modules`) are excluded from real-time monitoring to prevent I/O bottlenecks.
