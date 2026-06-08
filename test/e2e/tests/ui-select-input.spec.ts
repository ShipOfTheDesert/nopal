import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Select_input (RFC 0112, Step 5). Drives the
// intrinsic `data-field` anchor (Task 1) and asserts the resulting message via
// telemetry (REQ-N2). The "T-shirt size" select's field anchor is the slug of
// its label, "t-shirt-size".
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const SELECT = '[data-field="t-shirt-size"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SELECT,
    { timeout: 10000 }
  );
});

test("select change dispatches Change_size via telemetry", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(SELECT).selectOption("large");
  await telemetry.waitForMessage("Change_size:large", SETTLE);

  await telemetry.assertDispatched("Change_size:large");
});

test("select-input section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(
    page,
    testInfo,
    '[data-testid="form-controls-section"]'
  );
});
