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
      name: "counter",
      testMatch: "counter.spec.ts",
      use: { browserName: "chromium", baseURL: "http://localhost:3000/counter" },
    },
    {
      name: "todomvc",
      testMatch: "todomvc.spec.ts",
      use: { browserName: "chromium", baseURL: "http://localhost:3000/todomvc" },
    },
    {
      name: "router-demo",
      testMatch: "router-navigation.spec.ts",
      use: {
        browserName: "chromium",
        baseURL: "http://localhost:3000/router_demo",
      },
    },
    {
      name: "kitchen-sink",
      testMatch: ["kitchen-sink-*.spec.ts", "ui-*.spec.ts", "interaction-styling.spec.ts", "virtual-list.spec.ts", "telemetry-bridge.spec.ts", "storage.spec.ts", "subs.e2e.ts"],
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
      "cd ../.. && opam exec -- dune build && cp examples/counter/index.html _build/default/examples/counter/ && cp examples/todomvc/index.html _build/default/examples/todomvc/ && cp examples/router_demo/index.html _build/default/examples/router_demo/ && cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/ && cp examples/dashboard/index.html _build/default/examples/dashboard/ && cp examples/http_demo/index.html _build/default/examples/http_demo/ && npx serve -l 3000 _build/default/examples",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
