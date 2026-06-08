import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Checkbox (RFC 0112, Step 5). Drives the
// intrinsic `data-field` anchor (Task 1) and asserts the resulting message via
// telemetry (REQ-N2). The agree checkbox's field anchor is the slug of its
// label, "I agree to the terms" -> "i-agree-to-the-terms".
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const AGREE = '[data-field="i-agree-to-the-terms"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    AGREE,
    { timeout: 10000 }
  );
});

test("checkbox toggle dispatches Toggle_agree via telemetry", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(AGREE).click();
  await telemetry.waitForMessage("Toggle_agree:true", SETTLE);

  await telemetry.assertDispatched("Toggle_agree:true");
});

test("checkbox section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(
    page,
    testInfo,
    '[data-testid="form-controls-section"]'
  );
});
