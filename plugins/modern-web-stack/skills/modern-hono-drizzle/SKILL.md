---
name: modern-hono-drizzle
description: Type-safe backend APIs, OpenAPI specifications with Zod, Drizzle ORM schema SSOT, and fail-closed RBAC routing for Node.js web services. Use when building or refactoring Hono servers, REST APIs, database schemas, or full-stack applications.
compatibility: Node.js (Active LTS), Hono 4+, Drizzle ORM, Zod, Vite+
---

# Modern Hono & Drizzle ORM Full-Stack Guidelines

## 1. Authoritative External Endpoints

Query official documentation and inspect local type declarations before authoring routes or schemas:

- **Hono OpenAPI & RPC Reference**: `webread https://hono.dev/examples/zod-openapi` and `webread https://hono.dev/guides/rpc`
- **Drizzle ORM Documentation**: `webread https://orm.drizzle.team/docs/overview`
- **Local Type Definitions**: Inspect exact parameter and configuration signatures via `node_modules/@hono/zod-openapi/**/*.d.ts` and `node_modules/drizzle-orm/**/*.d.ts`.

---

## 2. Declarative OpenAPI Routing & SSOT RPC Inference

- **Declarative Contracts (`@hono/zod-openapi`)**:
  - Define all HTTP endpoint contracts with `createRoute` specifying Zod schemas for `params`, `query`, `json`, and `responses`.
  - Mount sub-routers onto a top-level router and export the unified type:
    ```ts
    export const router = new OpenAPIHono()
      .route("/api/users", userRoutes)
      .route("/api/auth", authRoutes);

    export type AppType = typeof router;
    ```
- **Type-Safe Frontend Consumption (`hono/client`)**:
  - The client imports `AppType` via `hc<AppType>("/")` for end-to-end type safety, autocomplete, and response inference without code-generation steps.

---

## 3. Drizzle ORM Schema SSOT & Code-First Push

- **Schema Definition**:
  - Define database tables centrally in `src/server/database/schema.ts` using Drizzle table primitives (`sqliteTable`, `pgTable`, etc.).
  - Derive entity types directly from schemas via `typeof table.$inferSelect` and `typeof table.$inferInsert`.
- **Code-First Schema Synchronization**:
  - Configure `package.json` with `"db:push": "drizzle-kit push"` and run `vpr db:push` to apply schema changes directly to the database.

---

## 4. Fail-Closed RBAC Routing Security Pattern

- **Explicit Access Control**:
  - Every non-public endpoint must explicitly attach access control middleware (`requirePermission(...)` or `authenticatedRoute`). Unannotated routes must fail closed with HTTP 401/403.
- **Canary Security Audit Contract**:
  - Maintain a dedicated test (`test/canary/rbac-contract.test.ts`) that programmatically inspects all routes registered on `router` and asserts that every non-public route binds an authorization gate.
