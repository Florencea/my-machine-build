import { defineConfig } from "vite-plus";

export default defineConfig({
  run: {
    cache: {
      scripts: true,
      tasks: true,
    },
  },
  lint: {
    ignorePatterns: [
      "configs/**",
      "plugins/**/resources/**",
      "node_modules/**",
      "dist/**",
      ".vitest/**",
    ],
    options: {
      typeAware: true,
      typeCheck: true,
    },
    categories: {
      correctness: "error",
      suspicious: "error",
      perf: "error",
    },
    plugins: ["unicorn", "typescript", "oxc", "vitest", "promise", "node", "import"],
  },
  fmt: {
    ignorePatterns: [
      "configs/**",
      "plugins/**/resources/**",
      "node_modules/**",
      "dist/**",
      ".vitest/**",
    ],
    sortPackageJson: true,
  },
  test: {
    allowOnly: !process.env.CI,
    silent: "passed-only",
    include: ["tests/**/*.test.ts"],
    environment: "node",
  },
});
