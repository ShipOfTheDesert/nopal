import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Button (RFC 0112, Step 5). One
// interaction-with-telemetry test + one zero-violation axe scan. Button has no
// intrinsic anchor (its action is app-defined), so the kitchen-sink call site
// carries a `data-action` anchor (REQ-F2). Behavioural assertions go only
// through the telemetry log (REQ-N2); the click merely triggers the action.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const BUTTON = '[data-action="ui-button-primary"]';

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    BUTTON,
    { timeout: 10000 }
  );
});

test("primary button click dispatches ButtonClicked via telemetry", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(BUTTON).click();
  await telemetry.waitForMessage("ButtonClicked:primary", SETTLE);

  await telemetry.assertDispatched("ButtonClicked:primary");
});

test("button section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, '[data-testid="ui-section"]');
});
