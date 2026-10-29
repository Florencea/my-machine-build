# macOS Darwin Execution Rules & Environment Invariants

## 1. Subshell Stdin Protection & Hanging Process Defense

- **Subshell Stdin Protection**:
  - Automated background processes and tool sessions on macOS pipe standard input. Never invoke commands that wait for stdin stream when invoked without arguments.
  - ALWAYS specify target search paths or inputs explicitly:
    - Use `rg -n -M 200 "pattern" .` instead of bare `rg "pattern"`.
    - Use `tokei .` instead of bare `tokei`.
    - Use `sd "pattern" "replacement" <file>` with explicit file targets.
    - Provide input streams or target files to `jq`, `yq`, `xsv`, `ast-grep`.
  - Omitting targets causes background subshells to hang indefinitely waiting for EOF.

---

## 2. Shell Execution Invariants & Anti-Patterns (macOS Specific)

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

## 3. Zsh Shell Traps & Execution Safety Invariants

- **Nomatch Fatal Error Guard (`*(N)` Nullglob Qualifier)**:
  - In Zsh, unmatched glob patterns trigger an immediate fatal error: `zsh: no matches found: <pattern>`, causing the entire tool command to fail.
  - When performing batch file operations where matches may be empty (e.g. cleaning temporary files, formatting specific file extensions), ALWAYS append the Zsh nullglob qualifier `*(N)`:
    ```zsh
    rm -f *.tmp(N)
    ```
- **Word Splitting Discipline**:
  - Unlike Bash, Zsh DOES NOT perform word splitting on unquoted variables `$var` by default.
  - Do not rely on whitespace splitting in unquoted variables; use Zsh arrays (`local -a items=(...)`) or explicit splitting (`${(s: :)var}`).
- **Fail-Fast in Multi-Step Shell Commands**:
  - When chaining multi-command one-liners, ALWAYS chain with `&&` or enforce strict failure stopping via:
    ```zsh
    set -euo pipefail
    ```
  - Never allow downstream file mutations to execute if a preceding path evaluation or build step fails.
- **Quoting & Escaping**:
  - POSIX and Zsh single quotes `'...'` cannot contain nested escaped single quotes `\'`.
  - For complex regex or strings with mixed quotes, use ANSI-C quoting `$'...\'...'` or double quotes with proper backslash escapes.

---

## 4. macOS BSD Compatibility Traps & GNU Prohibitions

macOS Darwin uses FreeBSD-derived userland utilities. Agents MUST observe the following constraints:

- **Strict Prohibition on `readlink -f`**:
  - BSD `readlink` DOES NOT support `-f` (canonicalize). Running `readlink -f <path>` fails with `illegal option -- f`.
  - ALWAYS resolve canonical physical paths using native Zsh parameter expansion `${file:A}` or `realpath <file>`.
- **`mktemp` Strict Template Requirement**:
  - BSD `mktemp` requires a template or `-t`. Bare `mktemp` fails or behaves unreliably.
  - ALWAYS use: `mktemp -t prefix.XXXXXX` or `mktemp /tmp/prefix.XXXXXX`.
- **System Diagnostics: The Absence of `/proc`**:
  - Darwin DOES NOT have a `/proc` filesystem. Commands like `cat /proc/cpuinfo` or `cat /proc/meminfo` fail immediately.
  - Use canonical Darwin system inspection utilities:
    - CPU cores: `sysctl -n hw.ncpu` (or `hw.logicalcpu`)
    - Physical Memory: `sysctl -n hw.memsize` (bytes) or `vm_stat`
    - OS Version: `sw_vers`
    - Hardware Overview: `system_profiler SPHardwareDataType`
- **Socket & Network Port Probing**:
  - Linux `ss` or `netstat -p` is not available on Darwin.
  - ALWAYS inspect listening ports with non-blocking numeric lookups:
    ```bash
    lsof -nP -iTCP:<PORT> -sTCP:LISTEN
    ```
- **POSIX Line Ranges (`head` / `tail`)**:
  - Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`.
  - For line ranges, use `bat --paging=never --style=plain -r <start>:<end> <file>` or `awk 'NR>=start&&NR<=end' <file>`.
- **Date Arithmetic**:
  - Darwin `date` does not support GNU `date -d`.
  - Use Node.js (`node -e "..."`) or PowerShell 7 (`pwsh -NoLogo -NoProfile -Command "..."`) for relative date arithmetic.
- **File Metadata & Sizing (`stat`)**:
  - BSD syntax only: `stat -f "%z"` for byte size (never Linux `stat -c`).
- **Stream Processing (`grep`, `awk`, `xargs`)**:
  - BSD grep lacks `-P` (Perl regex); always use `rg`.
  - BSD xargs lacks `-r` (`--no-run-if-empty`); use `fd -X` or standard POSIX `while read` loops.
  - Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.

---

## 5. APFS & Darwin Filesystem Safety Guardrails

- **APFS Copy-on-Write (CoW) Instant Cloning (`cp -c`)**:
  - APFS supports instant, zero-byte Copy-on-Write block cloning.
  - When backing up directories, snapshotting build artifacts, or cloning workspaces, ALWAYS use `cp -c` (or `cp -R -c`):
    ```bash
    cp -R -c src/ src.bak/
    ```
  - This executes in milliseconds with zero duplicate disk allocation until modified.
- **APFS Case-Preserving Case-Insensitive Rename Trap**:
  - Default macOS APFS filesystems are case-insensitive. Renaming `file.ts` to `File.ts` via standard `mv` is a no-op or causes collisions.
  - In Git repositories, ALWAYS use `git mv -f`:
    ```bash
    git mv -f file.ts File.ts
    ```
  - On the filesystem, perform a two-step rename via a temporary name: `mv file.ts file.ts.tmp && mv file.ts.tmp File.ts`.
- **Gatekeeper Quarantine & Extended Attributes (`com.apple.quarantine`)**:
  - Binaries, tools, or archives downloaded from the web acquire the `com.apple.quarantine` extended attribute, causing Gatekeeper to kill them (`zsh: killed`) or prompt intrusive dialogs.
  - Verify and strip quarantine attributes before running downloaded executables:
    ```bash
    xattr -d com.apple.quarantine <file> 2>/dev/null || true
    ```
- **AppleDouble (`._*`) Resource Forks & Archive Hygiene**:
  - macOS automatically embeds metadata as `._*` AppleDouble files when archiving.
  - Always set `COPYFILE_DISABLE=1` when packaging tarballs to prevent archive pollution:
    ```bash
    COPYFILE_DISABLE=1 tar -czf release.tar.gz <target>
    ```
  - Purge orphaned `.DS_Store` files using `fd -H "^\.DS_Store$" -X rm`.
- **Unicode Filename Normalization (NFD vs NFC)**:
  - macOS APFS/HFS+ normalizes filenames to decomposed form (NFD), whereas Linux/Windows use precomposed form (NFC).
  - When comparing filenames or matching non-ASCII/CJK characters in Node.js or scripts, always normalize string paths: `str.normalize('NFC')`.

---

## 6. Destructive File Operation Guardrails & Defensive Assertions

- **Strict Ban on Unchecked Recursive Deletion**:
  - `rm -rf` without explicit path existence checks is STRICTLY FORBIDDEN.
- **Defensive Path Assertion Guard**:
  - Before executing recursive file deletion or directory clearing, explicitly verify that the target path is non-null, non-whitespace, and exists:
    ```zsh
    if [[ -z "${TARGET_DIR:-}" || ! -d "$TARGET_DIR" ]]; then
      echo "Error: Target directory is unset, empty, or non-existent: '$TARGET_DIR'" >&2
      exit 1
    fi
    rm -rf "${TARGET_DIR:?}"/*
    ```
  - Never allow an unset variable to evaluate to `rm -rf /*` or bare `rm -rf /`.

---

## 7. Binary & Large File Ingestion Ban (Resource Exhaustion Guard)

- **Strict Ban on In-Memory Ingestion of Large Files & Binaries**:
  - NEVER use `cat`, Node.js `fs.readFileSync`, or PowerShell `[System.IO.File]::ReadAllText` on files exceeding **1 MB** or binary executables (`.dylib`, `.bin`, `.pkg`, `.dmg`, `.zip`).
  - Ingesting large files into memory exhausts context memory and causes terminal deadlocks.
- **Native Streaming CLI SSOT for Binary & Large File Inspection**:
  - Always inspect binary files or search for strings using streaming Rust CLI tools:
    ```bash
    rg -a -M 200 "pattern" <binary-file>
    ```
  - Use `bat -r <start>:<end>`, `awk`, or `head` for targeted line inspection.

---

## 8. Git-First Incident Recovery Protocol

- **Immediate Halt on Directory Pollution**:
  - When accidental recursive extraction, massive directory sprawl, or unorganized files pollute a Git workspace, **IMMEDIATELY STOP** all file mutations.
  - Do NOT attempt manual recursive shell deletions (`rm -rf`).
- **Standard Git Clean Recovery**:
  - Restore repository integrity cleanly and safely via native Git:
    ```bash
    git clean -ffdx
    git checkout -- .
    git status
    ```

---

## 9. Darwin Native Utilities & Architecture Awareness

- **Apple Silicon (`arm64`) vs Intel (`x86_64`)**:
  - Verify runtime architecture via `uname -m` (or `arch`).
  - Homebrew binary prefix defaults to `/opt/homebrew` on `arm64` and `/usr/local` on `x86_64`.
- **Native Clipboard & Desktop Interaction**:
  - Pipe text into macOS system clipboard: `pbcopy`
  - Read system clipboard: `pbpaste`
  - Open files, URLs, or applications: `open <path_or_url>`
- **System Administration & Preferences (`defaults`, `PlistBuddy`)**:
  - Modify system and application defaults: `defaults write <domain> <key> <value>`
  - Modify nested property list keys: `/usr/libexec/PlistBuddy -c "..." <plist-file>`

---

## 10. PowerShell 7 (`pwsh`) Symlink Execution on macOS

- **Extensionless Symlink Path Resolution**:
  - Cross-platform CLI scripts (`cli/*.ps1`) are symlinked into `~/.local/bin/<cmd>` without extension.
  - When `pwsh` runs an extensionless symlink via shebang, PowerShell runs it as an anonymous `ScriptBlock` where `$PSScriptRoot` and `$PSCommandPath` are empty string (`""`).
  - Furthermore, `~/.local/bin/<cmd>` points to `cli/<cmd>.ps1`.
  - Any script resolving repository-relative paths MUST inspect `[Environment]::GetCommandLineArgs()` and use `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)` to resolve the real script directory.
