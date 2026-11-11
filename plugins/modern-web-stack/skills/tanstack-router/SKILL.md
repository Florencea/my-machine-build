---
name: tanstack-router
description: File-based routing, type-safe search parameters with Zod, routeTree protection, loaders, and navigation standards with TanStack Router. Use when creating or modifying client-side routes, handling query parameters, or configuring TanStack Router.
compatibility: TanStack Router 1.x+, React 19, Vite+
---

# TanStack Router Guidelines

## 1. Authoritative External Endpoints

Query live documentation before modifying routes or data loading:

- **Router Overview & Setup**: `webread https://tanstack.com/router/latest/docs/framework/react/overview`
- **Search Parameters Guide**: `webread https://tanstack.com/router/latest/docs/framework/react/guide/search-params`
- **Data Loading & Loaders**: `webread https://tanstack.com/router/latest/docs/framework/react/guide/data-loading`

---

## 2. Routing Architecture & File Invariants

- **Route Directory SSOT**:
  - Place all route files strictly under `src/routes/` (`__root.tsx`, `index.tsx`, `canary.tsx`, `$.tsx`).
- **Protected Generated File Invariant**:
  - `src/routeTree.gen.ts` is managed exclusively by `@tanstack/router-plugin/vite`.
  - **STRICTLY PROHIBITED to manually edit `src/routeTree.gen.ts`**. It regenerates automatically during dev or build.

---

## 3. Type-Safe Search Parameters (Zod First)

Always validate search query parameters using Zod within `validateSearch`:

```tsx
import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

const SearchSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  query: z.string().default(""),
});

export const Route = createFileRoute("/items")({
  validateSearch: (search) => SearchSchema.parse(search),
  component: ItemsPage,
});
```

---

## 4. Data Loading & Navigation

- **Loaders over Effects**:
  - Always load initial route data using `loader` functions rather than component `useEffect`.
  - In projects using TanStack Query, prefetch server state ahead of render via `queryClient.ensureQueryData(queryOptions)`.
- **Type-Safe Navigation**:
  - Use `<Link>` and `useNavigate()` with type-checked `to` and `search` parameters.
