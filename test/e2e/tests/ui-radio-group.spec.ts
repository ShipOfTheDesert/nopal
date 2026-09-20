import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Radio_group (RFC 0112, Step 5). Drives the
// intrinsic `data-field` anchor (Task 1) and asserts the resulting message via
// telemetry (REQ-N2). Every option in a group shares `data-field=<group name>`
// (slug of the group label "Favorite color"), so the specific option is
// disambiguated by its own `id`, which is `<group id>-<slug value>`.
//
// It used to be disambiguated by `aria-label`. That pair is no longer emitted
// on a radio: an option is now named by `aria-labelledby` pointing at its
// label element, so carrying `aria-label` as well would give it two accessible
// names and let the invisible one win. The `id` is the replacement selector,
// and unlike the old one it is stable under a relabelling.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const GREEN = '[data-field="favorite-color"][id="favorite-color-green"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    GREEN,
    { timeout: 10000 }
  );
});

test("radio select dispatches Select_color via telemetry", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(GREEN).click();
  await telemetry.waitForMessage("Select_color:green", SETTLE);

  await telemetry.assertDispatched("Select_color:green");
});

test("radio-group section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(
    page,
    testInfo,
    '[data-testid="form-controls-section"]'
  );
});
