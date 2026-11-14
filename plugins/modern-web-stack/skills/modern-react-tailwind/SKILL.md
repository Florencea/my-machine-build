---
name: modern-react-tailwind
description: Strict architectural invariants and live external SSOT lookup gateways for modern React, Effect discipline, Tailwind CSS, and component contracts. Use when building React components, actions, forms, hooks, layout structures, and Tailwind styling.
compatibility: React, Tailwind CSS, Vite+, Oxlint
---

# Modern React & Tailwind CSS Guidelines

## 1. External SSOT Lookup Gateways (Required Before Coding)

`react.dev` HTML routes return empty anti-bot pages in `webread`; always resolve React docs via `.md` endpoints from `llms.txt`:

- **React Core & API Reference** (Two-Stage `.md`):
  - Stage 1: `webread https://react.dev/llms.txt`
  - Stage 2: `webread https://react.dev/<path>.md` (e.g. `https://react.dev/reference/react.md`, `https://react.dev/learn/you-might-not-need-an-effect.md`)
- **React & Accessibility Oxlint Rules**:
  - Inspect enabled rules: `vp lint --rules` (filter `react`, `react_perf`, `jsx_a11y`).
  - Rule details & examples: `webread https://oxc.rs/docs/guide/usage/linter/rules/react/<rule>.md` (e.g. `set-state-in-effect.md`, `exhaustive-deps.md`, `forward-ref-uses-ref.md`).
- **Tailwind CSS Documentation** (`/llms.txt` returns 404; HTML routes succeed directly):
  - `webread https://tailwindcss.com/docs/theme` (or `/docs/<topic>`) + inspect local CSS `@theme` definitions.
- **Web Platform Capabilities (Delegate Strictly to MWG)**:
  - Before implementing `<dialog>`, `[popover]`, anchor positioning, View Transitions, Container Queries, `:user-invalid`, or ARIA behaviors, query `vpx modern-web-guidance search "<query>"` and `retrieve "<id>"`.

---

## 2. React Architectural Invariants

- **Server vs Client Boundary**: Default components to React Server Components (RSC). Add `"use client"` strictly when browser APIs, interactive state hooks, or event handlers are needed.
- **Direct `ref` Prop & Function Components**: Pass `ref` directly as a prop (`function Input({ ref, ...props }: InputProps)`). STRICTLY PROHIBITED: `React.forwardRef`, `React.FC`, `React.FunctionComponent`.
- **Actions & Async Unwrapping**: Prefer form actions (`useActionState`, `useFormStatus`, `useOptimistic`) over manual `onSubmit` + `e.preventDefault()`, and `use(Promise)` / `use(Context)` over fetching inside `useEffect`.
- **Effect Synchronization Discipline**: Effects are strictly for synchronizing with external systems (DOM widgets, WebSockets, external stores). Never use `useEffect` for derived state, expensive memoized calculations, prop-change resets, or user event chains; consult `https://react.dev/learn/you-might-not-need-an-effect.md` when in doubt.

---

## 3. Tailwind CSS Design Tokens & `@shadcn/lint` Contracts

- **Design Token SSOT (`@theme`)**: Define CSS tokens centrally in root CSS (`@import "tailwindcss";` + `@theme { ... }`) and bind third-party UI library theme tokens to those CSS variables.
- **Enforced Component Contracts**:
  - `shadcn/no-raw-colors`: Forbid hardcoded hex/rgb values outside `@theme`.
  - `shadcn/no-arbitrary-values`: Ban unmapped arbitrary brackets (e.g. `w-[321px]`).
  - `shadcn/no-inline-styles`: Forbid `style={{ ... }}`; bind CSS variables or variants.
  - `shadcn/no-restyle`: External callers may pass layout/positioning utilities (`allow: ["layout"]`) or declared variants only; never restyle internal typography or borders from outside.
- **Verification**: Run `vpr lint:tailwind` to verify classes and `vpr lint:tailwind:fix` to sort utilities canonically.
