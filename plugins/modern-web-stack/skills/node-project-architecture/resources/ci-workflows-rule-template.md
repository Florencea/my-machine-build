---
trigger: glob
globs: ".github/workflows/**"
description: CI workflow verification standards, actionlint requirements, and security guidelines.
---

# CI & GitHub Actions Workflow Standards

Standards for maintaining and updating GitHub Actions workflows.

## 1. Centralized CI Toolchain (`vp-actions`)

- **Standard Web & Fullstack Workflows**:
  - Consume shared Reusable Workflows from `Florencea/vp-actions/.github/workflows/vp-web-ci.yml@v2.0.0`.
  - Pass custom pre-test commands via `pre-test-command` (e.g. `vp run db:seed`) and toggle cross-platform matrix testing with `enable-platform-compat: true`.
- **Specialized Workflows (Desktop / Native / Custom Pipelines)**:
  - If a project requires custom runners, virtual displays (`xvfb-run`), or platform packaging, consume modular Composite Actions:
    - `Florencea/vp-actions/actions/setup-vp-env@v2.0.0`: Handles Node.js setup, Vite+, dependency installation, and Vite Task Cache restoration.
    - `Florencea/vp-actions/actions/setup-playwright@v2.0.0`: Handles Playwright browser caching, installation, and Linux system dependencies.

## 2. Shift-Left Local Verification

- **Strict Requirement**: Whenever `.github/workflows/` files are added or modified, running `actionlint` locally with **0 errors and 0 warnings** is mandatory before staging (`git add`).
- **Execution Script**: Execute via `vpr agent:lint:ci` (or `actionlint` directly).

## 3. Guardrail Boundaries

- **Offline-Only Tool**: `actionlint` is strictly an offline / local shift-left verification guardrail.
- **Remote Workflow Invariant**: Never embed `actionlint` steps into remote GitHub Actions workflow files (`.github/workflows/*.yml`).

## 4. GitHub Actions Runner Best Practices & Invariants

- **Exact SemVer Pinning Invariant**:
  - Always reference GitHub Actions and shared workflows using exact stable SemVer tags (`vX.Y.Z`) and upgrade them via `up`:
    - `Florencea/vp-actions/.github/workflows/vp-web-ci.yml@v2.0.0`
    - `Florencea/vp-actions/actions/setup-vp-env@v2.0.0`
    - `Florencea/vp-actions/actions/setup-playwright@v2.0.0`
    - `actions/checkout@v7.0.1`
    - `voidzero-dev/setup-vp@v1.22.0`
    - `actions/cache@v6.1.0`
    - `actions/upload-artifact@v7.0.2`
  - Strictly avoid unpinned floating major or minor tags (e.g. never `@v1` or `@v7.0`).
- **Concurrency Policy**: Workflows triggered by `push` and `pull_request` must declare top-level `concurrency` with `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}` to prevent redundant CI runs and runner starvation.
- **Timeout Protection**: Every runner job must declare an explicit `timeout-minutes: 15` to prevent stalled tests or deadlocked processes from consuming quota.
- **Architecture-Aware Caching**: Cache keys for toolchain tasks must incorporate `${{ runner.os }}-${{ runner.arch }}` to ensure complete cache isolation across runner architectures.
- **Artifact Retention**: Failure diagnostic uploads via `actions/upload-artifact@v7.0.2` must specify `retention-days: 7` and `if-no-files-found: ignore`.
- **Node.js Runtime Invariant**: Node.js 26 is the project's authoritative Active LTS engine (`package.json` `engines.node`).
