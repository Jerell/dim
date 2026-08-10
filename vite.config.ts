import path from "node:path";
import { fileURLToPath } from "node:url";

import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vitest/config";

const root = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [tailwindcss()],
  resolve: {
    alias: [
      {
        find: "@/lib/dim/dim",
        replacement: path.resolve(root, "wasm/dim.ts"),
      },
      { find: "@", replacement: path.resolve(root, "registry") },
    ],
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./tests/react/setup.ts"],
    include: ["tests/react/**/*.test.{ts,tsx}"],
    css: true,
  },
});
