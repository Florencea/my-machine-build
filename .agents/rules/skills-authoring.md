---
trigger: glob
globs: "plugins/**"
description: Rules for creating, structuring, and maintaining Antigravity Plugins, Skills, and Rules in this repository.
---

# Antigravity Plugins, Skills & Rules Authoring Rules

## 1. Plugin Directory Structure & Split Architecture

All Antigravity customizations are packaged as **Plugins** under `plugins/<plugin-name>/` and deployed to `~/.gemini/config/plugins/<plugin-name>/`:

- **`plugins/macos-modern-tools/`** (macOS only):
  - `plugin.json`: Manifest for macOS toolchain bundle.
  - `rules/AGENTS.md`: macOS Darwin execution rules, BSD compatibility traps, and git commit guard.
  - `skills/macos-toolchain/SKILL.md`: macOS CLI decision tree and live query endpoints.
- **`plugins/win11-modern-tools/`** (Windows 11 only):
  - `plugin.json`: Manifest for Windows 11 toolchain bundle.
  - `rules/AGENTS.md`: Windows 11 execution rules, subshell stdin protection, token discipline, and `pwsh` protocol.
  - `skills/win11-toolchain/SKILL.md`: Windows 11 4-tier tool selection hierarchy and recipes.
- **`plugins/modern-web-stack/`** (Shared across macOS & Windows 11):
  - `plugin.json`: Manifest for cross-platform web development stack.
  - `rules/AGENTS.md`: Consolidated always-on rules for Node.js, TypeScript 5+, React 19, Tailwind CSS v4, Vitest Browser testing, and GitHub Actions CI (`actionlint`).
  - `skills/<skill-name>/SKILL.md`: `modern-nodejs`, `modern-typescript`, `modern-react-tailwind`, `node-project-architecture`, `tanstack-router`.

---

## 2. Manifest & File Specifications

- **Plugin Manifest (`plugins/<plugin-name>/plugin.json`)**:
  - Do NOT include remote `"$schema"` URLs.
  - Required fields: `name` (lowercase kebab-case matching folder name), `description`.
- **Plugin Rules (`plugins/<plugin-name>/rules/AGENTS.md`)**:
  - Plain Markdown **without YAML frontmatter** (continuously active while the plugin is enabled).
  - Must stay strictly under the `24 KB` (`24,000` bytes) per-file cap.
- **Plugin Skills (`plugins/<plugin-name>/skills/<skill-name>/SKILL.md`)**:
  - YAML frontmatter required: `name`, `description`, `compatibility`.
  - NEVER put `trigger: always_on` in skills.

---

## 3. Mandatory Authoring Invariants

- **Live Documentation First**: Query official docs (`webread https://antigravity.google/docs/plugins`, `https://viteplus.dev/llms-full.txt`, `https://oxc.rs/llms.txt`) before authoring or updating rules and skills.
- **Zero Suppression Directives Policy**: Never recommend `@ts-ignore`, `@ts-expect-error`, or `oxlint-disable`.
- **Zod-First Runtime Validation**: Demonstrate boundary validation with Zod `safeParse`.
- **No Fragile Version Pinning**: Reference major generations or LTS branches (`Node.js (Active LTS)`, `TypeScript 5+`, `PowerShell 7+`).
- **Formatting**: Always format modified `.md` and `.json` files via `vpx oxfmt <files>`.
