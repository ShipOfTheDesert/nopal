import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  workers: 4,
  use: { headless: true },
  projects: [
    {
      name: "todomvc",
      testMatch: "todomvc.spec.ts",
      use: { browserName: "chromium", baseURL: "http://localhost:3001/todomvc" },
    },
    {
      name: "kitchen-sink",
      testMatch: ["kitchen-sink-*.spec.ts", "interaction-styling.spec.ts", "storage.spec.ts"],
      use: { browserName: "chromium", baseURL: "http://localhost:3001/kitchen_sink" },
    },
    {
      name: "http-demo",
      testMatch: "http-demo.spec.ts",
      use: { browserName: "chromium", baseURL: "http://localhost:3001/http_demo" },
    },
  ],
});
