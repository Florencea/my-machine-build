---
name: macos-toolchain
description: macOS Darwin platform execution rules, subshell stdin defense, Zsh glob nomatch guardrails, APFS Copy-on-Write cloning, BSD compatibility recipes, Apple system administration (defaults, scutil, PlistBuddy, launchservices), and PowerShell 7 symlink resolution. Use when running Darwin-specific workflows or configuring macOS system settings.
compatibility: macOS Darwin, Zsh 5+, PowerShell 7+
---

# macOS Darwin Toolchain & System Administration Guidelines

> [!NOTE]
> For universal high-performance CLI tools (`rg`, `fd`, `bat`, `sd`, `jq`, `yq`, `duckdb`, `sqlite3`, `xsv`, `xh`, `dust`, `pdftotext`, `shfmt`, `actionlint`, `hyperfine`, Vite+), refer to the **`common-toolchain`** skill.

---

## 1. Subshell Stdin Defense & Zsh Execution Pitfalls

### 1.1 Background Subshell Stdin Pitfall

In Antigravity on macOS, tools execute inside Zsh subshells that pipe standard input. Commands like `rg`, `tokei`, `jq`, `yq`, `sd`, `xsv`, or `ast-grep` will hang indefinitely waiting for EOF if invoked without explicit target paths or input streams:

```zsh
# BAD: Background subshell hangs indefinitely
rg "pattern"
tokei

# GOOD: Explicit paths or input sources
rg -n -M 200 "pattern" .
tokei .
```

### 1.2 Zsh Nomatch Fatal Error Guard (`*(N)`)

By default, Zsh treats an unmatched file glob as a fatal error (`zsh: no matches found: ...`) and terminates execution immediately with exit code 1.

```zsh
# BAD: If no .tmp files exist, Zsh aborts with fatal error:
rm -f *.tmp
vpx oxfmt docs/*.md

# GOOD: Use the Zsh nullglob qualifier *(N) so unmatched globs expand to empty:
rm -f *.tmp(N)
vpx oxfmt docs/*.md(N)
```

### 1.3 Zsh Word Splitting Invariant

Unlike Bash, Zsh does NOT split unquoted variables on spaces by default:

```zsh
# BAD (Bash assumption): Loops once over the full string in Zsh!
local files="file1.txt file2.txt"
for f in $files; do ...; done

# GOOD: Use native Zsh arrays or explicit expansion modifier:
local -a files=(file1.txt file2.txt)
for f in "${files[@]}"; do ...; done

# Or explicit space-splitting modifier:
for f in ${(s: :)files}; do ...; done
```

---

## 2. macOS BSD Compatibility Recipes & Workarounds

macOS userland utilities originate from BSD and lack GNU extensions. Follow these verified recipes:

### 2.1 The `readlink -f` Canonical Path Solution

BSD `readlink` does not support the `-f` canonicalization flag:

```zsh
# BAD: Fails with "readlink: illegal option -- f"
readlink -f relative/path/to/file

# GOOD: Use Zsh native path modifier :A (canonical physical path)
local abs_path="${target:A}"

# Or use POSIX realpath:
realpath relative/path/to/file
```

### 2.2 `mktemp` Strict Template Requirement

BSD `mktemp` requires `-t` or an explicit template suffix:

```bash
# BAD: Bare mktemp fails or behaves unexpectedly
mktemp

# GOOD: Provide template with -t
temp_file="$(mktemp -t script.XXXXXX)"
temp_dir="$(mktemp -d -t dir.XXXXXX)"
```

### 2.3 Line Range Extraction & Slicing

GNU flags like `head -v`, `head -q`, `tail -n +1` are not reliably portable across Darwin:

```bash
# GOOD: Use bat or POSIX awk
bat --paging=never --style=plain -r 5:15 file.txt
awk 'NR>=5&&NR<=15' file.txt
```

### 2.4 Date Arithmetic

Darwin `date` does not support GNU `date -d "1 day ago"`:

```bash
# GOOD: Use Node.js or PowerShell 7
node -e "console.log(new Date(Date.now() - 86400000).toISOString())"
pwsh -NoLogo -NoProfile -Command "(Get-Date).AddDays(-1).ToString('yyyy-MM-dd')"
```

### 2.5 File Size and Metadata Inspection

Darwin `stat` does NOT support GNU `stat -c %s`:

```bash
# Byte size
stat -f "%z" <file>

# Modification time (epoch seconds)
stat -f "%m" <file>

# Permissions (octal)
stat -f "%OLp" <file>
```

---

## 3. Darwin System Inspection & Diagnostics (Absence of `/proc`)

Darwin DOES NOT have a `/proc` filesystem. Commands like `cat /proc/cpuinfo` fail immediately. Use canonical Darwin inspection commands:

```bash
# CPU core counts (physical and logical)
sysctl -n hw.ncpu
sysctl -n hw.logicalcpu
sysctl -n hw.physicalcpu

# Physical RAM in bytes
sysctl -n hw.memsize

# Virtual memory statistics (pages free, active, inactive, wired)
vm_stat

# macOS product and build version
sw_vers -productVersion
sw_vers -buildVersion

# Hardware overview (Model, Chip, Memory, Serial)
system_profiler SPHardwareDataType
```

---

## 4. High-Performance Socket & Network Probing

Linux `ss` and `netstat -p` are not available on Darwin. Use `lsof` with `-n` (numeric IP) and `-P` (numeric port) to avoid slow reverse DNS lookups:

```bash
# Check if port 3000 is listening:
lsof -nP -iTCP:3000 -sTCP:LISTEN

# List all open TCP listening ports:
lsof -nP -iTCP -sTCP:LISTEN
```

---

## 5. APFS Copy-on-Write (CoW) Instant Cloning & Snapshots

APFS supports native Copy-on-Write cloning at the block level. Duplicating large directories or files is instantaneous and consumes zero additional disk space until modified:

```bash
# Instant zero-byte file clone
cp -c large-bundle.js large-bundle.bak.js

# Instant zero-byte recursive directory snapshot
cp -R -c build/ build-snapshot/
```

Use this primitive whenever creating pre-refactor backups or snapshotting test environments.

---

## 6. APFS Case-Insensitive Rename Pitfalls & Workarounds

APFS is case-preserving but case-insensitive. Attempting to rename `file.ts` to `File.ts` directly fails:

```bash
# BAD: In Git, fails with "fatal: destination exists"
git mv file.ts File.ts

# GOOD (Git): Use -f flag
git mv -f file.ts File.ts

# GOOD (Filesystem): Perform two-step rename via temporary name
mv file.ts file.ts.tmp && mv file.ts.tmp File.ts
```

---

## 7. Gatekeeper Quarantine & Extended Attributes

Binaries or scripts downloaded via `curl`, `xh`, or `yt-dlp` acquire `com.apple.quarantine`, causing macOS Gatekeeper to kill them (`Killed: 9`):

```bash
# Inspect extended attributes on a file
xattr -l <file>

# Strip quarantine attribute to allow execution
xattr -d com.apple.quarantine <file> 2>/dev/null || true

# Strip all extended attributes
xattr -c <file>
```

---

## 8. AppleDouble (`._*`) Resource Forks & Archive Hygiene

macOS automatically attaches metadata files prefixed with `._` when packaging archives:

```bash
# BAD: Creates archives polluted with ._* hidden files
tar -czf release.tar.gz src/

# GOOD: Disable AppleDouble metadata embedding
COPYFILE_DISABLE=1 tar -czf release.tar.gz src/

# Purge stray .DS_Store files across workspace
fd -H "^\.DS_Store$" -X rm
```

---

## 9. Destructive File Operation Guardrails & Defensive Assertions

Always assert that target paths are non-null and valid before executing recursive deletions:

```zsh
# REQUIRED: Defensive path assertion pattern in Zsh
local target_dir="build"

if [[ -z "${target_dir:-}" || ! -d "$target_dir" ]]; then
  echo "Error: Target directory is empty or does not exist: '$target_dir'" >&2
  exit 1
fi

rm -rf "${target_dir:?}"/*
```

---

## 10. Streaming Inspection Protocol for Large Files & Binaries

Strictly avoid loading files >1MB into memory or reading them via `cat` / Node.js `fs.readFileSync`:

```bash
# REQUIRED: Streaming string search in binaries without memory exhaustion
rg -a -M 200 "pattern" path/to/large.bin

# Targeted line window preview
bat --paging=never --style=plain -r 1:100 large-log.log
```

---

## 11. Git-First Incident Recovery Protocol

When an accidental directory sprawl, untracked build explosion, or nested submodule issue occurs:

```bash
# 1. Immediately halt all filesystem mutations
# 2. Clean all untracked files and directories cleanly
git clean -ffdx

# 3. Discard all unstaged tracked file modifications
git checkout -- .

# 4. Verify clean working tree
git status
```

---

## 12. macOS System Configuration & Automation (`defaults`, `PlistBuddy`)

### 12.1 Apple System Defaults (`defaults`)

Fast, non-interactive configuration of macOS domain preferences:

```bash
# Check value
defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || true

# Write boolean
defaults write com.apple.finder AppleShowAllFiles -bool true

# Write floating point
defaults write -g NSWindowResizeTime -float 0.001
```

### 12.2 Deep Plist Manipulation (`/usr/libexec/PlistBuddy`)

Modify nested arrays or dictionaries in property lists (`.plist`):

```bash
# Print nested value
/usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:64:enabled" ~/Library/Preferences/com.apple.symbolichotkeys.plist

# Add array entry
/usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons: integer 2" ~/Library/Preferences/com.colliderli.iina.plist
```

### 12.3 LaunchServices File Associations

Default handler registration without GUI confirmation dialogs:

- Configuration file: `~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist`
- Rebuild LaunchServices database after batch modifications:
  ```bash
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
  ```

---

## 13. Cross-Platform PowerShell 7 CLI Scripts on Darwin

- Cross-platform CLI tools in `cli/*.ps1` use `#!/usr/bin/env -S pwsh -NoLogo -NoProfile` and are symlinked without extension into `~/.local/bin`.
- Ensure physical script paths are resolved via `ResolveLinkTarget($true)`:
  ```powershell
  $fileInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $scriptPath).Path)
  $targetInfo = $fileInfo.ResolveLinkTarget($true)
  $realPath = $targetInfo ? $targetInfo.FullName : $fileInfo.FullName
  ```
