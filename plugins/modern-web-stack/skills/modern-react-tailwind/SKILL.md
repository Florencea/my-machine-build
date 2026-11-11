---
name: modern-react-tailwind
description: Strict best practices for modern React 19, official 'You Might Not Need an Effect' rules, and Tailwind CSS v4. Use when building React components, server actions, forms, hooks, layout structures, and styling with Tailwind CSS v4.
compatibility: React 19.x, Tailwind CSS 4.x, Vite+
---

# Modern React 19 & Tailwind CSS v4 Guidelines

## 1. Authoritative External Endpoints (Look Before Leaping)

Before authoring components or styling, query live documentation:

- **React 19 Official Reference**: `webread https://react.dev/reference/react`
- **Official "You Might Not Need an Effect"**: `webread https://react.dev/learn/you-might-not-need-an-effect`
- **Tailwind CSS v4 Documentation**: `webread https://tailwindcss.com/docs`
- **Web Platform Standards & Modern Web Guidance (External SSOT)**: For all native HTML/CSS/DOM capabilities (`<dialog>`, `[popover]`, `anchor()`, View Transitions, Container Queries, `:user-invalid`, ARIA), execute `vpx modern-web-guidance search "<query>"` / `retrieve "<id>"`. This skill defines React 19 and Tailwind architecture only; all underlying web platform capabilities are strictly delegated to external MWG queries.

---

## 2. Component Architecture & React 19 Paradigms

- **Server vs Client Boundary**:
  - Default all components to **React Server Components (RSC)**.
  - Add `"use client"` only when requiring browser APIs, interactive state hooks (`useState`, `useReducer`), event handlers (`onClick`, `onChange`), or custom client hooks.
- **Direct Ref Passing**:
  - Pass `ref` directly as a regular prop: `function Input({ ref, ...props }: InputProps)`.
  - Strictly prohibited to use `React.forwardRef`, `React.FC`, or `React.FunctionComponent`.
- **Form Actions & Optimistic State**:
  - Prefer native `<form action={serverAction}>` paired with `useActionState`, `useFormStatus`, and `useOptimistic`.
  - Avoid legacy `onSubmit` handlers paired with `e.preventDefault()`.
- **Async Resource Unwrapping**:
  - Use `use(Promise)` or `use(Context)` to unwrap resources directly during render. Never use `useEffect` for initial data fetching.

---

## 3. Effect Discipline: The Synchronization Rule

Effects are an escape hatch strictly reserved for synchronizing with external systems (browser DOM APIs, third-party widgets, WebSockets, external stores).

- **The Synchronization Test**:
  - Is it synchronizing with an external system? $\rightarrow$ **Use an Effect**.
  - Is it transforming data for rendering, handling user events, resetting state on prop change, or notifying parents? $\rightarrow$ **Do not use an Effect**.
- **Official 12 Scenarios**:
  - For concrete patterns covering derived state, expensive calculations, prop change resets, event sharing, POST requests, cascading chains, app initialization, parent notification, store subscriptions, and race-free data fetching, query the official reference:
    `webread https://react.dev/learn/you-might-not-need-an-effect`

---

## 4. Tailwind CSS v4 & Design System Governance

### 4.1 Design Token Single Source of Truth (`@theme`)

Define design tokens centrally in the root CSS file (`src/index.css`):

```css
@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --color-brand-accent: #8b5cf6;
  --font-display: "Inter", sans-serif;
}
```

Bridge third-party component libraries (e.g. Ant Design tokens) directly to CSS variables defined in `@theme`.

### 4.2 Component Contracts & Linting (`@shadcn/lint`)

- **`shadcn/no-raw-colors`**: Strictly forbids hardcoding hex/rgb values or unmapped color utilities. All colors must derive from `@theme`.
- **`shadcn/no-arbitrary-values`**: Bans arbitrary brackets (e.g. `w-[321px]`). Use standardized spacing scale tokens.
- **`shadcn/no-inline-styles`**: Forbids `style={{ ... }}` attributes. Dynamic properties must bind CSS variables or variant props.
- **`shadcn/no-restyle`**: External pages may only pass layout and positioning utilities (`allow: ["layout"]`, e.g. `w-full`, `mt-4`) or declared variant props; never restyle internal component borders or typography from outside.
- **LSP Validation**:
  - Verify class compatibility: `vpr lint:tailwind`
  - Auto-sort and canonically format utility classes: `vpr lint:tailwind:fix`
