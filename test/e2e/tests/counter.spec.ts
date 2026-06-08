import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// Counter converted to the telemetry approach (RFC 0112, Step 2). Assertions go
// only through the telemetry log (REQ-N2): DOM clicks trigger the actions, but
// every behavioural check reads the recorded Message / Model_transition events.
// Waits gate on `waitForMessage` — never `waitForTimeout` (REQ-N2).
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const INCREMENT = '[data-action="counter-increment"]';
const DECREMENT = '[data-action="counter-decrement"]';

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/counter/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    INCREMENT,
    { timeout: 10000 }
  );
});

test("increment click dispatches Increment and model reaches 1", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(INCREMENT).click();
  // Gate on the recorded message rather than a fixed delay.
  await telemetry.waitForMessage("Increment", SETTLE);

  await telemetry.assertDispatched("Increment");
  await telemetry.assertModelContains("count=1;");
});

test("increment then decrement sequence", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(INCREMENT).click();
  await page.locator(DECREMENT).click();
  // Wait for the second dispatch to land before draining the log.
  await telemetry.waitForMessage("Decrement", SETTLE);

  await telemetry.assertSequence(["Increment", "Decrement"]);
});
