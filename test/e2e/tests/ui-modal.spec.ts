import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Modal (RFC 0112, Step 5). Drives the intrinsic
// `data-action="modal-dismiss"` anchor (Task 1, placed on the backdrop — the
// modal's only clickable dismiss surface) and asserts the close message via
// telemetry (REQ-N2). The modal must be opened first; the backdrop is clicked
// at its corner because the centred dialog overlays its middle.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const OPEN = '[data-testid="modal-open-button"]';
const DISMISS = '[data-action="modal-dismiss"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    OPEN,
    { timeout: 10000 }
  );
});

test("backdrop dismiss dispatches close message via telemetry", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(OPEN).click();
  await telemetry.waitForMessage("Modal:Open", SETTLE);

  // The backdrop fills the viewport with the dialog centred on top, so click a
  // corner to land on the backdrop rather than the dialog.
  await page.locator(DISMISS).click({ position: { x: 5, y: 5 } });
  await telemetry.waitForMessage("Modal:Close", SETTLE);

  await telemetry.assertDispatched("Modal:Close");
});

test("modal section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, '[data-testid="modal-section"]');
});
