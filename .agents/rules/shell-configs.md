---
trigger: glob
globs: "configs/bash/*, configs/zsh/*, scripts/*.sh, scripts/*.ps1"
description: Rules for shell configuration parity and cross-platform installer script idempotency.
---

# Shell Configuration & Cross-Platform Installer Rules

## 1. Directory Layout & Platform Installers

The repository provides automated, idempotent environment provisioning across **macOS** and **Windows 11**:

- **macOS Shell Configs**:
  - `configs/bash/`: `bash_profile`, `bashrc` (deployed to `~/.bash_profile`, `~/.bashrc`).
  - `configs/zsh/`: `zshenv`, `zprofile`, `zshrc`, `completions/_*` (deployed to `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.local/share/zsh/site-functions/`).
- **macOS Installer (`scripts/install.sh`)**:
  - Written in idiomatic Zsh (`#!/bin/zsh`, `emulate -L zsh`, `set -euo pipefail`).
  - Bootstraps Homebrew, installs `powershell` (`pwsh`) and modern CLI formulas/casks, links `cli/*.ps1` to `~/.local/bin/<cmd>`, and deploys `common-modern-tools`, `macos-modern-tools` and `modern-web-stack` plugins to `~/.gemini/config/plugins/`.
- **Windows 11 Installer (`scripts/install.ps1`)**:
  - Must be **strictly compatible with both Windows PowerShell 5.1 (`powershell.exe`, default on fresh Windows 11) and PowerShell 7+ (`pwsh.exe`)**.
  - **Prohibited in `scripts/install.ps1`**: Never use PowerShell 7-only operators (`? :`, `??`, `??=`, `?.`, `&&`, `||`, `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`).
  - Always write UTF-8 files without BOM using `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))`.
  - Deploys `common-modern-tools`, `win11-modern-tools` and `modern-web-stack` plugins to `$HOME\.gemini\config\plugins\` and registers `cli/` in User `PATH`.

---

## 2. Idempotency & Formatting Standards

- All shell configurations and installer tasks must be idempotent (safe to run repeatedly without duplicate `PATH` entries or side effects).
- Format Zsh/Bash files with: `shfmt -i 2 -ci -w <file>` (installed on both macOS via Homebrew and Windows 11 via WinGet `mvdan.shfmt`).
- Format PowerShell files with `Invoke-Formatter` (`PSScriptAnalyzer`, LF `\n`, UTF-8 without BOM) and verify AST syntax with `pwsh -NoLogo -NoProfile`.
