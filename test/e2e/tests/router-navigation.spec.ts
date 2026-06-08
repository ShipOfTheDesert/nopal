import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// Router-demo wizard converted to the telemetry approach (RFC 0112, Step 4).
// These cover what the native Telemetry_test cannot: the real
// popstate -> Route_changed path through window.history. Assertions go only
// through the telemetry log (REQ-N2) — DOM clicks trigger the wizard's
// call-site anchors, every behavioural check reads recorded events, and waits
// gate on `waitForMessage` (never `waitForTimeout`).
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const NEXT = '[data-action="wizard-next"]';
const BACK = '[data-action="wizard-back"]';
const JUMP = '[data-action="wizard-jump-summary"]';

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/router_demo/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    NEXT,
    { timeout: 10000 }
  );
});

test("next then browser back returns to prior step", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // Step_one -> push Step_two.
  await page.locator(NEXT).click();
  await telemetry.waitForMessage("Next Step_two", SETTLE);

  // The wizard Back control issues Router.back, exercising the real
  // history.back() -> popstate -> Route_changed path the native test can't.
  await page.locator(BACK).click();
  await telemetry.waitForMessage("Back", SETTLE);

  await telemetry.assertSequence(["Next", "Back"]);
  await telemetry.assertModelContains("Step_one");
});

test("jump to summary replaces so back skips the intermediate step", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  // Step_one -> push Step_two.
  await page.locator(NEXT).click();
  await telemetry.waitForMessage("Next Step_two", SETTLE);

  // Replace Step_two with Summary (no new history entry).
  await page.locator(JUMP).click();
  await telemetry.waitForMessage("Jump_to_summary", SETTLE);

  // Real browser back: because Summary replaced Step_two, history pops straight
  // to Step_one. The popstate-driven Route_changed proves the replace — the
  // optimistic Back update alone could not.
  await page.locator(BACK).click();
  await telemetry.waitForMessage("Route_changed", SETTLE);

  await telemetry.assertModelContains("Step_one");
});
