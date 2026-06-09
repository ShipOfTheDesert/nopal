import { test, expect } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// RFC 0114 Task 4 — Bottom_tabs E2E. The behavioural contract (per-tab stack
// preservation, push/pop) is asserted through the MVU telemetry log (ADR 0108),
// not the DOM; only the safe-area inset — a pure render concern — and the axe
// audit read the DOM.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), waitForFunction before interacting, and gate every
// behavioural wait on `waitForMessage` rather than a fixed delay.

const SECTION = '[data-testid="bottom-tabs-section"]';
const HOME_TAB = `${SECTION} [data-testid="nav-tab-home"]`;
const PROFILE_TAB = `${SECTION} [data-testid="nav-tab-profile"]`;
const PUSH = `${SECTION} [data-action="bottom-tabs-push"]`;
const BACK = `${SECTION} [data-action="nav-back"]`;
const GUTTER = `${SECTION} [data-testid="bottom-tabs-gutter"]`;

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("tab switch preserves each tab's stack depth", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // Drill the profile tab two screens deep.
  await page.locator(PROFILE_TAB).click();
  await telemetry.waitForMessage("BottomTabs:Select:profile", SETTLE);
  await page.locator(PUSH).click();
  await telemetry.waitForMessage("BottomTabs:Push", SETTLE);

  // Switch to home (depth 1) and back to profile. Preservation means profile's
  // depth is untouched by the round trip — the stacks live side by side.
  await page.locator(HOME_TAB).click();
  await telemetry.waitForMessage("BottomTabs:Select:home", SETTLE);
  await page.locator(PROFILE_TAB).click();
  await telemetry.waitForMessage("BottomTabs:Select:profile", SETTLE);

  // The trailing ';' bounds the fragment so `profile_depth=2;` cannot
  // prefix-alias a larger depth (undelimited-telemetry-fragment-aliasing).
  await telemetry.assertModelContains("profile_depth=2;");
  await telemetry.attachHistory(test.info());
});

test("push and pop within a tab", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // Home tab is active by default and roots at its push affordance.
  await page.locator(PUSH).click();
  await telemetry.waitForMessage("BottomTabs:Push", SETTLE);

  // Pushing reveals the component back affordance (gated on Nav_stack.can_pop).
  await page.locator(BACK).click();
  await telemetry.waitForMessage("BottomTabs:Back", SETTLE);

  await telemetry.assertSequence(["BottomTabs:Push", "BottomTabs:Back"]);
  await telemetry.attachHistory(test.info());
});

test("tab bar respects bottom safe-area inset", async ({ page }) => {
  // Render-correctness DOM assertion (REQ-F4): the kitchen sink passes a
  // non-zero inset, so the gutter wrapping the bar carries a real bottom pad.
  const paddingBottom = await page
    .locator(GUTTER)
    .evaluate((el) => parseFloat(getComputedStyle(el).paddingBottom));
  expect(paddingBottom).toBeGreaterThan(0);
});

test("axe accessibility audit", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, SECTION);
});
