# macOS Darwin Execution Rules & Environment Invariants

## 1. Shell Execution Invariants & Anti-Patterns (macOS Specific)

- **Bare Commands Only (No Absolute Path Prefixes)**:
  - STRICTLY PROHIBITED to prefix CLI commands with absolute paths (e.g., `/usr/bin/git`, `/bin/zsh`, `/usr/bin/python`, `/usr/local/bin/...`, `/opt/homebrew/bin/...`).
  - ALWAYS execute bare command names directly (e.g., `git`, `zsh`, `pwsh`, `vp`, `node`, `rg`, `fd`, `webread`) relying on `$PATH`. Prefixing absolute paths breaks Antigravity's security allowlist matching and triggers intrusive confirmation prompts.
- **Homebrew Environment Resolution**:
  - Homebrew on Apple Silicon installs binaries to `/opt/homebrew/bin` (on Intel to `/usr/local/bin`).
  - Shell scripts and profiles source `eval "$(/opt/homebrew/bin/brew shellenv)"`. Agents rely on inherited `$PATH` without manually referencing `/opt/homebrew/bin`.
- **Absolute Prohibition on `sed` and `eval`**:
  - `sed` is completely prohibited and excluded from permission allowlists. For text replacements, ALWAYS use `sd`. For previewing lines, use `bat` or `awk`.
  - NEVER use `eval` or dynamic variable execution (e.g. `cmd="..."; eval $cmd`). Execute commands directly.
- **Local Git Invariant**:
  - Use native bare `git` (NEVER `/usr/bin/git`). Do NOT use `gh` (GitHub CLI) to query remote PRs or issues.

---

## 2. macOS BSD Compatibility Traps (Linux/GNU Forbidden)

macOS Darwin uses FreeBSD-derived userland utilities. Agents MUST observe the following constraints:

- **`head` / `tail`**:
  - Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`.
  - For line ranges, use `bat --paging=never --style=plain -r 1:3 <file>` or `awk 'NR>=1&&NR<=3' <file>`.
- **`grep`**:
  - BSD grep DOES NOT support Perl-compatible regex (`-P`). ALWAYS use `rg` for advanced pattern matching.
- **`xargs`**:
  - BSD xargs DOES NOT support `-r` (`--no-run-if-empty`). Use `fd -X` or standard POSIX `while read` loops instead.
- **`date`**:
  - BSD date DOES NOT support GNU `date -d`.
  - Use Node.js (`node -e "..."`) or PowerShell 7 (`pwsh -NoLogo -NoProfile -Command "..."`) for relative date arithmetic.
- **`awk`**:
  - Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- **`stat`**:
  - BSD syntax only: use `stat -f "%z"` for byte size (never Linux `stat -c`).
- **Network & Port Diagnostics**:
  - Check open ports using `lsof -i :<PORT>` (never Linux `ss` or `netstat -p`).

---

## 3. Idiomatic Zsh Execution & Scripting Standards

- **Strict Script Header**:
  - Always begin Zsh automation scripts (`scripts/*.sh`, `configs/zsh/*`) with:
    ```zsh
    #!/bin/zsh
    emulate -L zsh
    set -euo pipefail
    ```
- **Zsh 1-Based Indexing & Modifiers**:
  - Zsh arrays are **1-based** (`$arr[1]`), not 0-based.
  - Prefer native parameter expansion modifiers over external commands:
    - `${file:A}`: Absolute canonical path (resolves symlinks)
    - `${file:h}`: Parent directory (`dirname`)
    - `${file:t}`: Trailing filename (`basename`)
    - `${file:e}`: Extension
    - `${file:r:t}`: Basename without extension
- **Zsh Glob Qualifiers**:
  - Use native Zsh qualifiers: `*(N)` (nullglob), `*(-@N)` (broken symlinks), `*(.)` (plain files).

---

## 4. PowerShell 7 (`pwsh`) Symlink Execution on macOS

- **Extensionless Symlink Path Resolution**:
  - Cross-platform CLI scripts (`cli/*.ps1`) are symlinked into `~/.local/bin/<cmd>` without extension.
  - When `pwsh` runs an extensionless symlink via shebang, PowerShell runs it as an anonymous `ScriptBlock` where `$PSScriptRoot` and `$PSCommandPath` are empty string (`""`).
  - Furthermore, `~/.local/bin/<cmd>` points to `cli/<cmd>.ps1`.
  - Any script resolving repository-relative paths MUST inspect `[Environment]::GetCommandLineArgs()` and use `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)` to resolve the real script directory.
