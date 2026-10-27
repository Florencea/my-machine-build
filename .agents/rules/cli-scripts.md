---
trigger: glob
globs: "cli/*.ps1"
description: Rules for managing, authoring, and verifying cross-platform PowerShell 7 CLI scripts in cli/.
---

# Cross-Platform PowerShell 7 CLI Script Rules

## 1. Naming, Permissions & Strict Header

- Store executable cross-platform PowerShell 7 scripts under `cli/<command>.ps1`.
- Begin every script with the cross-platform `env -S` shebang (which runs `pwsh -NoLogo -NoProfile` on macOS/Linux and is treated as a comment on Windows):
  ```powershell
  #!/usr/bin/env -S pwsh -NoLogo -NoProfile
  ```
- Enforce strict mode and UTF-8 output encoding at the top of the script:
  ```powershell
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  ```
- Ensure scripts have executable permissions on macOS/Linux: `chmod +x cli/<command>.ps1`.

---

## 2. Direct `$args` Parsing & Symlink-Safe Path Resolution

- **Direct `$args` Parsing (No `[CmdletBinding()] param(...)`)**:
  - Parse CLI arguments directly from `$args` (`for ($i = 0; $i -lt $args.Count; $i++) { $arg = [string]$args[$i] ... }`) rather than `[CmdletBinding()] param(...)`.
  - Avoiding `[CmdletBinding()]` prevents PowerShell's `ParameterBinder` and CommonParameters (`-WarningAction`, `-OutVariable`, `-Verbose`, `-Debug`) from colliding with short POSIX flags (`-w`, `-o`, `-v`, `-d`).
  - Support both POSIX/GNU style (`--llms`, `--quality`, `-w`, `-h`, `--help`) and PowerShell style (`-Llms`, `-Quality`, `-Width`, `-Help`) via case-insensitive regex matching (`-match`).
- **Extensionless Shebang & Symlink Path Resolution (`Get-ScriptDirectory`)**:
  - When `pwsh` executes an extensionless file via shebang on macOS/Linux (e.g., `~/.local/bin/ua`), PowerShell's engine runs it as an anonymous `ScriptBlock` and leaves `$PSScriptRoot` and `$PSCommandPath` empty (`""`).
  - Furthermore, `~/.local/bin/<cmd>` is a symlink whose parent directory is `~/.local/bin`, not `cli/`.
  - Any script that resolves paths relative to the repository MUST resolve the physical target path via `$PSCommandPath` with `[Environment]::GetCommandLineArgs()` fallback and `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)`.
- **PowerShell 7.4+ Native Byte-Stream Piping**:
  - Pipe binary streams directly between external native commands (`& ffmpeg ... | & gifski ...`) relying on PowerShell 7.4+ default `PSNativeCommandPreserveBytePipe` rather than `sh -c` or `cmd.exe /c` string interpolation.

---

## 3. System Exposure (`~/.local/bin` on macOS & User `PATH` on Windows)

- **macOS**: All CLI scripts are exposed system-wide without the `.ps1` extension via `$HOME/.local/bin`:
  ```bash
  ln -sf "$PWD/cli/<command>.ps1" "$HOME/.local/bin/<command>"
  ```
- **Windows 11**: The `cli/` directory is registered in User `PATH` via `scripts/install.ps1`, allowing direct invocation without typing `.ps1`.

---

## 4. Cross-Platform Formatting & AST Syntax Verification

- **Formatting (`PSScriptAnalyzer` / `ms-vscode.powershell`)**:
  - Format all `.ps1` scripts using `Invoke-Formatter` (`PSScriptAnalyzer`) and save with LF (`\n`) line endings and UTF-8 without BOM so the `#!/usr/bin/env -S pwsh -NoLogo -NoProfile` shebang works identically across macOS and Windows 11.
- **AST Syntax Verification**:
  - Before staging any `cli/*.ps1` changes, verify zero syntax errors using the PowerShell language parser:
    ```bash
    pwsh -NoLogo -NoProfile -Command '$errors = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("cli/<command>.ps1", [ref]$null, [ref]$errors); if ($errors) { $errors; exit 1 }'
    ```
