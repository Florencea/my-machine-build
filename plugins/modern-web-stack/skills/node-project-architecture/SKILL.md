---
name: node-project-architecture
description: Architecture blueprint, rules splitting standards, and workspace layout for Node.js projects with package.json. Use when creating a new Node.js project, refactoring a bloated AGENTS.md, designing .agents/rules and .agents/skills, or configuring agent:* package scripts.
compatibility: Node.js (Active LTS), Vite+, Antigravity
---

# Node.js Project Architecture & Rules Splitting Guidelines

This skill defines the canonical project structure, VSCode integration, CI workflows, and rules splitting standards for Node.js / Vite web applications operating in Google Antigravity.

## 1. Modern Workspace Layout (Antigravity Standards)

Avoid monolithic, multi-thousand-line `AGENTS.md` files at the project root. Instead, adopt the modular Antigravity workspace layout:

```text
<project-root>/
├── package.json              # Central scripts with three-tier agent:* gates
├── pnpm-workspace.yaml       # Workspace config with saveExact: true to pin dependency versions
├── AGENTS.md                 # Lean project overview, SSOT invariants, architecture map (< 3 KB)
├── .vscode/                  # Standardized editor toolchain configuration
│   ├── settings.json         # Oxc formatter, Vite+ script runner, ESLint/Prettier disabled
│   └── extensions.json       # Oxc + Vite+ extension recommendations
├── .github/
│   └── workflows/
│       ├── ci.yml            # Fast gatekeeper CI with floating major tags & concurrency control
│       └── node-canary.yml   # Node.js runtime canary check
└── .agents/
    ├── rules/                # Domain-specific rules with glob triggers (Global rules handle CI/testing/runtime)
    │   ├── api-routes.md     # trigger: glob -> "src/server/routes/**, src/api/**"
    │   ├── database.md       # trigger: glob -> "src/server/database/**, src/db/**"
    │   ├── ui-styling.md     # trigger: glob -> "src/client/components/**, src/components/**"
    │   ├── routing.md        # trigger: glob -> "src/client/routes/**"
    │   └── locales.md        # trigger: glob -> "src/locales/**"
    └── skills/               # Project-specific repeatable workflows (on-demand runbooks)
        ├── scaffold-feature/
        │   └── SKILL.md      # Step-by-step feature generator
        └── database-seed/
            └── SKILL.md      # Database schema sync and test fixtures generator
```

> [!NOTE]
> **Global Plugins vs Local Rules Division**:
>
> - **Global Plugins** (`~/.gemini/config/plugins/`): Enforce machine-wide standards via common CLI tools (`common-modern-tools`), platform plugins (`macos-modern-tools` / `win11-modern-tools`), and the shared `modern-web-stack` plugin (strict TypeScript safety, modern Node.js runtime behavior, React 19 / Tailwind v4 standards, GitHub Actions CI `actionlint` verification, and Vitest testing standards).
> - **Local Rules** (`.agents/rules/`): Enforce project-unique domain concerns (e.g. database schema migrations, specific routing topologies, domain localization, chess/game engines).

---

## 2. Editor Integration (`.vscode/`)

Standardize editor ergonomics to ensure seamless human-agent pair programming and eliminate linter conflicts:

- **`.vscode/settings.json`**:
  - **Oxc Formatter & Linter**: Set `editor.defaultFormatter` to `oxc.oxc-vscode` and enable `source.fixAll.oxc: explicit`.
  - **Disable Legacy Linters**: Explicitly set `"eslint.enable": false` and `"prettier.enable": false` to prevent duplicate diagnostics and editor lag.
  - **Vite+ Script Runner**: Set `"npm.scriptRunner": "vp"` so VS Code runs tasks via `vp`.
  - **Single Root Config**: Set `"oxc.disableNestedConfig": true` and `"oxc.fmt.disableNestedConfig": true`.
  - **TypeScript Import Preferences**: Set `"js/ts.preferences.preferTypeOnlyAutoImports": true` to support `verbatimModuleSyntax`.
  - **Exclude Auto-Generated Files**: Exclude generated files (e.g. `**/routeTree.gen.ts`) from formatting, file watchers, and searches.
- **`.vscode/extensions.json`**:
  - Recommendations: `oxc.oxc-vscode`, `VoidZero.vite-plus-extension-pack`, `bradlc.vscode-tailwindcss`, `typescriptteam.native-preview`.
  - Unwanted: `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`.

---

## 3. Continuous Integration & GitHub Actions Invariants (`.github/`)

Follow modern CI/CD governance to achieve deterministic verification and eliminate runner starvation:

- **Major Floating Tags Invariant**:
  - Always reference GitHub Actions via their authoritative Major floating tag:
    - `actions/checkout@v7`
    - `voidzero-dev/setup-vp@v1`
    - `actions/cache@v6`
    - `actions/upload-artifact@v7`
  - Strictly avoid locking actions to granular minor or patch releases (e.g. never use `@v1.21.2` or `@v4`).
- **Concurrency & Redundancy Policy**:
  - Workflows triggered by `push` and `pull_request` must declare top-level `concurrency` with `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}`.
- **Job Timeout Protection**:
  - Every runner job must declare an explicit `timeout-minutes: 15`.
- **Architecture-Aware Caching Key**:
  - Cache keys for toolchain tasks (Vite Task Cache) must incorporate `${{ runner.os }}-${{ runner.arch }}` to isolate execution environments:
    ```yaml
    key: ${{ runner.os }}-${{ runner.arch }}-vite-task-cache-${{ hashFiles('pnpm-lock.yaml') }}-${{ github.sha }}
    ```
- **Playwright Binary Caching**:
  - Cache Playwright browser binaries (`${{ env.PLAYWRIGHT_BROWSERS_PATH }}`) keyed to the Playwright CLI version.
- **Artifact Retention**:
  - Configure `actions/upload-artifact@v7` on failure with explicit `retention-days: 7` and `if-no-files-found: ignore`.
- **Local Shift-Left CI Verification (`actionlint`)**:
  - Whenever `.github/workflows/` files are created or modified, run `vpr lint:ci` (`actionlint`) locally.
  - Must pass with **0 errors and 0 warnings** before staging (`git add`).
  - **Offline Invariant**: `actionlint` is strictly a local pre-commit check; NEVER embed `actionlint` steps into remote GitHub Actions YAML workflow files.

---

## 4. Unified Gate Architecture & Vitest Browser Projects

In `package.json`, adopt the standard **three-tier gatekeeper architecture**:

```json
{
  "scripts": {
    "agent:test:e2e": "vp test run --project e2e --reporter=tap-flat --no-color",
    "agent:test:unit": "vp test run --project unit --reporter=tap-flat --no-color",
    "agent:verify:gate": "vpr agent:verify:unit && vp build && vpr agent:test:e2e",
    "agent:verify:inner": "vpr typecheck && vp lint && vpr lint:tailwind",
    "agent:verify:unit": "vpr agent:verify:inner && vpr agent:test:unit",
    "check:deadcode": "knip",
    "check:fast": "vpr typecheck && vp lint && vpr agent:test:unit",
    "lint:ci": "actionlint",
    "lint:tailwind": "node scripts/lint-tailwind.ts",
    "lint:tailwind:fix": "node scripts/lint-tailwind.ts --fix",
    "test:e2e": "vp test run --project e2e",
    "test:setup": "playwright install chromium",
    "test:unit": "vp test run --project unit",
    "typecheck": "tsc -b --pretty false",
    "verify": "vp check && vpr lint:tailwind && vpr check:deadcode && vp test run && vp build"
  }
}
```

### Gatekeeper Hierarchy:

1. **Tier 1 (Inner Loop - `agent:verify:inner`)**: Runs `vpr typecheck` + `vp lint` + `vpr lint:tailwind`. Ultra-fast feedback loop during active editing (< 2s).
2. **Tier 2 (Unit Verification - `agent:verify:unit`)**: Runs `agent:verify:inner` + `agent:test:unit`. Validates functionality without build overhead.
3. **Tier 3 (Gatekeeper - `agent:verify:gate` or `vpr verify`)**: Runs comprehensive gate (`unit` + `build` + `e2e` + `deadcode`). Mandatory before completing substantial features.
4. **Task Caching Acceleration**: Scripts executed via `vpr` leverage Vite Task caching (`run.cache: { scripts: true }`). Replay unmodified steps in milliseconds. Use `vpr --last-details` to inspect cache hit status or `vp cache clean` / `vpr --no-cache` to force a clean run.
