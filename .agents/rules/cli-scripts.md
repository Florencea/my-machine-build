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

## 2. Mandatory `--help` & `-h` Support & Dual-Style Parameter Binding

- All CLI scripts under `cli/<command>.ps1` MUST implement `[CmdletBinding(PositionalBinding = $false)]` and `[Parameter(ValueFromRemainingArguments = $true)] [string[]]$RemainingArgs`.
- Support both PowerShell style (`-Llms`, `-Quality`, `-Help`) and POSIX/GNU style (`--llms`, `--quality`, `-h`, `--help`) flags.
- Do NOT mark positional parameters with `Mandatory = $true` inside `param(...)`, as doing so causes PowerShell to interactively prompt for missing arguments before `--help` can be evaluated. Instead, evaluate `-h` / `--help` first and exit with code 0 (`exit 0`).

---

## 3. System Exposure (`~/.local/bin` on macOS & User `PATH` on Windows)

- **macOS**: All CLI scripts are exposed system-wide without the `.ps1` extension via `$HOME/.local/bin`:
  ```bash
  ln -sf "$PWD/cli/<command>.ps1" "$HOME/.local/bin/<command>"
  ```
- **Windows 11**: The `cli/` directory is registered in User `PATH` via `scripts/install.ps1`, allowing direct invocation without typing `.ps1`.

---

## 4. AST Syntax Verification

- Before staging any `cli/*.ps1` changes, verify zero syntax errors using the PowerShell language parser:
  ```bash
  pwsh -NoLogo -NoProfile -Command '$errors = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("cli/<command>.ps1", [ref]$null, [ref]$errors); if ($errors) { $errors; exit 1 }'
  ```
