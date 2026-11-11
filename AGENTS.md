# Agent Guidelines & Repository Workflow Rules

This document outlines the core architecture map, git delivery invariants, and modular domain rules for AI agents operating in this unified cross-platform (macOS + Windows 11) repository. Universal CLI toolchains, cross-platform safety, language, and formatting standards are inherited globally from the `common-modern-tools` plugin.

## 1. Quick Architecture Map

| Layer                   | Path                                            | Responsibility                                                                                                                                   |
| :---------------------- | :---------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| **CLI Tools**           | `cli/*.ps1`                                     | Cross-platform PowerShell 7 (`pwsh`) CLI commands (symlinked to `~/.local/bin` on macOS; User `PATH` on Win11)                                   |
| **Dotfiles & Configs**  | `configs/bash/`, `configs/zsh/`, `configs/git/` | Shell configuration parity, completions, global Git hooks, and browser extension backups                                                         |
| **Antigravity Plugins** | `plugins/`                                      | Cross-platform toolchain, platform & web stack bundles (`common-modern-tools`, `macos-modern-tools`, `windows-modern-tools`, `modern-web-stack`) |
| **Installers**          | `scripts/install.sh`, `scripts/install.ps1`     | Idempotent OS environment setup (Zsh for macOS; PowerShell 5.1 & 7+ compatible for Windows 11)                                                   |
| **Workspace Rules**     | `.agents/rules/`                                | Modular project rules triggered via file globbing                                                                                                |

---

## 2. Git Delivery Protocol & AI Rejection Invariant

- **AI Direct Commits Globally Prohibited**:
  - The repository enforces a global Git hook (`~/.config/git/hooks/pre-commit`) that rejects direct commits by AI agents (`ANTIGRAVITY_AGENT=1`).
  - Agents must NEVER execute `git commit` or `git push`.
  - Mandatory workflow:
    1. Apply code changes and verify syntax/AST.
    2. Format modified files (`shfmt` for shell, `vpx oxfmt` for markdown/JSON/code).
    3. Stage changes using defensive explicit paths: `git add <files>`.
    4. Output the exact `git commit -m "type(scope): concise imperative description"` command for manual execution by the user.
- **Agent-Friendly Execution Formats**:
  - Prefer token-efficient structured flags during verification:
    - Linting: `vp lint -f agent` (or `vpx oxlint -f agent`)
    - Type check: `tsc -b --pretty false`
    - Combined check: `vp check --quiet`
    - Dependencies: `vp list --json`, `vp outdated --format json`
- **Project Root Settings SSOT**:
  - Maintain `PSScriptAnalyzerSettings.psd1` directly in the project root (synchronized with `plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1`) for zero-configuration VS Code discovery.

---

## 3. Modular Domain Rules (`.agents/rules/`)

Domain-specific rules are modularized and automatically injected via file globbing:

- **CLI Scripts**: [`.agents/rules/cli-scripts.md`](./.agents/rules/cli-scripts.md) (triggers on `cli/*.ps1`)
- **Shell & Installers**: [`.agents/rules/shell-configs.md`](./.agents/rules/shell-configs.md) (triggers on `configs/bash/*`, `configs/zsh/*`, `scripts/*`)
- **Plugins, Skills & Rules**: [`.agents/rules/skills-authoring.md`](./.agents/rules/skills-authoring.md) (triggers on `plugins/**`)
