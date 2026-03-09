import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  testMatch: "kitchen-sink-draw.spec.ts",
  use: {
    baseURL: "http://localhost:3001",
    headless: true,
  },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
  webServer: {
    command:
      "cd ../.. && opam exec -- dune build && cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/ && npx serve --single -l 3001 _build/default/examples/kitchen_sink",
    port: 3001,
    reuseExistingServer: !process.env.CI,
  },
});
