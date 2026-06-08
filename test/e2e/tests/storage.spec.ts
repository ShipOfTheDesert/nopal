import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// RFC 0112 Step 6 / REQ-F3: a value written to web storage survives a full
// page reload, proven through telemetry rather than the DOM. The storage
// section reads a fixed restore key on `init` and dispatches `StorageRestored
// <value>`; the in-memory telemetry log is cleared by reload (RFC Option B),
// so the proof is the *post-reload* restore message, not a pre-reload entry.
//
// Headless rAF mitigations (headless-chromium-raf-stall): no `page.reload()`
// in `beforeEach` (the reload is the subject of the single test, gated on
// `waitForMessage` — never a fixed delay), and workers are capped at 4 in the
// Playwright config.

const SECTION = '[data-section="storage"]';
const KEY_FIELD = '[data-field="storage-key"]';
const VALUE_FIELD = '[data-field="storage-value"]';
const SET_ACTION = '[data-action="storage-set"]';

// The fixed key the storage section restores on init (kitchen_sink_app).
const RESTORE_KEY = "kitchen-sink:restore-demo";
const VALUE = "survives-reload";

// Generous: the first dispatch frame in a worker can lag while the rAF loop
// warms up — worst right after a reload on a display-server-less machine.
const SETTLE = 60000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("value survives a page reload", async ({ page }) => {
  // This is the only spec that reloads, so it pays the headless first-rAF
  // warm-up twice (initial goto + reload). Under full-suite parallel load that
  // can exceed the 30s default; give it headroom. The proof is still gated on
  // `waitForMessage` (no fixed delay) per RFC Option B / headless-chromium-raf-stall.
  test.setTimeout(150000);

  const before = new NopalTelemetry(page);

  await page.locator(KEY_FIELD).fill(RESTORE_KEY);
  await page.locator(VALUE_FIELD).fill(VALUE);
  await page.locator(SET_ACTION).click();

  // Gate the reload on the write *committing* (StorageSetOk), not merely the
  // StorageSet message: StorageSet only fires the async IndexedDB write, so
  // reloading on it alone races the commit and init would re-read an empty key.
  await before.waitForMessage("StorageSetOk", SETTLE);
  await before.assertDispatched("StorageSet");

  await page.reload({ waitUntil: "load" });

  // After reload the bridge is reinstalled and the in-memory log is empty.
  // init re-reads the restore key and dispatches `StorageRestored:<value>`,
  // which is the only available proof that the value persisted. Poll on a
  // timer (not the default rAF) for the bridge: rAF stalls right after a
  // headless reload, so an rAF-polled wait would starve even once it exists.
  await page.waitForFunction(
    () =>
      (window as { __nopal_telemetry__?: unknown }).__nopal_telemetry__ !==
      undefined,
    null,
    { timeout: SETTLE, polling: 100 }
  );

  const after = new NopalTelemetry(page);
  await after.waitForMessage("Restored", SETTLE);
  await after.assertModelContains(VALUE);
});
