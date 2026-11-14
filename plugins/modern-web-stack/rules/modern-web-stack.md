---
trigger: glob
globs: "**/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.json, **/*.html, **/*.css, **/package.json, **/vite.config.*, **/.github/workflows/*"
description: Modern Web Stack execution invariants (Node.js pure ESM, TypeScript, React, Tailwind CSS, Testing, Oxlint/Oxfmt & CI)
---

# Modern Web Stack Execution Rules

## 1. Modern Node.js & Vite+ Invariants

- **Native Manifest Operations**: Inspect and edit `package.json` strictly through `vp pm pkg get/set/delete`; never use regex or `jq` rewrites.
- **Pure ESM & Built-Ins**: Require `"type": "module"`. Prohibit CommonJS (`require`, `module.exports`, `__dirname`). Always prefix built-in imports with `node:` (`node:fs/promises`, `node:path`) and use `import.meta.dirname`.
- **Built-In APIs & Process Safety**: Prefer native `fetch`, `crypto.randomUUID()`, `structuredClone()`, `node:sqlite`, and `node:test`. Invoke child processes via `execFileSync` / `spawnSync` with argument arrays (`shell: false`). Prefer setting `process.exitCode = 1` over abrupt `process.exit(1)`.
- **Task Caching & Case-Sensitivity**: Enable `run.cache: { scripts: true, tasks: true }` in `vite.config.ts`. Import specifiers and asset paths must match exact on-disk casing for Linux CI.

---

## 2. Strict TypeScript & Anti-Pattern Gateways

- **Strict Type Hygiene**: Prohibit `@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, double casts (`as unknown as T`), and raw unsafe casts. Narrow types via discriminated unions, `typeof`/`instanceof`/`in`, `satisfies`, or Zod `safeParse`.
- **Control Flow & Lookups**: Require explicit boolean checks (`str !== ""`, `arr.length > 0`). Perform single Map lookup (`const v = map.get(k); if (v !== undefined)`). Interpolate only primitives in template literals. Await or return every promise, prefer `??` over `||`, and enforce `import type` (`verbatimModuleSyntax`).
- **Oxlint Anti-Pattern SSOT**: Query `vp lint --rules` (or `vp lint --print-config`) to inspect active AST/type rules (`typescript`, `unicorn`, `oxc`, `promise`, `node`, `import`, `react`, `vitest`) and read `https://oxc.rs/docs/guide/usage/linter/rules/<plugin>/<rule>.md` via `webread` instead of guessing linter behavior.

---

## 3. React, Tailwind CSS & Routing Invariants

- **React Paradigms**: Calculate derived state during render; never synchronize local state via `useEffect` without external subscriptions. Pass `ref` directly as a standard prop; STRICTLY PROHIBITED: `React.forwardRef`, `React.FC`. Prefer `<form action={...}>` with `useActionState` / `useFormStatus` / `useOptimistic`.
- **Tailwind Design Tokens & Contracts**: Define tokens in root CSS via `@import "tailwindcss";` and `@theme { ... }`. Enforce `shadcn/no-raw-colors`, `shadcn/no-arbitrary-values`, and `shadcn/no-inline-styles`; external callers may pass layout utilities or variants only.
- **TanStack Router**: Place route files under `src/routes/`. NEVER edit `src/routeTree.gen.ts`. Validate search parameters with `validateSearch` and Zod schemas.

---

## 4. Testing & GitHub Actions CI Gatekeeper

- **Vitest Browser & Verification**: Use `vite-plus/test` and `vite-plus/test/browser-playwright` (`headless: true`, `chromium`) for browser E2E tests. Run `vp check`, `vp run typecheck` (or `tsc -b --pretty false`), and `vp test run` before finalizing changes.
- **GitHub Actions CI**: Pin actions and reusable workflows to exact SemVer tags (never floating `@v1` / `@v7`), declare top-level `concurrency` (`group: ${{ github.workflow }}-${{ github.ref }}`) and `timeout-minutes: 15`, and validate workflows locally with `actionlint` (0 errors/warnings) before staging.

---

## 5. External SSOT Lookup Gateways

- **Web Platform SSOT**: Query `vpx modern-web-guidance search "<query>"` / `retrieve "<id>"` before implementing overlays (`<dialog>`, `[popover]`), anchor positioning, view transitions, scroll animations, or accessibility patterns. Prefer native Baseline APIs over third-party polyfills.
- **Two-Stage Library Docs**: Query `/llms.txt` → targeted `.md` pages (mandatory `.md` endpoints for `react.dev` and `tanstack.com`; `/llms.txt` + `node_modules/**/*.d.ts` for `hono.dev`) or local `.d.ts` declarations rather than relying on stale memory.
