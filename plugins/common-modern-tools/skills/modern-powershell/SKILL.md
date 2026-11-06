---
name: modern-powershell
description: Strict cross-platform (macOS, Windows 11, Linux) and cross-version (PowerShell 7+ pwsh vs Windows PowerShell 5.1) authoring standards, pre-execution live documentation and runtime introspection gate, AST and PSUseCompatibleSyntax grammar verification, VS Code Stroustrup formatting (LF, UTF-8 without BOM), and non-bypassable PSScriptAnalyzer static analysis. Use when writing, refactoring, formatting, or debugging PowerShell scripts (.ps1, .psm1, .psd1) or in-memory pwsh automation.
compatibility: PowerShell 7+ (pwsh), Windows PowerShell 5.1 (powershell.exe), PSScriptAnalyzer, macOS Darwin, Windows 11, Linux
---

# Modern PowerShell Authoring & Verification Guidelines

**CRITICAL:** Every PowerShell script (`.ps1`, `.psm1`, `.psd1`) and multi-line automation block must pass three mandatory gates on the first attempt: (1) `Invoke-Formatter` with LF (`\n`) and UTF-8 without BOM normalization, (2) AST parser grammar check (`[System.Management.Automation.Language.Parser]::ParseFile`) plus `PSUseCompatibleSyntax` for dual-version scripts, and (3) `Invoke-ScriptAnalyzer -IncludeSuppressed -EnableExit` with **0 ParseErrors, 0 Errors, 0 Warnings, and 0 Information violations**.

---

## 1. Pre-Execution Live Query & Runtime Introspection Gate

Never guess cmdlet parameter names, parameter sets, `.NET` method overloads, or `PSScriptAnalyzer` rule identifiers from pre-training memory. Before writing or modifying PowerShell code that invokes unfamiliar cmdlets, `.NET` APIs, or analyzer configurations, execute at least one verification query:

### 1.1 Local Runtime Introspection (Zero-Latency Primary Source)

- **Cmdlet Parameter Sets & Syntax**:
  ```powershell
  pwsh -NoLogo -NoProfile -Command "Get-Command <CmdletName> -Syntax"
  ```
- **.NET Type Constructors & Method Overloads**:
  ```powershell
  pwsh -NoLogo -NoProfile -Command "[System.IO.File].GetMethods() | Where-Object Name -eq 'WriteAllText' | ForEach-Object { `$_.ToString() }"
  ```
- **PSScriptAnalyzer Rule Definitions & Severities**:
  ```powershell
  pwsh -NoLogo -NoProfile -Command "Get-ScriptAnalyzerRule -Name <RuleName> | Select-Object RuleName, Severity, CommonName, Description | Format-List"
  ```

### 1.2 Authoritative Official Documentation Matrix (`webread`)

When designing cross-platform or cross-version logic, query Microsoft Learn official documentation via `webread`:

- **Windows PowerShell 5.1 vs PowerShell 7+ Breaking Changes & Differences**:
  - `webread https://learn.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell`
- **Cross-Platform Portable Module & Script Authoring**:
  - `webread https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules`
- **Core Language & Conceptual Topics (`about_*`)**:
  - Operators: `webread https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators`
  - Strict Mode: `webread https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_strict_mode`
  - Automatic Variables: `webread https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables`
  - Functions & Parameters: `webread https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters`
- **PSScriptAnalyzer Usage & Compatibility Rules**:
  - Overview & Settings: `webread https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer`
  - Syntax Compatibility (`PSUseCompatibleSyntax`): `webread https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatiblesyntax`
  - Cmdlet Compatibility (`PSUseCompatibleCmdlets`): `webread https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatiblecmdlets`
  - Command Compatibility (`PSUseCompatibleCommands`): `webread https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatiblecommands`
  - Type Compatibility (`PSUseCompatibleTypes`): `webread https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatibletypes`

---

## 2. Zero-Suppression & Non-Bypassable Linting Gate

Agents are strictly prohibited from skipping, muting, or weakening `PSScriptAnalyzer` checks:

1. **Absolute Ban on `SuppressMessageAttribute`**:
   - NEVER add `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` or `[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` to any script, function, or parameter block.
2. **Mandatory `-IncludeSuppressed -EnableExit` Invocation**:
   - All `Invoke-ScriptAnalyzer` verification runs MUST include `-IncludeSuppressed` so that any suppression attribute in the source file is surfaced as an active violation.
3. **Strict Ban on Configuration or CLI Downgrades**:
   - NEVER pass `-ExcludeRule` or narrow `-Severity` on the command line when verifying scripts.
   - NEVER modify `PSScriptAnalyzerSettings.psd1` to disable rules, add exclusions to `ExcludeRules`, or remove `'ParseError'` / `'Information'` from `Severity`.
4. **Structural Resolution of Common Violations**:
   - **`PSAvoidUsingWriteHost`**: Never use `Write-Host` (note: PSScriptAnalyzer's `PSAvoidUsingWriteHost` rule also strictly forbids `[System.Console]::Write` and `[System.Console]::WriteLine`).
     - Standard output stream: `Write-Output 'message'`
     - Error stream: `[Console]::Error.WriteLine('error message')`
     - In-place terminal spinners or ANSI progress without newline: `$Host.UI.Write("`r $frame $Message...")`
   - **`PSAvoidUsingEmptyCatchBlock`**: Never leave a `catch {}` block empty. Always log via `Write-Verbose`, `Write-Warning`, `[Console]::Error.WriteLine`, or rethrow (`throw`).
   - **`PSPlaceOpenBrace` / `PSPlaceCloseBrace` (`IgnoreOneLineBlock = $false`)**: Never write single-line control blocks (`if ($x) { return }` or `catch {}`). Always expand blocks across multiple lines using Stroustrup brace placement (`{` on the same line, body indented on a new line, `}` on its own line).
   - **`PSUseSingularNouns` & `PSUseApprovedVerbs`**: Name all functions with an approved PowerShell verb (`Get-Verb`) and a singular noun (e.g., `Convert-TimeToSecond` instead of `Convert-TimeToSeconds`).
   - **`PSUseUsingScopeModifierInNewRunspaces`**: Inside `ForEach-Object -Parallel` or `Start-ThreadJob -ScriptBlock`, reference caller-scoped variables directly with `$using:varName` rather than undeclared variables or `param(...)` blocks that trigger scope warnings.
5. **Project-Level Configuration Inheritance**:
   - Whenever a repository or workspace contains PowerShell scripts (`*.ps1`, `*.psm1`, `*.psd1`), `PSScriptAnalyzerSettings.psd1` must reside directly in the workspace root.
   - If missing, copy it from the canonical plugin directory (`$HOME/.gemini/config/plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1` or local repo `plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1`).
   - This ensures VS Code's default `powershell.scriptAnalysis.settingsPath` (`"PSScriptAnalyzerSettings.psd1"`) resolves automatically across macOS, Windows 11, and CI runners without OS-specific absolute path conflicts in VS Code Settings Sync.

---

## 3. Cross-Version Compatibility Matrix (`pwsh 7+` vs `powershell.exe 5.1`)

Always classify the target runtime tier before writing a script:

- **Tier A — Modern Cross-Platform Scripts (`cli/*.ps1`, general `pwsh` automation)**:
  - Header: `#!/usr/bin/env -S pwsh -NoLogo -NoProfile`
  - Target Runtime: PowerShell 7.4+ (`.NET 8+`) across macOS, Windows 11, and Linux.
  - Permitted Syntax: Ternary (`$cond ? $a : $b`), null-coalescing (`$a ?? $b`, `$a ??= $b`), null-conditional (`$a?.Prop`), pipeline chains (`&&`, `||`), `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`, and native byte-stream piping (`PSNativeCommandPreserveBytePipe`).
- **Tier B — Dual-Version Bootstrap Scripts (`scripts/install.ps1`, fresh Windows 10/11 provisioning)**:
  - Header: `#Requires -Version 5.1`
  - Target Runtime: Must execute identically on out-of-the-box Windows PowerShell 5.1 (`.NET Framework 4.x`, `PSEdition -eq 'Desktop'`) and PowerShell 7+ (`PSEdition -eq 'Core'`).

### 3.1 Breaking Differences & Safe Cross-Version Patterns

| Feature / Boundary                       | PowerShell 7+ Only (Tier A)                                                                | Dual-Compatible Pattern (Tier B: PS 5.1 + PS 7+)                                                                                                                                                                                                                                 |
| :--------------------------------------- | :----------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Conditional / Null Operators**         | `$x = $cond ? $a : ($b ?? 'default')`                                                      | `if ($cond) { $x = $a } elseif ($null -ne $b) { $x = $b } else { $x = 'default' }`                                                                                                                                                                                               |
| **OS Detection Variables**               | `if ($IsWindows) { ... }`                                                                  | `$isWin = ($PSVersionTable.PSEdition -ne 'Core') -or $IsWindows` (In PS 5.1, `$IsWindows` does not exist and throws `VariableIsUndefined` under `Set-StrictMode -Version Latest`)                                                                                                |
| **String Splitting (`Split`)**           | `$str -split '[;:]'`                                                                       | Always use `-split` regex operator or explicit `[char[]]` cast: `$str.Split([char[]]';:')`. Never call `$str.Split('ab')` with a string argument (`.NET Framework 4.x` splits by `char[]`, whereas `.NET 8+` splits by the substring `'ab'`).                                    |
| **UTF-8 File Writing (No BOM)**          | `[System.IO.File]::WriteAllText($absPath, $text, [System.Text.UTF8Encoding]::new($false))` | `$utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($absPath, $text, $utf8NoBom)` (In PS 5.1, `Set-Content -Encoding UTF8` writes a 3-byte BOM and `utf8NoBOM` does not exist).                                                            |
| **JSON Parsing**                         | `ConvertFrom-Json -AsHashtable`                                                            | `ConvertFrom-Json` (returns `PSCustomObject`; `-AsHashtable` is absent in PS 5.1).                                                                                                                                                                                               |
| **HTTP Downloads (`Invoke-WebRequest`)** | `Invoke-RestMethod` or native `curl`                                                       | Must enable TLS 1.2 (`[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12`) and pass `-UseBasicParsing` to `Invoke-WebRequest` so Server Core / LTSC does not fail due to missing IE DOM libraries. |
| **Parallel Execution**                   | `$items \| ForEach-Object -Parallel { ... } -ThrottleLimit 6`                              | Sequential `foreach ($item in $items)` or runspace pools (`-Parallel` on `ForEach-Object` was introduced in PS 7.0).                                                                                                                                                             |

---

## 4. Cross-Platform Portability Invariants (macOS, Windows 11, Linux)

### 4.1 The `.NET` Working Directory Desync Defense (`[System.IO.File]` vs `$PWD`)

`.NET` static methods (`[System.IO.File]::ReadAllText`, `[System.IO.File]::WriteAllText`, `[System.IO.FileInfo]::new`) resolve relative paths against `[System.Environment]::CurrentDirectory`, which **does not** update when PowerShell changes location via `Set-Location` or `Push-Location`:

```powershell
# BAD: Writes to the wrong directory if Set-Location / Push-Location was called
[System.IO.File]::WriteAllText('output.json', $json, [System.Text.UTF8Encoding]::new($false))

# GOOD: Resolve full provider path via Join-Path $PWD.ProviderPath or Resolve-Path
$outPath = Join-Path $PWD.ProviderPath 'output.json'
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.UTF8Encoding]::new($false))
```

### 4.2 Mandatory `-LiteralPath` Over `-Path`

In PowerShell, `-Path` interprets `[` and `]` as wildcard character range patterns. Paths containing brackets (such as media files `[1080p].mkv` or framework dynamic route files `src/routes/posts/[id].tsx`) fail silently or throw errors when passed to `-Path`:

```powershell
# BAD: Fails when $targetFile contains '[' or ']'
if (Test-Path -Path $targetFile) {
    $raw = Get-Content -Path $targetFile -Raw
}

# GOOD: Always use -LiteralPath unless wildcard globbing is explicitly required
if (Test-Path -LiteralPath $targetFile) {
    $raw = Get-Content -LiteralPath $targetFile -Raw
}
```

### 4.3 Path & Environment Variable Portability

- **Path Composition**: Never concatenate paths with hardcoded `\` or `/`. Always use `Join-Path`, `Split-Path`, or `[System.IO.Path]::Combine()`.
- **`PATH` Delimiter**: When splitting the `PATH` environment variable in cross-platform scripts, use `[System.IO.Path]::PathSeparator` (`;` on Windows, `:` on macOS/Linux).
- **Case-Sensitive Environment Variables on Unix**: On Windows, `$env:Path` and `$env:PATH` are case-insensitive aliases; on macOS and Linux, environment variables are strictly case-sensitive (`$env:PATH` is populated while `$env:Path` is `$null`). Always use `$env:PATH` in cross-platform scripts, and guard Windows registry environment APIs (`[Environment]::GetEnvironmentVariable('Path', 'User')`) behind `if ($IsWindows)`.
- **Native Binary Invocation & Alias Collision Defense**:
  - Resolve OS-specific binary names cleanly:
    ```powershell
    $curlBin = $IsWindows ? 'curl.exe' : 'curl'
    $nullDevice = $IsWindows ? 'NUL' : '/dev/null'
    ```
  - Always invoke external binaries with the call operator `&` and an argument array `@argsList`, followed by an explicit `$LASTEXITCODE` check.

### 4.4 Extensionless Shebang & Symlink Target Resolution (`cli/*.ps1`)

On macOS and Linux, `cli/<cmd>.ps1` scripts are symlinked to `~/.local/bin/<cmd>` without the `.ps1` extension. When executed via `#!/usr/bin/env -S pwsh -NoLogo -NoProfile`:

1. The file **must** be saved with LF (`\n`) line endings and UTF-8 without BOM (CRLF or BOM causes kernel `exec` failure).
2. `$PSScriptRoot` and `$PSCommandPath` are empty (`""`) when `pwsh` runs an extensionless symlink. Always resolve the physical script directory via `[Environment]::GetCommandLineArgs()` and `ResolveLinkTarget($true)`:

```powershell
function Get-ScriptDirectory {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $cmdArgs = [Environment]::GetCommandLineArgs()
        for ($i = 1; $i -lt $cmdArgs.Count; $i++) {
            $candidate = $cmdArgs[$i]
            if ($candidate -and (-not $candidate.StartsWith('-')) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $scriptPath = $candidate
                break
            }
        }
    }
    if (-not $scriptPath) {
        throw 'Unable to determine script path.'
    }
    $fileInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $scriptPath).Path)
    $targetInfo = $fileInfo.ResolveLinkTarget($true)
    $realPath = $targetInfo ? $targetInfo.FullName : $fileInfo.FullName
    return (Split-Path -Parent $realPath)
}
```

### 4.5 Pipeline Scalar Unrolling Defense (`@(...)`)

PowerShell pipelines unroll single-item outputs into a scalar object. Under `Set-StrictMode -Version Latest`, indexing `[0]` on a scalar `System.String` extracts the first character `[char]`, and accessing `.Count` on `$null` can fail:

```powershell
# Always wrap pipeline or filter results in @(...)
$matchedItems = @($items | Where-Object { $_.IsEnabled })
if ($matchedItems.Count -gt 0) {
    $first = $matchedItems[0]
}
```

---

## 5. Three-Stage Mandatory Verification Pipeline

Whenever any `.ps1`, `.psm1`, or `.psd1` file is created or modified, run all three stages before staging (`git add`) or concluding the task.

### Stage 1: VS Code Stroustrup Formatting with LF & UTF-8 No-BOM Normalization

`Invoke-Formatter` preserves CRLF (`\r\n`) if the input string contains CRLF. Always normalize `\r\n` to `\n` before saving as UTF-8 without BOM:

```powershell
$cmd = @'
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$targetFile = 'cli/command.ps1'
$settingsPath = (Test-Path -LiteralPath './PSScriptAnalyzerSettings.psd1') ? './PSScriptAnalyzerSettings.psd1' : (Join-Path $HOME '.gemini/config/plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1')
$absPath = (Resolve-Path -LiteralPath $targetFile).Path
$raw = [System.IO.File]::ReadAllText($absPath)
$formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $settingsPath
$normalized = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"
[System.IO.File]::WriteAllText($absPath, $normalized, [System.Text.UTF8Encoding]::new($false))
'@
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
pwsh -NoLogo -NoProfile -EncodedCommand $b64
```

### Stage 2: AST Grammar & Cross-Version Syntax Verification

Verify zero parser errors via `Parser::ParseFile`, and for Tier B dual-version scripts (`#Requires -Version 5.1`), enforce `PSUseCompatibleSyntax` against PowerShell `5.1` and `7.4`:

```powershell
$cmd = @'
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$targetFile = 'scripts/install.ps1'
$absPath = (Resolve-Path -LiteralPath $targetFile).Path
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($absPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors) {
    $parseErrors | Format-List
    throw "AST syntax check failed on $targetFile"
}
# For Tier B (PS 5.1 + 7+ compatible) scripts:
$compatSettings = @{
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
    }
}
$compatViolations = @(Invoke-ScriptAnalyzer -Path $absPath -Settings $compatSettings -IncludeSuppressed)
if ($compatViolations.Count -gt 0) {
    $compatViolations | Format-Table -AutoSize
    throw "Cross-version syntax check (5.1 & 7.4) failed on $targetFile"
}
'@
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
pwsh -NoLogo -NoProfile -EncodedCommand $b64
```

### Stage 3: Non-Bypassable `PSScriptAnalyzer` Gate (`-IncludeSuppressed`)

Run `Invoke-ScriptAnalyzer` with `-IncludeSuppressed` against `PSScriptAnalyzerSettings.psd1` (`Severity = @('ParseError', 'Error', 'Warning', 'Information')`):

```powershell
$cmd = @'
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$targetFile = 'cli/command.ps1'
$settingsPath = (Test-Path -LiteralPath './PSScriptAnalyzerSettings.psd1') ? './PSScriptAnalyzerSettings.psd1' : (Join-Path $HOME '.gemini/config/plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1')
$absPath = (Resolve-Path -LiteralPath $targetFile).Path
$violations = @(Invoke-ScriptAnalyzer -Path $absPath -Settings $settingsPath -IncludeSuppressed)
if ($violations.Count -gt 0) {
    $violations | Format-Table -AutoSize
    throw "PSScriptAnalyzer failed with $($violations.Count) violation(s) on $targetFile"
}
'@
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
pwsh -NoLogo -NoProfile -EncodedCommand $b64
```

---

## 6. Architecture & Design Trade-off Matrix

| Technical Choice                                                                                 | Hard Constraints Satisfied                                                                                                                                                                                | Incurred Trade-offs & Costs                                                                                                                                                                   | Anti-Use Cases (When NOT to Use)                                                                                                             |
| :----------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| **`Severity = @('ParseError', 'Error', 'Warning', 'Information')` with `-IncludeSuppressed`**    | Enforces AST parse errors, security errors, code quality warnings, and formatting/casing `Information` rules in a single pass while blocking `SuppressMessageAttribute` bypasses.                         | Requires explicit exclusion of `PSAvoidUsingPositionalParameters` and `PSProvideCommentHelp` in `PSScriptAnalyzerSettings.psd1` to prevent noise on internal functions and `Join-Path $a $b`. | Public PowerShell Gallery modules that require mandatory comment-based help (`PSProvideCommentHelp`) on all exported cmdlets.                |
| **Replacing `Write-Host` with `Write-Output` / `[Console]::Error.WriteLine` / `$Host.UI.Write`** | Eliminates `PSAvoidUsingWriteHost` warnings (which also flag `[Console]::Write`) without suppression attributes, keeping stdout pipeline objects clean while supporting ANSI terminal spinners.           | `$Host.UI.Write` writes to the host UI and cannot be captured via PowerShell stream `6>&1` redirection.                                                                                       | Scripts designed specifically for PowerShell Information Stream (`6>`) transcript capture, which should use `Write-Information`.             |
| **Dual-Tier Version Classification (`pwsh 7.4+` vs `#Requires -Version 5.1`)**                   | Allows daily CLI scripts (`cli/*.ps1`) to use concise PS 7+ syntax and `-Parallel` loops while guaranteeing fresh Windows 10/11 machines can run `scripts/install.ps1` using in-box `powershell.exe 5.1`. | Tier B scripts require more verbose `if/else` control flow and explicit `.NET` constructors (`New-Object`) instead of PS 7+ operators (`? :`, `??`).                                          | Do not apply Tier B (`TargetVersions = @('5.1')`) restrictions to cross-platform `cli/*.ps1` utilities that run exclusively under `pwsh 7+`. |
