import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  testMatch: "todomvc.spec.ts",
  use: {
    headless: true,
  },
  projects: [
    {
      name: "todomvc",
      testMatch: "todomvc.spec.ts",
      use: { browserName: "chromium", baseURL: "http://localhost:3000/todomvc" },
    },
    {
      name: "kitchen-sink",
      testMatch: "kitchen-sink-*.spec.ts",
      use: {
        browserName: "chromium",
        baseURL: "http://localhost:3000/kitchen_sink",
      },
    },
  ],
  webServer: {
    command:
      "cd ../.. && opam exec -- dune build && cp examples/todomvc/index.html _build/default/examples/todomvc/ && cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/ && npx serve -l 3000 _build/default/examples",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
