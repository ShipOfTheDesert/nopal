import { test, expect } from "@playwright/test";

// FR-4: when a select's model value matches no option, the rendered control
// must reflect the model (nothing selected) rather than the browser's default
// first option. The "Unmatched select" demo binds a model value that matches
// none of its options. Render-correctness assertion per ADR 0108 (selection is
// a DOM property, not part of the MVU model).
const SELECT_NO_MATCH = '[data-testid="form-select-no-match"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  // rAF-driven mount: wait for the control before asserting (headless guard).
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SELECT_NO_MATCH,
    { timeout: 10000 }
  );
});

test("unmatched model value selects no option", async ({ page }) => {
  // Wait until the options have been rendered (rAF DOM patch).
  await page.waitForFunction(
    (sel) => {
      const el = document.querySelector(sel) as HTMLSelectElement | null;
      return el !== null && el.options.length === 2;
    },
    SELECT_NO_MATCH,
    { timeout: 5000 }
  );

  // No option matches "no-such-value": the control reflects no selection.
  const selectedIndex = await page.$eval(
    SELECT_NO_MATCH,
    (el) => (el as HTMLSelectElement).selectedIndex
  );
  expect(selectedIndex).toBe(-1);
  await expect(page.locator(SELECT_NO_MATCH)).toHaveValue("");
});
