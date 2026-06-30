import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

// Feature 0120 FR-3: a keyed list must preserve the DOM node behind each stable
// key across reconciles, so a focused input survives both an unrelated model
// update (editing a row) and a reorder. Before the fix the reorder pass
// re-inserted every keyed child on every reconcile, blurring the focused input.

const SECTION = '[data-testid="keyed-section"]';
const INPUT_1 = '[data-testid="keyed-input-1"]';
const INPUT_2 = '[data-testid="keyed-input-2"]';

const isFocused = (sel: string) =>
  document.activeElement === document.querySelector(sel);

test.beforeEach(async ({ page }) => {
  // Navigate fresh (never page.reload) so the rAF render loop starts cleanly in
  // headless Chromium (headless-raf-stall convention).
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    INPUT_1,
    { timeout: 10000 }
  );
  // First-interaction actionability wait without clicking.
  await page.click(INPUT_2, { trial: true });
});

test("keyed list preserves focus on reorder", async ({ page }) => {
  // Focus the middle row's input.
  await page.click(INPUT_2);
  await expect
    .poll(() => page.evaluate(isFocused, INPUT_2), { timeout: 5000 })
    .toBe(true);

  // Edit the row — an unrelated-to-ordering model update that re-renders the
  // whole keyed list. Focus must survive the reconcile it triggers.
  await page.locator(INPUT_2).fill("edited");
  await expect(page.locator(INPUT_2)).toHaveValue("edited");
  expect(await page.evaluate(isFocused, INPUT_2)).toBe(true);

  // Reorder: Enter submits the row, moving item 2 above item 1. The same input
  // node is reused under key "2", so it stays focused with its value intact.
  await page.locator(INPUT_2).press("Enter");

  // The reorder landed once row 2's input precedes row 1's in document order.
  await page.waitForFunction(
    ([a, b]) => {
      const na = document.querySelector(a);
      const nb = document.querySelector(b);
      if (!na || !nb) return false;
      return !!(
        nb.compareDocumentPosition(na) & Node.DOCUMENT_POSITION_FOLLOWING
      );
    },
    [INPUT_1, INPUT_2],
    { timeout: 5000 }
  );

  expect(await page.evaluate(isFocused, INPUT_2)).toBe(true);
  await expect(page.locator(INPUT_2)).toHaveValue("edited");
});

test("keyed section passes axe-core accessibility audit", async ({ page }) => {
  const results = await new AxeBuilder({ page }).include(SECTION).analyze();
  expect(results.violations).toEqual([]);
});
