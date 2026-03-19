import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  testMatch: "todomvc.spec.ts",
  // 4 workers avoids overwhelming headless Chromium on systems without
  // a display server, where requestAnimationFrame is already degraded.
  workers: 4,
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
      testMatch: ["kitchen-sink-*.spec.ts", "interaction-styling.spec.ts"],
      use: {
        browserName: "chromium",
        baseURL: "http://localhost:3000/kitchen_sink",
      },
    },
    {
      name: "http-demo",
      testMatch: "http-demo.spec.ts",
      use: {
        browserName: "chromium",
        baseURL: "http://localhost:3000/http_demo",
      },
    },
  ],
  webServer: {
    command:
      "cd ../.. && opam exec -- dune build && cp examples/todomvc/index.html _build/default/examples/todomvc/ && cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/ && cp examples/dashboard/index.html _build/default/examples/dashboard/ && cp examples/http_demo/index.html _build/default/examples/http_demo/ && npx serve -l 3000 _build/default/examples",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
