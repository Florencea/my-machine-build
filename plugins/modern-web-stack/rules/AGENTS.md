# Modern Web Stack Execution Rules (Node.js, TypeScript, React 19, Tailwind v4, Testing & CI)

## Part 1: Modern Node.js & Vite+ Execution Rules

### 1.1 Native Manifest Operations (`vp pm pkg`)

- When inspecting or modifying `package.json`, ALWAYS use Vite+ commands (`vp pm pkg get <key>`, `vp pm pkg set <key>=<value> [--json]`, `vp pm pkg delete <key>`, `vp pm pkg fix`). STRICTLY FORBIDDEN to use raw regex or `jq` file swapping.

### 1.2 Environment Variables & Runtime Data Validation (Zod First)

- NEVER access unvalidated environment variables or use raw casts (`process.env.SECRET as string`). Validate with Zod `safeParse` at startup and derive types via `z.infer<typeof Schema>`.

### 1.3 Pure ESM & Batteries-Included Built-Ins

- **Pure ESM Only**: Always use pure ESM (`"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g. `import fs from 'node:fs/promises'`). Use native `import.meta.dirname`.
- **Prefer Built-In APIs**: Argument parsing (`node:util` `parseArgs`), globbing (`node:fs/promises` `glob`), SQLite (`node:sqlite` `DatabaseSync`), env loading (`process.loadEnvFile()`), web standards (`fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`), tests (`node:test`, `node:assert/strict`).
- **Process Safety**: Use `execFileSync` or `spawnSync` with argument arrays (`shell: false`). Set `process.exitCode = 1` rather than abrupt `process.exit(1)`.

### 1.4 Vite Task Caching & Acceleration

- Configure `run.cache: { scripts: true, tasks: true }` in `vite.config.ts`. Inspect cache hits via `vpr --last-details`; clean via `vp cache clean` or bypass with `--no-cache`.

### 1.5 Linux CI Case-Sensitivity Defense

- Import specifiers and asset paths MUST match exact on-disk casing (`import { Button } from "./Button"` only if named `Button.tsx`).

---

## Part 2: Strict TypeScript Rules & Type-Checked Invariants

### 2.1 Zero Suppression Directives & Pre-Execution Verification

- STRICTLY PROHIBITED: `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`, `/* oxlint-disable */`, `// biome-ignore`. Never modify `tsconfig.json` or `.oxlintrc.json` to downgrade errors.
- Confirm unfamiliar API signatures via local definitions (`node_modules/<pkg>/**/*.d.ts`) or `tsc -b --pretty false`.

### 2.2 Strict Type Hygiene

- **Ban on Unsafe Assertions & `any`**: NEVER use double assertions (`as unknown as TargetType`) or raw casts. Narrow types via discriminated unions, `typeof`, `instanceof`, `in`, or Zod parsing.
- **Strict Booleans & Lookups**: Never evaluate non-boolean values directly (`if (str !== '')`, `if (arr.length > 0)`). Never call `Map.has(key)` followed by `Map.get(key)` (single lookup: `const v = map.get(key); if (v !== undefined)`).
- **Template Literals**: Only interpolate primitives (`string`, `number`, `boolean`). Explicitly stringify complex objects.
- **Async Handling & Imports**: Handle all promises (`await`, `return`, or `void`); prefer `??` over `||`. Enforce `import type { ... }` (`verbatimModuleSyntax`).

---

## Part 3: Modern React 19, Tailwind CSS v4 & Architecture

### 3.1 React 19 Core Paradigms & Effect Rules

- **You Might Not Need an Effect**: Calculate derived state directly during render; place user-driven actions in event handlers or Server Actions. Never sync state via `useEffect` without external systems (see `modern-react-tailwind` skill).
- **Component Signatures & Refs**: Pass `ref` directly as a standard prop (`{ ref, ...props }`). STRICTLY PROHIBITED to use `React.forwardRef`, `React.FC`, or `React.FunctionComponent`. Type props directly: `function Button({ title }: ButtonProps)`.
- **Server Actions & Forms**: Prefer `<form action={serverAction}>` paired with `useActionState`, `useFormStatus`, and `useOptimistic`.

### 3.2 Tailwind CSS v4 & Design System Governance (`@shadcn/lint`)

- **Design Tokens SSOT**: Define tokens in root CSS via `@import "tailwindcss";` and `@theme { ... }`. Never hardcode magic colors or use inline `style={{ ... }}`.
- **Component Contracts**: Strictly enforce `shadcn/no-raw-colors`, `shadcn/no-arbitrary-values`, and `shadcn/no-inline-styles`. External pages may only pass layout utilities (`allow: ["layout"]`) or variant props; never restyle internal component borders or typography from outside.
- **TanStack Router**: Place route modules under `src/routes/`. NEVER manually edit `src/routeTree.gen.ts`. Validate search parameters using `validateSearch` paired with Zod schemas.

---

## Part 4: Modern Testing & GitHub Actions CI Gatekeeper

### 4.1 Vitest Browser Projects & Three-Tier Gatekeeper

- Write component and E2E tests using `vite-plus/test` and `vite-plus/test/browser-playwright` (`headless: true`, `chromium`) configured in `vite.config.ts`.
- **Three-Tier Verification**: Tier 1 (`vpr typecheck && vp lint && vpr lint:tailwind`), Tier 2 (`agent:verify:inner && vpr agent:test:unit`), Tier 3 (`agent:verify:gate` / `vpr verify`).

### 4.2 GitHub Actions CI & Runner Governance Mandate

- **Floating Tags & Concurrency**: Always reference major floating tags (`actions/checkout@v7`, `voidzero-dev/setup-vp@v1`, `actions/cache@v6`, `actions/upload-artifact@v7`). Push/PR workflows must declare top-level `concurrency` (`group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}`).
- **Timeouts & Keys**: Every job must declare `timeout-minutes: 15`. Task cache keys must incorporate `${{ runner.os }}-${{ runner.arch }}`.
- **Mandatory Local `actionlint`**: Run `actionlint` locally before staging (`git add`) with 0 errors and 0 warnings. NEVER embed `actionlint` into remote GitHub Actions YAML workflow files.

---

## Part 5: Native Web Platform Primacy & External Modern Web Guidance Gatekeeper

### 5.1 Zero Local Web Standard Duplication (External SSOT)

- The repository maintains zero static specifications, cheat sheets, or tutorials for native HTML5, CSS layout/animation standards, Web APIs, client-side form validation, and accessibility.
- `GoogleChrome/modern-web-guidance` (`vpx modern-web-guidance`) is the sole authoritative Single Source of Truth (SSOT) across all web platform capabilities.

### 5.2 Mandatory External Lookup Gate (Evidence-First Verification)

- Prior to implementing or refactoring any web UI component, native overlay (`<dialog>`, `[popover]`), floating element, anchor positioning, view transition, scroll-driven animation, form validation state, or accessibility pattern, active CLI query evidence MUST exist in the conversation trajectory:
  - Search: `vpx modern-web-guidance search "<action-oriented-query>"`
  - Retrieve: `vpx modern-web-guidance retrieve "<id>"`
- Generating web platform implementations from unverified pre-training memory or implementing obsolete JavaScript workarounds is strictly categorized as a **Verification Gate Failure**.

### 5.3 Native-First Invariant & Third-Party Library Ban

- When MWG guidance confirms native browser support (Baseline Widely Available or Newly Available), agents are STRICTLY FORBIDDEN from importing third-party UI libraries (e.g. external modal, tooltip, or floating-positioning packages) or writing bespoke JavaScript emulation layers for native capabilities (`<dialog>`, `[popover]`, `anchor()`, `@starting-style`, `view-transition`).

### 5.4 Unified Vite+ Execution Mandate

- All guidance queries and legacy scans must strictly execute via bare `vpx modern-web-guidance`. Invoking `npx` or `pnpx` is strictly prohibited.

### 5.5 Progressive Enhancement & Conditional Polyfills

- When polyfills are required for Newly Available features, load them strictly via runtime feature detection and dynamic `import()` (never unconditional static bundle imports).
