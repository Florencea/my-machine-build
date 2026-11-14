---
name: modern-nodejs
description: Modern Node.js pure ESM standards, two-stage external SSOT documentation and Oxlint anti-pattern gateways, Zod runtime validation, and zero-dependency built-in rules. Use when writing Node.js scripts, managing dependencies, configuring runtimes, or building CLI utilities.
compatibility: Node.js (Active LTS), Vite+, Zod, Oxlint
---

# Modern Node.js Guidelines

## 1. External SSOT & Anti-Pattern Gateways

Verify live Node.js APIs, Vite+ options, and active linter anti-patterns before authoring scripts or configurations:

- **Node.js Official API (Two-Stage `webread`)**:
  - Stage 1 (Index): `webread https://nodejs.org/llms.txt`
  - Stage 2 (Module Markdown): `webread https://nodejs.org/docs/latest/api/<module>.md` (e.g. `sqlite.md`, `util.md`, `test.md`, `fs.md`)
- **Vite+ Reference**:
  - Stage 1: `webread https://viteplus.dev/llms.txt` → Stage 2: `webread https://viteplus.dev/guide/<topic>.md` (plus `vp toolchain` and `vp --help`).
- **Oxlint Node & ESM Anti-Patterns**:
  - Inspect enabled rules locally: `vp lint --rules` (filter `unicorn`, `node`, `import`, `promise`, `oxc`) and `vp lint --print-config`.
  - Retrieve exact anti-pattern rationale and examples: `webread https://oxc.rs/docs/guide/usage/linter/rules/<plugin>/<rule>.md` (e.g. `unicorn/prefer-node-protocol.md`, `unicorn/no-process-exit.md`, `node/no-path-concat.md`, `node/no-new-require.md`).

---

## 2. Zero-Dependency Native Selection Tree

Prioritize Node.js built-ins over third-party dependencies, verifying exact exports in `nodejs.org/docs/latest/api/<module>.md` before use:

- CLI argument parsing and terminal styling → `node:util`
- File system globbing and async I/O → `node:fs/promises`
- Embedded SQLite storage → `node:sqlite`
- Standard Web Globals → `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`
- Unit testing and assertions → `node:test` and `node:assert/strict` (or `vite-plus/test`)
- Environment loading → `process.loadEnvFile()`

---

## 3. Native Manifest Operations (`vp pm pkg`)

Manage `package.json` exclusively through native Vite+ manifest commands:

- Inspect: `vp pm pkg get <key>`
- Mutate: `vp pm pkg set <key>=<value>` (pass `--json` for arrays/objects/booleans)
- Remove: `vp pm pkg delete <key>`
- Standardize & normalize: `vp pm pkg fix`

STRICTLY FORBIDDEN to rewrite `package.json` with raw regex replacements or `jq` file swaps.

---

## 4. Cross-Platform Portability & Process Safety Invariants

- **Pure ESM & `node:` Protocol**: Require `"type": "module"`, prohibit CommonJS (`require`, `module.exports`, `__dirname`), prefix all built-ins with `node:`, and resolve paths relative to `import.meta.dirname` or `fileURLToPath(import.meta.url)`.
- **Path & Glob Composition**: Use `node:path` (`path.join()`, `path.resolve()`, `path.relative()`). Never concatenate paths with `+ '/' +`. Enforce POSIX `/` in glob strings (`pattern.replace(/\\/g, "/")`).
- **Cross-Platform `package.json` Scripts**: Prohibit OS-specific shell builtins (`rm -rf`, `export`, `set`, `mkdir -p`); use Node.js one-liners (`node -e "fs.rmSync('dist', { recursive: true, force: true })"`).
- **Process & Stdin Safety**: Invoke subprocesses via `execFileSync` or `spawnSync` with argument arrays and `{ shell: false }`. Prefer `process.exitCode = 1` over `process.exit(1)`. Never block waiting for stdin in non-interactive automation.
