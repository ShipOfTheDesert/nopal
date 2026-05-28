import { test, expect } from "@playwright/test";

// E2E coverage for the offline storage abstraction (RFC 0107). The kitchen
// sink storage section is backed by IndexedDB on web (nopal_storage_web), so
// these tests exercise the real browser IndexedDB through the MVU loop.
//
// Persistence is verified with a second `goto` rather than `page.reload()`:
// headless Chromium without a display server can stall requestAnimationFrame
// on reload, so we navigate fresh instead (see headless-chromium-raf-stall).

const SECTION = '[data-section="storage"]';
const KEY_INPUT = '[data-testid="storage-key-input"]';
const VALUE_INPUT = '[data-testid="storage-value-input"]';
const SET_BTN = '[data-testid="storage-set-btn"]';
const GET_BTN = '[data-testid="storage-get-btn"]';
const DELETE_BTN = '[data-testid="storage-delete-btn"]';
const LIST_BTN = '[data-testid="storage-list-btn"]';
const CLEAR_BTN = '[data-testid="storage-clear-btn"]';
const RESULT = '[data-testid="storage-result"]';

// Typed counter (With_codec) controls.
const CODEC_INCREMENT_BTN = '[data-testid="codec-increment-btn"]';
const CODEC_SAVE_BTN = '[data-testid="codec-save-btn"]';
const CODEC_LOAD_BTN = '[data-testid="codec-load-btn"]';
const CODEC_CORRUPT_BTN = '[data-testid="codec-corrupt-btn"]';
const CODEC_RESULT = '[data-testid="codec-result"]';

// Generous timeout: the first model→DOM update in a worker can lag while the
// rAF loop warms up on a display-server-less machine.
const SETTLE = 15000;

async function gotoFresh(page: import("@playwright/test").Page) {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
}

test.beforeEach(async ({ page }) => {
  await gotoFresh(page);
});

test("test_storage_set_and_get_roundtrip", async ({ page }) => {
  await page.locator(KEY_INPUT).fill("greeting");
  await page.locator(VALUE_INPUT).fill("hola");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored", { timeout: SETTLE });

  await page.locator(KEY_INPUT).fill("greeting");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("hola", { timeout: SETTLE });
});

// Note: the section's "Reload" button (storage-reload-btn) calls
// window.location.reload() — the exact operation that stalls requestAnimationFrame
// on a display-server-less machine (headless-chromium-raf-stall). We therefore do
// not click it here; persistence is verified by navigating fresh (gotoFresh)
// instead, which exercises the same IndexedDB-survives-a-new-page behaviour
// without the reload stall.
test("test_storage_persists_across_reload", async ({ page }) => {
  await page.locator(KEY_INPUT).fill("persisted");
  await page.locator(VALUE_INPUT).fill("survives-reload");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored", { timeout: SETTLE });

  // Navigate fresh (not page.reload) — IndexedDB persists across navigation
  // within the same origin, so the value must reappear on a brand-new page.
  await gotoFresh(page);

  await page.locator(KEY_INPUT).fill("persisted");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("survives-reload", {
    timeout: SETTLE,
  });
});

test("test_storage_large_value_over_5mb_persists", async ({ page }) => {
  // > 5 MB proves the backend is IndexedDB, not localStorage (which caps
  // around 5 MB). A leading 'A' run + trailing 'Z' lets us detect any
  // truncation at either boundary, not just a length mismatch.
  const size = 5 * 1024 * 1024 + 1024;
  const bigValue = "A".repeat(size - 1) + "Z";

  await page.locator(KEY_INPUT).fill("big");
  await page.locator(VALUE_INPUT).fill(bigValue);
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored", { timeout: SETTLE });

  await page.locator(KEY_INPUT).fill("big");
  await page.locator(GET_BTN).click();

  // Wait for the value to render, then assert it round-tripped intact. Use a
  // length-tolerant wait first (the "Stored"/"Not found" sentinels are short).
  await expect
    .poll(async () => (await page.locator(RESULT).textContent())?.length ?? 0, {
      timeout: SETTLE,
    })
    .toBe(size);

  const roundTripped = await page.locator(RESULT).textContent();
  expect(roundTripped?.startsWith("A")).toBe(true);
  expect(roundTripped?.endsWith("Z")).toBe(true);
});

test("test_storage_delete_removes_value", async ({ page }) => {
  await page.locator(KEY_INPUT).fill("doomed");
  await page.locator(VALUE_INPUT).fill("temporary");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored", { timeout: SETTLE });

  await page.locator(KEY_INPUT).fill("doomed");
  await page.locator(DELETE_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Deleted", { timeout: SETTLE });

  await page.locator(KEY_INPUT).fill("doomed");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Not found", {
    timeout: SETTLE,
  });
});

test("test_storage_list_keys_by_prefix", async ({ page }) => {
  const seed = async (key: string, value: string) => {
    await page.locator(KEY_INPUT).fill(key);
    await page.locator(VALUE_INPUT).fill(value);
    await page.locator(SET_BTN).click();
    await expect(page.locator(RESULT)).toContainText("Stored", {
      timeout: SETTLE,
    });
  };

  await seed("a:1", "one");
  await seed("a:2", "two");
  await seed("b:1", "three");

  // The List control uses the key input as the prefix (empty → list all).
  await page.locator(KEY_INPUT).fill("a:");
  await page.locator(LIST_BTN).click();

  const result = page.locator(RESULT);
  await expect(result).toContainText("a:1", { timeout: SETTLE });
  await expect(result).toContainText("a:2");
  await expect(result).not.toContainText("b:1");
});

test("test_storage_clear_preserves_localstorage", async ({ page }) => {
  // A localStorage item set out-of-band must survive Storage.clear (), which
  // only empties the abstraction's IndexedDB namespace (REQ-N3).
  await page.evaluate(() =>
    localStorage.setItem("ls-survivor", "still-here")
  );

  await page.locator(KEY_INPUT).fill("nopal-key");
  await page.locator(VALUE_INPUT).fill("nopal-value");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored", { timeout: SETTLE });

  await page.locator(CLEAR_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Cleared", {
    timeout: SETTLE,
  });

  // The abstraction's key is gone...
  await page.locator(KEY_INPUT).fill("nopal-key");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Not found", {
    timeout: SETTLE,
  });

  // ...but the untouched localStorage item is still present.
  const survivor = await page.evaluate(() =>
    localStorage.getItem("ls-survivor")
  );
  expect(survivor).toBe("still-here");
});

test("test_codec_typed_counter_persists", async ({ page }) => {
  // With_codec stores an int through encode/decode over the same IndexedDB
  // backend. Increment to 3, Save, navigate fresh, Load — the typed value must
  // round-trip back as an integer (not the raw string).
  await page.locator(CODEC_INCREMENT_BTN).click();
  await page.locator(CODEC_INCREMENT_BTN).click();
  await page.locator(CODEC_INCREMENT_BTN).click();
  await page.locator(CODEC_SAVE_BTN).click();
  await expect(page.locator(CODEC_RESULT)).toContainText("Saved", {
    timeout: SETTLE,
  });

  await gotoFresh(page);

  await page.locator(CODEC_LOAD_BTN).click();
  await expect(page.locator(CODEC_RESULT)).toContainText("Loaded 3", {
    timeout: SETTLE,
  });
});

test("test_codec_decode_error_surfaces", async ({ page }) => {
  // Write a non-integer under the typed key (Corrupt), then Load: With_codec
  // must surface a Decode error rather than crashing or returning a value.
  await page.locator(CODEC_CORRUPT_BTN).click();
  await expect(page.locator(CODEC_RESULT)).toContainText("Corrupted", {
    timeout: SETTLE,
  });

  await page.locator(CODEC_LOAD_BTN).click();
  await expect(page.locator(CODEC_RESULT)).toContainText("Decode error", {
    timeout: SETTLE,
  });
});
