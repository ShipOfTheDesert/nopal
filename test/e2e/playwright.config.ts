import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  use: {
    baseURL: "http://localhost:3000",
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
      "cd ../.. && opam exec -- dune build && cp examples/todomvc/index.html _build/default/examples/todomvc/ && npx serve --single -l 3000 _build/default/examples/todomvc",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
