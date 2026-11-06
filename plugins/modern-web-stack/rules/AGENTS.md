# Modern Web Stack Execution Rules (Node.js, TypeScript, React 19, Tailwind v4, Testing & CI)

## Part 1: Modern Node.js & Vite+ Execution Rules

### 1.1 Native Manifest Operations (`vp pm pkg`)

- When inspecting or modifying `package.json` programmatically, ALWAYS use Vite+ package manifest commands:
  - Querying: `vp pm pkg get <key>` (or `vp -C <dir> pm pkg get <key>`)
  - Modifying: `vp pm pkg set <key>=<value>` (pass `--json` for objects, booleans, numbers, arrays)
  - Deleting: `vp pm pkg delete <key>`; Standardizing: `vp pm pkg fix`
- STRICTLY FORBIDDEN to use raw regex replacements or `jq` intermediate file swapping to mutate `package.json`.

### 1.2 Environment Variables & Runtime Data Validation (Zod First)

- NEVER access unvalidated environment variables or use raw type casts (`process.env.SECRET as string`). Validate with Zod `safeParse` at process startup and derive types via `z.infer<typeof Schema>`.

### 1.3 Pure ESM & Batteries-Included Built-Ins

- **Pure ESM Only**: Always use pure ESM (`"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g. `import fs from 'node:fs/promises'`). Use native `import.meta.dirname` and `import.meta.filename`.
- **Prefer Built-In APIs**:
  - CLI argument parsing: `node:util` `parseArgs({ options, allowPositionals })`
  - File globbing: `node:fs/promises` `glob(pattern)`
  - Embedded database: `node:sqlite` (`DatabaseSync`)
  - Environment loading: `process.loadEnvFile()`
  - Web standards: `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`
  - Unit testing: `node:test` and `node:assert/strict` for standalone Node scripts
- **Process Safety**: Use `execFileSync` or `spawnSync` with argument arrays (`shell: false`). Set `process.exitCode = 1` rather than abrupt `process.exit(1)`.

### 1.4 Vite Task Caching & Acceleration

- Configure `run.cache: { scripts: true, tasks: true }` in `vite.config.ts`.
- Inspect cache hits via `vpr --last-details`; clean via `vp cache clean` or bypass with `--no-cache`.

### 1.5 Linux CI Case-Sensitivity Defense

- Windows (NTFS) and macOS (APFS) are case-insensitive by default; Linux CI runners are strictly case-sensitive. Import specifiers and asset paths MUST match exact on-disk casing (`import { Button } from "./Button"` only if the file is named `Button.tsx`).

---

## Part 2: Strict TypeScript Rules & Type-Checked Invariants

### 2.1 Zero Suppression Directives & Pre-Execution Verification

- STRICTLY PROHIBITED: `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`, `/* oxlint-disable */`, `// biome-ignore`. Never modify `tsconfig.json` or `.oxlintrc.json` to downgrade errors.
- Confirm unfamiliar API signatures by inspecting local definitions (`node_modules/<pkg>/**/*.d.ts`) or running `tsc -b --pretty false` before completing edits.

### 2.2 Strict Type Hygiene

- **Ban on Unsafe Assertions & `any`**: NEVER use double assertions (`as unknown as TargetType`) or raw casts on untrusted data. Resolve types via discriminated unions, control flow narrowing (`typeof`, `instanceof`, `in`), or Zod parsing.
- **Strict Boolean Expressions**: NEVER evaluate non-boolean values directly in conditionals (`if (str !== '')`, `if (arr.length > 0)`).
- **Single Map Lookup**: NEVER call `Map.has(key)` followed by `Map.get(key)`. Perform a single lookup: `const v = map.get(key); if (v !== undefined) { ... }`.
- **Safe Template Literals**: Only interpolate primitives (`string`, `number`, `boolean`). Explicitly convert complex objects via `String(val)` or `JSON.stringify(val)`.
- **Async Handling & Imports**: Handle all promises (`await`, `return`, or `void`); prefer `??` over `||`. Enforce `import type { ... }` for type-only imports (`verbatimModuleSyntax`).

---

## Part 3: Modern React 19, Tailwind CSS v4 & Architecture

### 3.1 React 19 Core Paradigms & Effect Rules

- **You Might Not Need an Effect**: Calculate derived state directly during render; place user-driven actions in event handlers or Server Actions. Never sync state via `useEffect` without external systems (see the **`modern-react-tailwind`** skill for detailed patterns).
- **Direct Ref Passing**: Pass `ref` directly as a standard prop (`{ ref, ...props }`). STRICTLY PROHIBITED to use `React.forwardRef`.
- **Explicit Component Typing**: STRICTLY PROHIBITED to use `React.FC` or `React.FunctionComponent`. Type props directly: `function Button({ title }: ButtonProps)`.
- **Server Actions & Forms**: Prefer `<form action={serverAction}>` paired with `useActionState`, `useFormStatus`, and `useOptimistic`.

### 3.2 Tailwind CSS v4 & Design System Governance (`@shadcn/lint`)

- **Design Tokens SSOT**: Define tokens in root CSS via `@import "tailwindcss";` and `@theme { ... }`. Never hardcode magic colors or use inline `style={{ ... }}`.
- **Component Contracts**: Strictly enforce `shadcn/no-raw-colors`, `shadcn/no-arbitrary-values`, and `shadcn/no-inline-styles`. External pages may only pass layout utilities (`allow: ["layout"]`) or variant props; never restyle internal component borders or typography from outside.
- **TanStack Router**: Place route modules under `src/routes/`. NEVER manually edit `src/routeTree.gen.ts`. Validate search parameters using `validateSearch` paired with Zod schemas.

---

## Part 4: Modern Testing & GitHub Actions CI Gatekeeper

### 4.1 Vitest Browser Projects & Three-Tier Gatekeeper

- Write component and E2E tests using `vite-plus/test` and `vite-plus/test/browser-playwright` (`headless: true`, `chromium`) configured directly in `vite.config.ts`.
- **Three-Tier Verification Hierarchy**:
  1. Tier 1 (`agent:verify:inner`): `vpr typecheck && vp lint && vpr lint:tailwind` (< 2s inner loop)
  2. Tier 2 (`agent:verify:unit`): `vpr agent:verify:inner && vpr agent:test:unit`
  3. Tier 3 (`agent:verify:gate` / `vpr verify`): Full gate (`unit` + `build` + `e2e` + `knip` deadcode)

### 4.2 GitHub Actions CI & Runner Governance Mandate

- **Major Floating Tags**: Always reference GitHub Actions via their authoritative major floating tag (`actions/checkout@v7`, `voidzero-dev/setup-vp@v1`, `actions/cache@v6`, `actions/upload-artifact@v7`). Never lock to granular minor/patch releases.
- **Top-Level Concurrency**: Workflows triggered by `push` and `pull_request` must declare top-level `concurrency`:
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
  ```
- **Job Timeout Protection**: Every runner job must declare `timeout-minutes: 15`.
- **Architecture-Aware Caching Key**: Vite task cache keys must incorporate `${{ runner.os }}-${{ runner.arch }}`.
- **Mandatory Local `actionlint`**:
  - Whenever `.github/workflows/` files are created or modified, run `actionlint` locally before staging (`git add`) and pass with **0 errors and 0 warnings**.
  - NEVER embed `actionlint` steps or jobs into remote GitHub Actions YAML workflow files.
