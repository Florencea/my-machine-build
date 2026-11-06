# Agent Guidelines & Workflow Rules

This document outlines the core architecture, verification standards, and commit rules for AI agents operating in this unified cross-platform (macOS + Windows 11) repository.

## 1. Quick Architecture Map

| Layer                   | Path                                            | Responsibility                                                                                                                                 |
| :---------------------- | :---------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| **CLI Tools**           | `cli/*.ps1`                                     | Cross-platform PowerShell 7 (`pwsh`) CLI commands (symlinked to `~/.local/bin` on macOS; User `PATH` on Win11)                                 |
| **Dotfiles & Configs**  | `configs/bash/`, `configs/zsh/`, `configs/git/` | Shell configuration parity, completions, global Git hooks, and browser extension backups                                                       |
| **Antigravity Plugins** | `plugins/`                                      | Cross-platform toolchain, platform & web stack bundles (`common-modern-tools`, `macos-modern-tools`, `win11-modern-tools`, `modern-web-stack`) |
| **Installers**          | `scripts/install.sh`, `scripts/install.ps1`     | Idempotent OS environment setup (Zsh for macOS; PowerShell 5.1 & 7+ compatible for Windows 11)                                                 |
| **Workspace Rules**     | `.agents/rules/`                                | Modular project rules triggered via file globbing                                                                                              |

---

## 2. Git Commit & Command Execution Rules

- **AI Direct Commits Globally Prohibited**:
  - The system enforces a global Git hook (`~/.config/git/hooks/pre-commit`) that rejects direct commits by AI agents (`ANTIGRAVITY_AGENT=1`).
  - Agents must **never** execute `git commit` or `git push`.
  - Mandatory workflow for agents:
    1. Apply code changes and verify syntax/AST.
    2. Format modified files (`shfmt` for shell, `vpx oxfmt` for markdown/JSON/code).
    3. Stage changes using `git add <files>`.
    4. Provide the exact `git commit -m "..."` command for manual execution by the user.
- **Unified Vite+ Toolchain Mandate (`vp`, `vpx`, `vpr`)**:
  - Across all Node.js projects, always use native Vite+ commands: `vp` for package management, `vpx <tool>` for one-off tool execution, and `vpr <script>` for package scripts.
  - STRICTLY PROHIBITED to invoke package-manager specific runners (`npx`, `pnpm dlx`, `bunx`, `npm run`).
- **Bare Command Invocation (No Path Prefixes)**:
  - All terminal commands executed by agents must strictly use bare command names (e.g. `git`, `vp`, `pwsh`, `node`, `shfmt`, `sd`) relying on `$PATH`.
- **Agent-Friendly Execution Formats**:
  - When running verification or inspection commands, prefer token-efficient structured flags:
    - Linting: `vp lint -f agent` (or `vpx oxlint -f agent`)
    - Type check: `tsc -b --pretty false`
    - Combined check: `vp check --quiet`
    - Dependencies: `vp list --json`, `vp outdated --format json`
- **Commit Message Convention**:
  - Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification (`feat`, `fix`, `refactor`, `style`, `docs`, `chore`).

---

## 3. Code Formatting & Verification Standards

Before staging any files, all modified files must be formatted and verified:

- **Shell Scripts** (`scripts/*.sh`, `configs/bash/*`, `configs/zsh/*`):
  - Formatter: `shfmt -i 2 -ci -w <files>`
- **PowerShell Scripts** (`cli/*.ps1`, `scripts/install.ps1`, `*.psm1`, `*.psd1`):
  - Formatter: `Invoke-Formatter` via `PSScriptAnalyzerSettings.psd1` (Stroustrup style, 4-space indent, normalize CRLF to LF `\n`, UTF-8 without BOM).
  - AST Verification: Verify zero parse errors via `[System.Management.Automation.Language.Parser]::ParseFile(...)`. For dual-version bootstrap scripts (`scripts/install.ps1` with `#Requires -Version 5.1`), enforce `PSUseCompatibleSyntax` (`TargetVersions = @('5.1', '7.4')`).
  - Static Analysis Gate: Run `Invoke-ScriptAnalyzer -Path <file> -Settings ./PSScriptAnalyzerSettings.psd1 -IncludeSuppressed` achieving **0 ParseErrors, 0 Errors, 0 Warnings, and 0 Information violations**.
  - Zero Lint Suppression: Strictly prohibited to add `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]`, pass `-ExcludeRule`, or weaken `PSScriptAnalyzerSettings.psd1`.
- **Markdown & Code Files** (`*.md`, `*.json`, `*.ts`):
  - Formatter: `vpx oxfmt <files>`

---

## 4. Documentation, Language & Communication Standards

- **Dual-Mode Language Separation**:
  - **Dialogue & Review Artifacts (Traditional Chinese)**: Conversational chat responses, implementation plans (`<plan_name>.md`), walkthrough artifacts (`walkthrough.md`), and commit explanations are written in strict Traditional Chinese (臺灣習慣用語，例如：預設、專案、模組、支援、介面、記憶體、相容性、最佳化; 嚴禁簡體用語). Standard technical identifiers, flags, and symbols retain their English casing (`pnpm`, `Vite+`, `tsconfig.json`).
  - **Code, Comments & Commits (Concise English)**: Source code, identifiers, inline comments, docstrings, and Git commit messages must be written in concise, grammatical English. Never include Chinese or non-English characters in code comments or commits.
- **Objective Fact-First Syntax & Strict Ban on Emojis**:
  - Prohibit marketing superlatives ("best", "optimal", "flawless", "revolutionary", "blazingly fast", "最佳", "首選", "卓越", "強大") and self-congratulatory praise ("elegant", "robust", "perfect", "優雅", "健全").
  - Express facts through verbs, physical conditions, and measurable metrics.
  - Strictly prohibit emojis (🚀, 💡, ✨, 👉, ❌, ✅, 🎉, etc.) and informal emoticons across all outputs.
- **Document Language Preservation & Offline Reader Test**:
  - Preserve the primary language of existing files. Write documentation under the invariant that the reader is an offline engineer with zero chat history context. Explicitly state technical context and problem definitions; avoid dangling references ("as discussed earlier").

---

## 5. Modular Domain Rules (`.agents/rules/`)

To keep this document lean, domain-specific rules are modularized and automatically injected via file globbing:

- **CLI Scripts**: [`.agents/rules/cli-scripts.md`](./.agents/rules/cli-scripts.md) (triggers on `cli/*.ps1`)
- **Shell & Installers**: [`.agents/rules/shell-configs.md`](./.agents/rules/shell-configs.md) (triggers on `configs/bash/*`, `configs/zsh/*`, `scripts/*`)
- **Plugins, Skills & Rules**: [`.agents/rules/skills-authoring.md`](./.agents/rules/skills-authoring.md) (triggers on `plugins/**`)
