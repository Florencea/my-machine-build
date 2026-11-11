---
name: modern-nodejs
description: Modern Node.js pure ESM standards, config pre-verification, Zod runtime validation, and zero-dependency built-in rules. Use when writing Node.js scripts, managing dependencies, configuring runtimes, or building CLI utilities.
compatibility: Node.js (Active LTS), Vite+, Zod
---

# Modern Node.js Guidelines

## 1. Authoritative External Endpoints

Query official documentation before authoring Node.js scripts or configurations:

- **Node.js Official API Reference**: `webread https://nodejs.org/api/`
- **Vite+ Documentation**: `webread --llms https://viteplus.dev` (or `https://viteplus.dev/llms-full.txt`)
- **Runtime Toolchain Inspection**: `vp toolchain` to inspect runtime version and active tools dynamically.

---

## 2. Zero-Dependency Native Selection Tree

Prioritize Node.js built-ins over third-party dependencies:

- **CLI Argument Parsing**: Always use `node:util` `parseArgs({ options, allowPositionals })`.
- **Terminal Styling**: Always use `node:util` `styleText('color', text)`.
- **File System Globbing**: Always use `node:fs/promises` `glob(pattern)`.
- **Embedded Database**: Always use native `node:sqlite` (`DatabaseSync`).
- **Standard Web Globals**: Always use native `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`.
- **Unit Testing**: Always use native `node:test` and `node:assert/strict`.
- **Environment Loading**: Always use native `process.loadEnvFile()`.

---

## 3. Native Manifest Operations (`vp pm pkg`)

Always manage `package.json` fields via native Vite+ manifest commands:

- Inspect: `vp pm pkg get <key>`
- Mutate: `vp pm pkg set <key>=<value>` (pass `--json` for arrays/objects/booleans)
- Remove: `vp pm pkg delete <key>`
- Standardize & Normalize: `vp pm pkg fix`

STRICTLY FORBIDDEN to use raw regex replacement or `jq` file swapping (`package.json.tmp && mv`).

---

## 4. Cross-Platform Portability & Process Safety

- **Path Composition**:
  - Always use `node:path` methods (`path.join()`, `path.resolve()`, `path.relative()`).
  - Use `fileURLToPath(import.meta.url)` and `import.meta.dirname` in ESM.
  - In all glob patterns, enforce POSIX forward slashes `/` (`pattern.replace(/\\/g, "/")`).
- **Cross-Platform `package.json` Scripts**:
  - Prohibit OS-specific builtins (`rm -rf`, `export VAR=val`, `set VAR=val`).
  - Use cross-platform Node.js one-liners: `node -e "fs.rmSync('dist', { recursive: true, force: true })"`.
- **Process Safety**:
  - Always invoke child processes via `execFileSync` or `spawnSync` with an argument array and `{ shell: false }`. Avoid string-concatenated shell execution.
  - Headless Stdin: Never prompt for standard input in automated scripts to prevent background subshell hangs.
