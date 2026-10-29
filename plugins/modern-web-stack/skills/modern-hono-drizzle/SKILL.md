---
name: modern-hono-drizzle
description: Type-safe backend APIs, OpenAPI specifications with Zod, Drizzle ORM schema SSOT, and fail-closed RBAC routing for Node.js web services. Use when building or refactoring Hono servers, REST APIs, database schemas, or full-stack applications.
compatibility: Node.js (Active LTS), Hono 4+, Drizzle ORM, Zod, Vite+
---

# Modern Hono & Drizzle ORM Full-Stack Guidelines

This skill provides verified architecture blueprints, type-safe API patterns, database schema governance, and security contracts for building high-performance Node.js / edge services with Hono, Zod, and Drizzle ORM.

---

## 1. Declarative OpenAPI Routing (`@hono/zod-openapi`)

Always define HTTP route contracts declaratively using Zod schemas to achieve end-to-end type safety and automated OpenAPI documentation:

### 1.1 Route Contract Specification

```ts
import { createRoute, z } from "@hono/zod-openapi";

export const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(["admin", "user"]),
});

export const ErrorResponseSchema = z.object({
  success: z.literal(false),
  error: z.string(),
});

export const getUserRoute = createRoute({
  method: "get",
  path: "/api/users/{id}",
  request: {
    params: z.object({
      id: z.string().uuid(),
    }),
  },
  responses: {
    200: {
      content: {
        "application/json": {
          schema: UserSchema,
        },
      },
      description: "User details retrieved successfully",
    },
    404: {
      content: {
        "application/json": {
          schema: ErrorResponseSchema,
        },
      },
      description: "User not found",
    },
  },
});
```

### 1.2 Route Implementation & Scalar Documentation Mount

```ts
import { OpenAPIHono } from "@hono/zod-openapi";
import { apiReference } from "@scalar/hono-api-reference";
import { getUserRoute } from "./routes/user.ts";

export const app = new OpenAPIHono();

// Implement route handler with inferred request/response types
app.openapi(getUserRoute, async (c) => {
  const { id } = c.req.valid("param");
  const user = await findUserById(id);
  if (!user) {
    return c.json({ success: false as const, error: "User not found" }, 404);
  }
  return c.json(user, 200);
});

// Interactive Scalar API documentation
app.get(
  "/docs",
  apiReference({
    theme: "purple",
    spec: {
      url: "/openapi.json",
    },
  }),
);

// OpenAPI JSON endpoint
app.doc("/openapi.json", {
  openapi: "3.1.0",
  info: {
    title: "Application API",
    version: "1.0.0",
  },
});
```

---

## 2. Single Source of Truth (SSOT) RPC Type Inference

Mount sub-routers onto a top-level router and export the unified `AppType`. The client consumes full API types without any code-generation steps:

### 2.1 Backend Router Export (`src/server/router.ts`)

```ts
import { OpenAPIHono } from "@hono/zod-openapi";
import { userRoutes } from "./routes/user.ts";
import { authRoutes } from "./routes/auth.ts";

export const router = new OpenAPIHono()
  .route("/api/users", userRoutes)
  .route("/api/auth", authRoutes);

export type AppType = typeof router;
```

### 2.2 Type-Safe Frontend Client Consumption

```ts
import { hc } from "hono/client";
import type { AppType } from "../server/router.ts";

export const client = hc<AppType>("/");

// Full autocomplete, parameter validation, and response type inference
const res = await client.api.users[":id"].$get({
  param: { id: "123e4567-e89b-12d3-a456-426614174000" },
});

if (res.ok) {
  const user = await res.json(); // Type is UserSchema!
  console.log(user.name);
}
```

---

## 3. Drizzle ORM Schema SSOT & Code-First Push

Define database schemas centrally in `src/server/database/schema.ts`. Use Drizzle Kit's code-first schema push for rapid local iteration:

### 3.1 Unified Schema Definition (`src/server/database/schema.ts`)

```ts
import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  role: text("role", { enum: ["admin", "user"] })
    .default("user")
    .notNull(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .$defaultFn(() => new Date())
    .notNull(),
});

export type UserRecord = typeof users.$inferSelect;
export type NewUserRecord = typeof users.$inferInsert;
```

### 3.2 Dual Database Client (SQLite & Cloudflare D1)

```ts
import { createClient } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";
import * as schema from "./schema.ts";

const client = createClient({
  url: process.env.DATABASE_URL ?? "file:./local.db",
});

export const db = drizzle(client, { schema });
```

### 3.3 Code-First Push Workflow

- In `package.json`, configure:
  ```json
  {
    "scripts": {
      "db:push": "drizzle-kit push",
      "db:seed": "vp node scripts/seed.ts",
      "db:studio": "drizzle-kit studio"
    }
  }
  ```
- Always run `vpr db:push` to synchronize schema changes directly to the active database.

---

## 4. Fail-Closed RBAC Routing Security Pattern

Every endpoint must explicitly declare its access control policy. Unannotated routes must fail closed:

```ts
import { createMiddleware } from "hono/factory";

export const requirePermission = (permission: string) =>
  createMiddleware(async (c, next) => {
    const session = c.get("session");
    if (!session || !session.permissions.includes(permission)) {
      return c.json({ success: false, error: "Forbidden: Missing required permission" }, 403);
    }
    await next();
  });

export const authenticatedRoute = createMiddleware(async (c, next) => {
  const session = c.get("session");
  if (!session) {
    return c.json({ success: false, error: "Unauthorized" }, 401);
  }
  await next();
});
```

> [!IMPORTANT]
> **Canary Security Audit Contract**:
> Maintain a dedicated test (`test/canary/rbac-contract.test.ts`) that programmatically scans all registered routes on `router` and asserts that every single non-public path binds either `requirePermission` or `authenticatedRoute`.
