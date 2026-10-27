# Modern Web Stack Execution Rules (Node.js, TypeScript, React 19, Tailwind v4, Testing & CI)

## Part 1: Modern Node.js & Vite+ Execution Rules

### 1.1 Pre-Execution Config Verification & Native Manifest Operations

- **Pre-Verification Mandate**: Prior to writing or modifying any configuration files (`package.json`, `pnpm-workspace.yaml`, `.npmrc`, toolchain settings), agents MUST verify the exact schema and current runtime options:
  - Check dynamic project/runtime constraints: Run `vp toolchain` or inspect `engines.node` and dependencies in `package.json`. NEVER hardcode or assume fixed version numbers.
  - Query live documentation: Inspect `https://viteplus.dev/llms-full.txt` (via `webread --llms https://viteplus.dev`) or run `<tool> --help`.
  - NEVER guess syntax, package fields (e.g. `exports`, `imports`, `type`), or CLI flags from memory.
- **Native Manifest Operations (`vp pm pkg`)**:
  - When querying or mutating `package.json` fields programmatically, ALWAYS use native Vite+ package manifest commands:
    - Querying: `vp pm pkg get <key>` (or `vp -C <dir> pm pkg get <key>`)
    - Modifying: `vp pm pkg set <key>=<value>` (use `--json` for objects, numbers, booleans, arrays)
    - Deleting: `vp pm pkg delete <key>`
    - Standardizing: `vp pm pkg fix`
  - STRICTLY FORBIDDEN to use raw regex replacements or `jq` with intermediate file swapping (`package.json.tmp && mv`) to mutate `package.json`.

### 1.2 Environment Variables & Runtime Data Validation (Zod First)

- **Mandatory Validation for `process.env`**: Never use unvalidated environment variables or type casts (`Number(process.env.PORT)`, `process.env.SECRET as string`).
- **Safe Zod Parsing**: Validate environment variables with Zod `safeParse` at process startup and derive types via `z.infer<typeof Schema>`.

### 1.3 Pure ESM & Zero-Dependency Built-In Tooling

- **Pure ESM Only**: Always use pure ESM (`.mjs` or `"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g. `import fs from 'node:fs/promises'`).
- **Native Path Resolution**: Use native built-in `import.meta.dirname` and `import.meta.filename`.
- **Batteries-Included Built-Ins**:
  - CLI Argument Parsing: `node:util` `parseArgs({ options, allowPositionals })`
  - Terminal Styling: `node:util` `styleText('color', text)`
  - File Globbing: `node:fs/promises` `glob(pattern)`
  - Embedded Database: `node:sqlite` (`DatabaseSync`)
  - Environment Loading: `process.loadEnvFile()`
  - Native Web Standards: `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`, `AbortController`
  - Unit Testing: `node:test` and `node:assert/strict` for standalone Node scripts
- **Process & Execution Safety**: Prefer `execFileSync` or `spawnSync` with argument arrays and `shell: false`. Signal failure via `process.exitCode = 1` rather than abrupt `process.exit(1)`.

### 1.4 Unified Vite+ Toolchain & Agent-Friendly Formats

- **Unified Vite+ Mandate**: ALWAYS use Vite+ commands across all workflows (`vp`, `vpx`, `vpr`). STRICTLY FORBIDDEN to use package-manager specific runners (`npx`, `pnpm dlx`, `bunx`, `npm run`).
  - Project scripts $\rightarrow$ `vpr <script>` (or `vp run <script>`)
  - One-off tools $\rightarrow$ `vpx <tool>` (e.g. `vpx oxlint`, `vpx oxfmt`)
  - Dependencies $\rightarrow$ `vp install`, `vp update`, `vp add`, `vp remove`
  - Managed Node execution $\rightarrow$ `vp node <script>`
- **Agent-Friendly Formats**:
  - Installed packages: `vp list --json`
  - Outdated dependencies: `vp outdated --format json`
  - Toolchain status: `vp toolchain --json`
  - Test runner: `vp test run --reporter=tap-flat --no-color` (or `vp test run --json`)

---

## Part 2: Strict TypeScript Rules & Type-Checked Invariants

**CRITICAL:** All generated TypeScript code MUST pass `oxlint` (zero warnings, zero errors) and compile cleanly under strict TypeScript (`tsc --noEmit` or `tsc -b --pretty false`) on the first attempt.

### 2.1 Pre-Execution Verification & Zero Suppression Directives

- **Verify Diagnostics & Flags First**: Run `vpx oxlint --help` or `tsc --help`, or inspect `https://oxc.rs/llms.txt` (`webread --llms https://oxc.rs`).
- **NEVER Suppress Compiler or Linter Diagnostics**:
  - STRICTLY PROHIBITED: `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`, `/* oxlint-disable */`, `// oxlint-disable-next-line`, `/* eslint-disable */`, `// biome-ignore`.
  - Never modify `tsconfig.json` or `.oxlintrc.json` to downgrade errors or disable rules.
  - Resolve all type discrepancies structurally via control flow narrowing (`typeof`, `instanceof`, `in`), discriminated unions, or Zod schema validation.

### 2.2 Ban on Unsafe Assertions & Strict Type Hygiene

- **Absolute Ban on Unsafe Casts & `any`**:
  - NEVER use double assertions (`as unknown as TargetType`) or raw casts on untrusted data (`(await res.json()) as UserProfile`).
  - NEVER use the `any` type (`no-unsafe-*`) or non-null assertion operator (`!`).
  - Use Zod `safeParse` for external boundary data, and `satisfies Type` or `as const` for internal known literals.
- **Strict Boolean Expressions**: NEVER evaluate non-boolean values in conditionals (`if (str !== '')`, `if (arr.length > 0)`, `if (obj !== null)`).
- **Single Map Lookup**: NEVER use `Map.has(key)` followed by `Map.get(key)`. Perform a single `const v = map.get(key); if (v !== undefined) { ... }`.
- **Safe Template Literals**: Only interpolate primitive types (`string`, `number`, `boolean`). Explicitly convert complex types via `String(val)` or `JSON.stringify(val)`.
- **Async & Null Safety**: Handle all promises (`await`, `return`, or `void`); always prefer `??` over `||`.
- **Consistent Type Imports**: Enforce `import type { ... }` for type-only imports (`verbatimModuleSyntax`).
- **All-in-One `vite.config.ts`**: Configure Oxlint and Oxfmt rules directly inside `vite.config.ts` (`lint` and `fmt` fields) with `lint.options.typeAware: true` and `lint.options.typeCheck: true`.

---

## Part 3: Modern React 19, Official Best Practices & Tailwind CSS v4

### 3.1 React Official Best Practice: You Might Not Need an Effect

When no external system is involved, **NEVER use an Effect**:

1. **Derived State**: Calculate directly during render (`const fullName = first + ' ' + last;`), never in `useEffect`.
2. **Expensive Computations**: Rely on React Compiler auto-memoization or `useMemo`, never state synced via `useEffect`.
3. **Resetting All State on Prop Change**: Pass an explicit `key` (`<Profile userId={userId} key={userId} />`), never reset state inside `useEffect`.
4. **Adjusting State on Prop Change**: Derive in render instead of mutating state in `useEffect`.
5. **Sharing Event Logic**: Place user-driven actions (POST mutations, notifications) in event handlers or Server Actions, never triggered via state + `useEffect`.
6. **No Effect Cascades**: Compute interdependent updates together in the event handler or render.
7. **App Initialization**: Run one-time setup at module scope or guarded by a module flag, not unguarded in a root `useEffect`.
8. **Parent Notifications & Data Flow**: Call `onChange` directly inside the event handler alongside state updates; let parents fetch and pass data down via props.
9. **External Stores & Data Fetching**: Use `useSyncExternalStore` for external stores; use route `loader`s (TanStack Router), RSC, or `use(Promise)` / TanStack Query for data fetching (with `AbortController` / ignore-flag cleanup if an Effect is unavoidable).

### 3.2 React 19 Core Paradigms

- **Direct Ref Passing**: Pass `ref` directly as a standard prop (`{ ref, ...props }`). STRICTLY PROHIBITED to use `React.forwardRef`.
- **Explicit Component Typing**: STRICTLY PROHIBITED to use `React.FC` or `React.FunctionComponent`.
- **Server Actions & Forms**: Prefer `<form action={serverAction}>` paired with `useActionState`, `useFormStatus`, and `useOptimistic`.
- **React Compiler**: When `@vitejs/plugin-react` has `compiler: true`, avoid manual `useMemo`/`useCallback`/`React.memo` boilerplate.

### 3.3 Tailwind CSS v4 & TanStack Router Rules

- **Design Token SSOT (`@theme`)**: Define tokens in root CSS via `@import "tailwindcss";` and `@theme { ... }`. Bridge UI libraries via CSS variables; never hardcode magic colors or use inline `style={{ ... }}`.
- **Canonical Classes & Safe Merging**: Maintain zero warnings on `vpr lint:tailwind`. Never dynamically interpolate class names (`bg-blue-${shade}`). Merge conditional classes using `clsx` and `tailwind-merge` (`cn(...)`).
- **TanStack Router**: Place route modules under `src/routes/`. NEVER manually edit `src/routeTree.gen.ts`. Validate search parameters using `validateSearch` paired with Zod schemas.

---

## Part 4: Modern Testing & GitHub Actions CI Gatekeeper

### 4.1 Unified Vitest Browser Projects & Three-Tier Gatekeeper

- **Native Vitest Browser Mode**: Write component and E2E tests using `vite-plus/test` and `vite-plus/test/browser-playwright` (`headless: true`, `chromium`) configured directly in `vite.config.ts`. Avoid standalone `playwright.config.ts`.
- **Three-Tier Verification Hierarchy**:
  1. **Tier 1 (`agent:verify:inner`)**: `vpr typecheck && vp lint && vpr lint:tailwind` (< 2s inner loop).
  2. **Tier 2 (`agent:verify:unit`)**: `vpr agent:verify:inner && vpr agent:test:unit`.
  3. **Tier 3 (`agent:verify:gate` / `vpr verify`)**: Full gate (`unit` + `build` + `e2e` + `knip` deadcode).

### 4.2 GitHub Actions CI & `actionlint` Shift-Left Mandate

- **Mandatory Local `actionlint`**: Whenever `.github/workflows/` files are created or modified, agents MUST run `actionlint` locally before staging (`git add`) and pass with **0 errors and 0 warnings**.
- **Offline Guardrail Invariant**: NEVER embed `actionlint` steps or jobs into remote GitHub Actions YAML workflow files.
- **Standard Vite+ CI Pipeline**: Use `voidzero-dev/setup-vp@v1` with `node-version-file: package.json` and `cache: true`, cache `node_modules/.vite/task-cache` and Playwright browsers, and run verification steps in deterministic topological order (`vp install` $\rightarrow$ `vpr typecheck` $\rightarrow$ `vp check` $\rightarrow$ `vpr agent:test:unit` $\rightarrow$ `vp build` $\rightarrow$ `vpr agent:test:e2e`).
