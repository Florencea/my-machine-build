---
trigger: glob
globs: "**/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.json, **/*.html, **/*.css, **/package.json, **/vite.config.*, **/.github/workflows/*"
description: Modern Web Stack execution constraints (Node.js pure ESM, React 19, Tailwind v4, TypeScript invariants, Vitest, CI)
---

# Modern Web Stack Execution Rules (Node.js, TypeScript, React 19, Tailwind v4, Testing & CI)

## 1. Modern Node.js & Vite+ Execution Rules

- **Native Manifest Operations**:
  - Always inspect and modify `package.json` via Vite+ commands (`vp pm pkg get <key>`, `vp pm pkg set <key>=<value> [--json]`, `vp pm pkg delete <key>`). Raw regex or `jq` file swapping is strictly prohibited.
- **Pure ESM & Batteries-Included Built-Ins**:
  - Pure ESM only (`"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`).
  - Node Protocol Imports: Prefix built-in modules with `node:` (`node:fs/promises`, `node:path`). Use `import.meta.dirname`.
  - Prefer built-in APIs (`fetch`, `crypto.randomUUID()`, `structuredClone()`, `node:test`, `node:assert/strict`).
  - Process safety: Use `execFileSync` or `spawnSync` with argument arrays (`shell: false`). Set `process.exitCode = 1` rather than abrupt `process.exit(1)`.
- **Vite Task Caching & Linux CI Case-Sensitivity**:
  - Configure `run.cache: { scripts: true, tasks: true }` in `vite.config.ts`.
  - Import specifiers and asset paths MUST match exact on-disk casing to prevent Linux CI build failures.

---

## 2. Strict TypeScript Rules & Type-Checked Invariants

- **Strict Type Hygiene**:
  - Ban unsafe assertions: NEVER use double assertions (`as unknown as TargetType`) or raw casts. Narrow types via discriminated unions, `typeof`, `instanceof`, `in`, or Zod parsing.
  - Strict booleans & lookups: Never evaluate non-boolean values directly (`if (str !== '')`, `if (arr.length > 0)`). Single Map lookup: `const v = map.get(k); if (v !== undefined) { ... }`.
  - Template literals: Only interpolate primitives (`string`, `number`, `boolean`). Explicitly stringify complex objects.
  - Async handling & imports: Await or return all promises; prefer `??` over `||`. Enforce `import type { ... }` (`verbatimModuleSyntax`).

---

## 3. Modern React 19, Tailwind CSS v4 & Architecture

- **React 19 Core Paradigms**:
  - "You Might Not Need an Effect": Calculate derived state directly during render. User-driven actions belong in event handlers or Server Actions. Never sync state via `useEffect` without external systems.
  - Component signatures: Pass `ref` directly as a standard prop (`{ ref, ...props }`). STRICTLY PROHIBITED: `React.forwardRef`, `React.FC`. Type props directly: `function Button({ title }: ButtonProps)`.
  - Prefer `<form action={serverAction}>` with `useActionState`, `useFormStatus`, and `useOptimistic`.
- **Tailwind CSS v4 & Component Contracts**:
  - Design tokens SSOT: Define tokens in root CSS via `@import "tailwindcss";` and `@theme { ... }`. Never use inline `style={{ ... }}` or magic colors.
  - Component contracts: Enforce `shadcn/no-raw-colors`, `shadcn/no-arbitrary-values`, and `shadcn/no-inline-styles`. External callers may only pass layout utilities (`allow: ["layout"]`) or variant props; never restyle internal typography or borders from outside.
  - TanStack Router: Place route modules under `src/routes/`. NEVER edit `src/routeTree.gen.ts`. Validate search parameters using `validateSearch` + Zod schemas.

---

## 4. Modern Testing & GitHub Actions CI Gatekeeper

- **Vitest Browser Projects & Three-Tier Gatekeeper**:
  - Component and E2E tests must use `vite-plus/test` and `vite-plus/test/browser-playwright` (`headless: true`, `chromium`).
  - Three-Tier Verification: Tier 1 (`vpr typecheck && vp lint && vpr lint:tailwind`), Tier 2 (`agent:verify:inner && vpr agent:test:unit`), Tier 3 (`agent:verify:gate` / `vpr verify`).
- **GitHub Actions CI Mandate**:
  - Floating tags: Reference major floating tags (`actions/checkout@v7`, `voidzero-dev/setup-vp@v1`, `actions/cache@v6`).
  - Concurrency & timeouts: Declare top-level `concurrency` (`group: ${{ github.workflow }}-${{ github.ref }}`) and `timeout-minutes: 15`.
  - Mandatory local `actionlint`: Run `actionlint` locally before staging (`git add`) with 0 errors and 0 warnings.

---

## 5. Native Web Platform Primacy & External Guidance Gatekeeper

- **Zero Local Web Standard Duplication**:
  - `GoogleChrome/modern-web-guidance` (`vpx modern-web-guidance`) is the sole SSOT for HTML5, CSS layout/animation, Web APIs, and accessibility.
- **Mandatory Lookup Gate**:
  - Prior to implementing native overlays (`<dialog>`, `[popover]`), floating elements, anchor positioning, view transitions, or scroll animations, query via `vpx modern-web-guidance search "<query>"`.
- **Native-First Invariant**:
  - When Baseline confirms native browser support, third-party UI libraries for native platform capabilities are strictly banned. Load polyfills conditionally via feature detection and dynamic `import()`.
