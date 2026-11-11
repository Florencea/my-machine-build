---
name: modern-typescript
description: Strict TypeScript standards (TS 5+), pre-execution live verification, zero suppression directives, Zod runtime validation, and high-performance Oxlint + Oxfmt toolchain for agentic development. Use when writing, refactoring, or type-checking TypeScript code.
compatibility: TypeScript 5+, Oxlint, Oxfmt, Vite+, Zod
---

# Strict TypeScript Guidelines

## 1. Authoritative External Endpoints & Verification Gate

Inspect official references and query local type declarations before modifying code or configurations:

- **TypeScript Reference**: `webread https://www.typescriptlang.org/docs/`
- **Oxc Reference**: `webread --llms https://oxc.rs` (or `https://oxc.rs/llms.txt`)
- **CLI Verification**: Run `vpx oxlint --help` (or `vp lint --help`) and `tsc -b --pretty false`.

---

## 2. Zero Suppression & Non-Negotiable Type Invariants

- **Strict Ban on Suppression Directives**:
  - STRICTLY PROHIBITED: `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`, `/* oxlint-disable */`, `// biome-ignore`.
  - Never downgrade rules in `tsconfig.json` or `.oxlintrc.json`. Resolve all type errors structurally.
- **Ban on Unsafe Casts & Assertions**:
  - Never use double assertions (`as unknown as TargetType`) or raw casts without runtime proof. Narrow types via control flow (`typeof`, `instanceof`, `in`), discriminated unions, or Zod schemas.
- **Strict Boolean Expressions**:
  - Always evaluate explicit booleans (`if (str !== "")`, `if (arr.length > 0)`, `if (obj !== null)`).
- **Single Map Lookups**:
  - Perform a single `.get()` and check against `undefined`. Never invoke `map.has(key)` followed by `map.get(key)`.
- **Type Modeling (`satisfies` vs `Record`)**:
  - Static configurations & known objects $\rightarrow$ use `satisfies Type` to validate shape while preserving literal types.
  - Dynamic dictionaries $\rightarrow$ use `: Record<K, V>` or `Map<K, V>` requiring explicit `undefined` checks.
- **Template Literals**:
  - Only interpolate primitives (`string`, `number`, `boolean`). Explicitly convert complex objects: `${String(val)}` or `${JSON.stringify(val)}`.

---

## 3. Zod-First Runtime Boundary Validation

Validate all external data (API responses, `JSON.parse`, configuration files, `process.env`) using Zod schemas:

```ts
import { z } from "zod";

export const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  role: z.enum(["admin", "user"]).default("user"),
});

export type User = z.infer<typeof UserSchema>;

export function parseUserData(raw: unknown): User | null {
  const result = UserSchema.safeParse(raw);
  return result.success ? result.data : null;
}
```
