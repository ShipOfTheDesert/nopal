import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Toast (RFC 0112, Step 5). Drives the intrinsic
// `data-action="toast-dismiss"` anchor (Task 1) and asserts the dismiss message
// via telemetry (REQ-N2). A toast must be shown first; the toast body itself is
// the dismiss control. Driven before the 3s auto-dismiss elapses, gated on
// telemetry rather than a fixed delay.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const TRIGGER_INFO = '[data-testid="toast-trigger-info"]';
const DISMISS = '[data-action="toast-dismiss"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    TRIGGER_INFO,
    { timeout: 10000 }
  );
});

test("toast dismiss dispatches Dismiss message via telemetry", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(TRIGGER_INFO).click();
  await telemetry.waitForMessage("Toast:ShowInfo", SETTLE);

  await page.locator(DISMISS).click();
  await telemetry.waitForMessage("Toast:Dismiss", SETTLE);

  await telemetry.assertSequence(["Toast:ShowInfo", "Toast:Dismiss"]);
});

test("toast section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, '[data-testid="toast-section"]');
});
