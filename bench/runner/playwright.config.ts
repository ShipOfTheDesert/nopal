import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: "*.spec.ts",
  timeout: 120_000,
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
      "cd ../.. && opam exec -- dune build && cp bench/jsfb/index.html _build/default/bench/jsfb/ && npx serve -l 3001 _build/default/bench/jsfb",
    port: 3001,
    reuseExistingServer: !process.env.CI,
  },
});
