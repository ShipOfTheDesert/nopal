import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Text_input (RFC 0112, Step 5). Drives the
// intrinsic `data-field` anchor (Task 1) and asserts the resulting message via
// telemetry (REQ-N2). The "Default" input has no explicit id, so its field
// anchor falls back to the slug of its label, "default". Scoped to the
// text-input section so the field anchor is unambiguous across the page.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before driving the input.

const INPUT = '[data-testid="text-input-section"] [data-field="default"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    INPUT,
    { timeout: 10000 }
  );
});

test("typing dispatches Default_changed via telemetry", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(INPUT).fill("hello");
  await telemetry.waitForMessage("Default_changed:hello", SETTLE);

  await telemetry.assertDispatched("Default_changed:hello");
});

test("text-input section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(
    page,
    testInfo,
    '[data-testid="text-input-section"]'
  );
});
