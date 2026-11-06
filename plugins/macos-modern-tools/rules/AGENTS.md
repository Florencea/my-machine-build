# macOS Darwin Execution Rules & Environment Invariants

## 1. Shell Execution Invariants & Anti-Patterns (macOS Specific)

- **Bare Commands Only (No Absolute Path Prefixes)**:
  - STRICTLY PROHIBITED to prefix CLI commands with absolute paths (`/usr/bin/git`, `/bin/zsh`, `/usr/bin/python`, `/usr/local/bin/...`, `/opt/homebrew/bin/...`).
  - ALWAYS execute bare command names directly (`git`, `zsh`, `pwsh`, `vp`, `node`, `rg`, `fd`, `webread`) relying on `$PATH`. Prefixing absolute paths breaks Antigravity allowlist matching and triggers intrusive confirmation prompts.
- **Homebrew Environment Resolution**:
  - Apple Silicon installs binaries to `/opt/homebrew/bin` (Intel to `/usr/local/bin`). Shell profiles source `eval "$(/opt/homebrew/bin/brew shellenv)"`. Agents rely on inherited `$PATH` without manually referencing `/opt/homebrew/bin`.
- **Absolute Prohibition on `sed` and `eval`**:
  - `sed` is completely prohibited and excluded from permission allowlists. For text replacements, ALWAYS use `sd`. For previewing lines, use `bat` or `awk`.
  - NEVER use `eval` or dynamic variable execution (e.g. `cmd="..."; eval $cmd`). Execute commands directly.
- **Local Git Invariant**:
  - Use native bare `git` (NEVER `/usr/bin/git`). Do NOT use `gh` (GitHub CLI) to query remote PRs or issues.

---

## 2. Zsh Shell Traps & Execution Safety Invariants

- **Nomatch Fatal Error Guard (`*(N)` Nullglob Qualifier)**:
  - In Zsh, unmatched glob patterns trigger an immediate fatal error: `zsh: no matches found: <pattern>`.
  - When performing batch file operations where matches may be empty (e.g. cleaning temporary files, formatting specific file extensions), ALWAYS append the Zsh nullglob qualifier `*(N)`:
    ```zsh
    rm -f *.tmp(N)
    ```
- **Word Splitting Discipline**:
  - Unlike Bash, Zsh DOES NOT perform word splitting on unquoted variables `$var` by default. Use Zsh arrays (`local -a items=(...)`) or explicit splitting (`${(s: :)var}`).
- **Fail-Fast in Multi-Step Shell Commands**:
  - When chaining multi-command scripts or one-liners, ALWAYS chain with `&&` or enforce strict failure stopping via:
    ```zsh
    set -euo pipefail
    ```
- **Quoting & Escaping**:
  - POSIX and Zsh single quotes `'...'` cannot contain nested escaped single quotes `\'`. For complex regex or strings with mixed quotes, use ANSI-C quoting `$'...\'...'` or double quotes with backslash escapes.

---

## 3. macOS BSD Compatibility Traps & GNU Prohibitions

macOS Darwin uses FreeBSD-derived userland utilities. Agents MUST observe the following constraints:

- **Strict Prohibition on `readlink -f`**:
  - BSD `readlink` DOES NOT support `-f` (fails with `illegal option -- f`). ALWAYS resolve canonical physical paths using native Zsh parameter expansion `${file:A}` or `realpath <file>`.
- **`mktemp` Strict Template Requirement**:
  - BSD `mktemp` requires a template or `-t`. Bare `mktemp` fails. ALWAYS use `mktemp -t prefix.XXXXXX` or `mktemp /tmp/prefix.XXXXXX`.
- **Absence of `/proc`**:
  - Darwin DOES NOT have a `/proc` filesystem. Commands like `cat /proc/cpuinfo` fail immediately. Use canonical Darwin inspection utilities:
    - CPU cores: `sysctl -n hw.ncpu`
    - Physical Memory: `sysctl -n hw.memsize` (bytes) or `vm_stat`
    - OS Version: `sw_vers`
    - Hardware Overview: `system_profiler SPHardwareDataType`
- **Socket & Network Port Probing**:
  - Linux `ss` and `netstat -p` are unavailable. Inspect listening ports with non-blocking numeric lookups:
    ```bash
    lsof -nP -iTCP:<PORT> -sTCP:LISTEN
    ```
- **POSIX Line Ranges (`head` / `tail`)**:
  - Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `bat --paging=never --style=plain -r <start>:<end> <file>` or `awk 'NR>=start&&NR<=end' <file>`.
- **Date Arithmetic**: Darwin `date` does not support GNU `date -d`. Use Node.js (`node -e "..."`) or PowerShell 7 (`pwsh -NoLogo -NoProfile -Command "..."`) for relative date arithmetic.
- **File Sizing (`stat`)**: BSD syntax only: `stat -f "%z" <file>` for byte size (never Linux `stat -c`).
- **Stream Processing**: BSD grep lacks `-P` (always use `rg`). BSD xargs lacks `-r` (use `fd -X` or standard POSIX `while read` loops).

---

## 4. APFS & Darwin Filesystem Safety Guardrails

- **APFS Copy-on-Write (CoW) Instant Cloning (`cp -c`)**:
  - APFS supports instant, zero-byte Copy-on-Write block cloning. When backing up directories, snapshotting build artifacts, or cloning workspaces, ALWAYS use `cp -c` (or `cp -R -c`):
    ```bash
    cp -R -c src/ src.bak/
    ```
- **APFS Case-Preserving Case-Insensitive Rename Trap**:
  - Default macOS APFS filesystems are case-insensitive. Renaming `file.ts` to `File.ts` via standard `mv` is a no-op or causes collisions. In Git, ALWAYS use `git mv -f file.ts File.ts`. On the filesystem, perform a two-step rename via a temporary name: `mv file.ts file.ts.tmp && mv file.ts.tmp File.ts`.
- **Gatekeeper Quarantine (`com.apple.quarantine`)**:
  - Binaries downloaded from the web acquire the `com.apple.quarantine` extended attribute, causing Gatekeeper to kill them (`zsh: killed`). Verify and strip quarantine attributes before running downloaded executables:
    ```bash
    xattr -d com.apple.quarantine <file> 2>/dev/null || true
    ```
- **AppleDouble (`._*`) Resource Forks & Archive Hygiene**:
  - Set `COPYFILE_DISABLE=1` when packaging tarballs to prevent archive pollution:
    ```bash
    COPYFILE_DISABLE=1 tar -czf release.tar.gz <target>
    ```
  - Purge orphaned `.DS_Store` files using `fd -H "^\.DS_Store$" -X rm`.
- **Unicode Filename Normalization (NFD vs NFC)**:
  - macOS APFS normalizes filenames to decomposed form (NFD). When comparing filenames or matching non-ASCII characters in Node.js or scripts, always normalize string paths: `str.normalize('NFC')`.

---

## 5. Destructive File Operation Guardrails & Git Recovery

- **Defensive Path Assertion Guard**:
  - `rm -rf` without explicit path existence checks is STRICTLY FORBIDDEN. Before recursive deletion, explicitly verify that the target path is non-null, non-whitespace, and exists:
    ```zsh
    if [[ -z "${TARGET_DIR:-}" || ! -d "$TARGET_DIR" ]]; then
      echo "Error: Target directory is unset, empty, or non-existent: '$TARGET_DIR'" >&2
      exit 1
    fi
    rm -rf "${TARGET_DIR:?}"/*
    ```
- **Git-First Incident Recovery Protocol**:
  - When accidental extraction or directory sprawl pollutes a Git workspace, immediately stop file mutations and restore repository integrity via native Git:
    ```bash
    git clean -ffdx && git checkout -- . && git status
    ```

---

## 6. Darwin Native Utilities & Architecture Awareness

- **Architecture Verification**: Verify runtime architecture via `uname -m`. Homebrew defaults to `/opt/homebrew` on `arm64` and `/usr/local` on `x86_64`.
- **Native Clipboard & System Defaults**:
  - Pipe text into clipboard: `pbcopy`; read clipboard: `pbpaste`.
  - Modify application defaults: `defaults write <domain> <key> <value>`.
  - Modify property list keys: `/usr/libexec/PlistBuddy -c "..." <plist-file>`.

---

## 7. PowerShell 7 (`pwsh`) Execution & Symlink Resolution on macOS

- **Extensionless Symlink Path Resolution**:
  - Cross-platform CLI scripts (`cli/*.ps1`) are symlinked into `~/.local/bin/<cmd>` without extension. When `pwsh` runs an extensionless symlink via shebang, `$PSScriptRoot` and `$PSCommandPath` are empty (`""`).
  - Any script resolving repository-relative paths MUST inspect `[Environment]::GetCommandLineArgs()` and use `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)` to resolve the real script directory.
- **Unix Environment Case Sensitivity**:
  - On Darwin, environment variable names are strictly case-sensitive (`$env:PATH` is populated, whereas `$env:Path` is `$null`). Always use `$env:PATH`, `Join-Path`, `-LiteralPath`, and `[System.IO.Path]::PathSeparator` (`:`).
