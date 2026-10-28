---
name: macos-toolchain
description: macOS Darwin platform execution rules, BSD compatibility constraints, Apple system administration (defaults, scutil, PlistBuddy, launchservices), Zsh scripting standards, and PowerShell 7 symlink resolution. Use when running Darwin-specific workflows or configuring macOS system settings.
compatibility: macOS Darwin, Zsh 5+, PowerShell 7+
---

# macOS Darwin Toolchain & System Administration Guidelines

> [!NOTE]
> For universal high-performance CLI tools (`rg`, `fd`, `bat`, `sd`, `jq`, `yq`, `duckdb`, `sqlite3`, `xsv`, `xh`, `dust`, `pdftotext`, `shfmt`, `actionlint`, `hyperfine`, Vite+), refer to the **`common-toolchain`** skill.

## 1. macOS BSD Compatibility Recipes & Workarounds

macOS userland utilities originate from BSD and lack GNU extensions. When interacting with Darwin system utilities, follow these verified recipes:

### 1.1 Line Range Extraction & Slicing

- **POSIX `head` / `tail`**:
  - GNU flags like `head -v`, `head -q`, `tail -n +1` are not reliably portable across Darwin.
  - _Standard Approach_: Use `bat --paging=never --style=plain -r <start>:<end> <file>` or POSIX awk:
    ```bash
    awk 'NR>=5&&NR<=15' file.txt
    ```

### 1.2 Date Arithmetic

- **BSD `date`**:
  - Darwin `date` does not support GNU `date -d "1 day ago"`.
  - _Standard Approach_: Use Node.js one-liners or PowerShell 7:
    ```bash
    node -e "console.log(new Date(Date.now() - 86400000).toISOString())"
    pwsh -NoLogo -NoProfile -Command "(Get-Date).AddDays(-1).ToString('yyyy-MM-dd')"
    ```

### 1.3 File Size and Metadata Inspection

- **BSD `stat`**:
  - Darwin `stat` does NOT support GNU `stat -c %s`.
  - _Byte size_: `stat -f "%z" <file>`
  - _Modification time_: `stat -f "%m" <file>`
  - _Permissions (octal)_: `stat -f "%OLp" <file>`

### 1.4 Process & Network Probing

- **Port Checking**:
  - Linux `ss` or `netstat -p` is not available on Darwin.
  - _Standard Approach_:
    ```bash
    lsof -i :<PORT>
    lsof -iTCP:<PORT> -sTCP:LISTEN
    ```

---

## 2. macOS System Configuration & Automation (`defaults`, `PlistBuddy`)

### 2.1 Apple System Defaults (`defaults`)

- Fast, non-interactive configuration of macOS domain preferences:
  ```bash
  # Check value
  defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || true
  # Write boolean
  defaults write com.apple.finder AppleShowAllFiles -bool true
  # Write integer
  defaults write -g NSWindowResizeTime -float 0.001
  ```

### 2.2 Deep Plist Manipulation (`/usr/libexec/PlistBuddy`)

- When modifying nested arrays or dictionaries in property lists (`.plist`):
  ```bash
  # Print nested value
  /usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:64:enabled" ~/Library/Preferences/com.apple.symbolichotkeys.plist
  # Add array entry
  /usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons: integer 2" ~/Library/Preferences/com.colliderli.iina.plist
  ```

### 2.3 LaunchServices File Associations

- Default handler registration without GUI confirmation dialogs:
  - Configuration file: `~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist`
  - Rebuilding LaunchServices database after batch modifications:
    ```bash
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
    ```

---

## 3. Idiomatic Zsh Automation Standards

```zsh
#!/bin/zsh
emulate -L zsh
set -euo pipefail

# 1-based array indexing
local -a items=(alpha beta gamma)
echo "First item: $items[1]"

# Path modifiers
local target="/opt/homebrew/bin/pwsh"
echo "Dir: ${target:h}"       # /opt/homebrew/bin
echo "Name: ${target:t}"      # pwsh
echo "Canonical: ${target:A}" # Physical resolved path
```

---

## 4. Cross-Platform PowerShell 7 CLI Scripts on Darwin

- Cross-platform CLI tools in `cli/*.ps1` use `#!/usr/bin/env -S pwsh -NoLogo -NoProfile` and are symlinked without extension into `~/.local/bin`.
- Ensure physical script paths are resolved via:
  ```powershell
  $fileInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $scriptPath).Path)
  $targetInfo = $fileInfo.ResolveLinkTarget($true)
  $realPath = $targetInfo ? $targetInfo.FullName : $fileInfo.FullName
  ```
