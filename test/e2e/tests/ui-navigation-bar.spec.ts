import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Navigation_bar (RFC 0112, Step 5). Drives the
// intrinsic `data-action="nav-navigate"` / `data-field=<route key>` anchor
// (Task 1) and asserts the navigate message via telemetry (REQ-N2). The field
// anchor is the item id ("settings"), disambiguating it among the tabs.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const SETTINGS = '[data-action="nav-navigate"][data-field="settings"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SETTINGS,
    { timeout: 10000 }
  );
});

test("nav item click dispatches SelectTab via telemetry", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(SETTINGS).click();
  await telemetry.waitForMessage("SelectTab:settings", SETTLE);

  await telemetry.assertDispatched("SelectTab:settings");
});

test("navigation-bar section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(
    page,
    testInfo,
    '[data-testid="navigation-bar-section"]'
  );
});
