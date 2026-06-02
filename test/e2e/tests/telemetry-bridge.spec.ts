import { test, expect } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// E2E for the telemetry browser bridge (RFC 0110, Layer 2). The kitchen sink is
// the live target: it mounts with `Nopal_web.mount_with_telemetry` by default,
// and with plain `Nopal_web.mount` when `?telemetry=off` — so we exercise both
// "wired" and "not wired" against one app.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForSelector before asserting.

const SECTION = '[data-section="telemetry"]';
const PING_ALPHA = '[data-testid="telemetry-ping-alpha"]';
const PING_BETA = '[data-testid="telemetry-ping-beta"]';

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

async function gotoFresh(
  page: import("@playwright/test").Page,
  query = ""
): Promise<void> {
  await page.goto(`/kitchen_sink/${query}`);
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
}

test("bridge present and getEvents returns array when wired", async ({
  page,
}) => {
  await gotoFresh(page);

  const present = await page.evaluate(
    () =>
      typeof (window as { __nopal_telemetry__?: { getEvents?: unknown } })
        .__nopal_telemetry__?.getEvents === "function"
  );
  expect(present).toBe(true);

  const telemetry = new NopalTelemetry(page);
  const events = await telemetry.events();
  expect(Array.isArray(events)).toBe(true);
});

test("bridge absent when not wired", async ({ page }) => {
  // Same app, mounted via plain `Nopal_web.mount` (no telemetry) — the bridge
  // must not exist (REQ-N2: the surface appears only on explicit opt-in).
  await gotoFresh(page, "?telemetry=off");

  const present = await page.evaluate(
    () =>
      typeof (window as { __nopal_telemetry__?: unknown })
        .__nopal_telemetry__ !== "undefined"
  );
  expect(present).toBe(false);
});

test("waitForMessage resolves on dispatch, rejects on timeout", async ({
  page,
}) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  // Arm the wait before the interaction so the live stream catches the event.
  const pending = telemetry.waitForMessage("TelemetryPing:alpha", SETTLE);
  await page.locator(PING_ALPHA).click();
  await expect(pending).resolves.toBeUndefined();

  // A fragment that is never dispatched must reject after the timeout.
  await expect(
    telemetry.waitForMessage("never-dispatched-zzz", 1000)
  ).rejects.toThrow(/never-dispatched-zzz/);
});

test("assertSequence passes in order", async ({ page }) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  await page.locator(PING_ALPHA).click();
  await page.locator(PING_BETA).click();
  // Let the second dispatch land before draining the log.
  await telemetry.waitForMessage("TelemetryPing:beta", SETTLE);

  await telemetry.assertSequence([
    "TelemetryPing:alpha",
    "TelemetryPing:beta",
  ]);
});

test("history attached on failure", async ({ page }, testInfo) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  await page.locator(PING_ALPHA).click();
  await telemetry.waitForMessage("TelemetryPing:alpha", SETTLE);

  // A deliberately failing assertion: we attach the recorded history before
  // letting the test continue (REQ-F7). The attachment must carry the real
  // event we recorded, proving the dump-on-failure path works.
  let failed = false;
  try {
    await telemetry.assertDispatched("definitely-absent-fragment");
  } catch {
    failed = true;
    await telemetry.attachHistory(testInfo);
  }

  expect(failed).toBe(true);
  const attachment = testInfo.attachments.find(
    (a) => a.name === "nopal-telemetry-history"
  );
  expect(attachment).toBeDefined();
  expect(attachment?.body?.toString()).toContain("TelemetryPing:alpha");
});
