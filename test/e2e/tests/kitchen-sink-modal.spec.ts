import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const MODAL_SECTION = '[data-testid="modal-section"]';
const OPEN_BUTTON = '[data-testid="modal-open-button"]';
const DIALOG = '[data-testid="modal-dialog"]';
const BACKDROP = '[data-testid="modal-backdrop"]';
const INPUT_1 = '[data-testid="modal-input-1"]';
const INPUT_2 = '[data-testid="modal-input-2"]';
const CLOSE_BUTTON = '[data-testid="modal-close-button"]';

// Wait for one rAF cycle so the MVU loop updates subscription closures.
// The keydown_prevent callbacks are refreshed per-frame, so after a Tab
// dispatch updates the model, the next rAF must run before the closure
// captures the new model.focused value.
async function waitForRaf(page: import("@playwright/test").Page) {
  await page.evaluate(
    () => new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))
  );
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    OPEN_BUTTON,
    { timeout: 10000 }
  );
});

test("open modal via button click", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator('[role="dialog"]')).toBeVisible();
});

test("escape closes the modal", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator(DIALOG)).not.toBeVisible();
});

test("tab cycles through focusable elements", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();

  // Focus the first input
  await page.locator(INPUT_1).focus();
  await expect(page.locator(INPUT_1)).toBeFocused();

  // Tab → input-2
  await page.keyboard.press("Tab");
  await expect(page.locator(INPUT_2)).toBeFocused();
  await waitForRaf(page);

  // Tab → close-button
  await page.keyboard.press("Tab");
  await expect(page.locator(CLOSE_BUTTON)).toBeFocused();
  await waitForRaf(page);

  // Tab → wraps to input-1
  await page.keyboard.press("Tab");
  await expect(page.locator(INPUT_1)).toBeFocused();
});

test("shift+tab cycles in reverse", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();

  // Focus the first input and wait for rAF so subscription captures focus state
  await page.locator(INPUT_1).focus();
  await expect(page.locator(INPUT_1)).toBeFocused();
  await waitForRaf(page);

  // Shift+Tab → wraps to close-button (last element)
  await page.keyboard.press("Shift+Tab");
  await expect(page.locator(CLOSE_BUTTON)).toBeFocused();
});

test("tab does not escape the modal", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();

  // Focus the first input
  await page.locator(INPUT_1).focus();
  await expect(page.locator(INPUT_1)).toBeFocused();

  // Press Tab more times than there are focusable elements, waiting for
  // each rAF so the subscription closure captures updated model.focused
  await page.keyboard.press("Tab");
  await expect(page.locator(INPUT_2)).toBeFocused();
  await waitForRaf(page);

  await page.keyboard.press("Tab");
  await expect(page.locator(CLOSE_BUTTON)).toBeFocused();
  await waitForRaf(page);

  await page.keyboard.press("Tab");
  await expect(page.locator(INPUT_1)).toBeFocused();
  await waitForRaf(page);

  await page.keyboard.press("Tab");
  await expect(page.locator(INPUT_2)).toBeFocused();
  await waitForRaf(page);

  await page.keyboard.press("Tab");
  await expect(page.locator(CLOSE_BUTTON)).toBeFocused();
});

test("backdrop click closes the modal", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();

  // Click the backdrop outside the dialog (top-left corner)
  await page.locator(BACKDROP).click({ position: { x: 5, y: 5 } });
  await expect(page.locator(DIALOG)).not.toBeVisible();
});

test("focus returns to trigger after close", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();

  // Close via Escape
  await page.keyboard.press("Escape");
  await expect(page.locator(DIALOG)).not.toBeVisible();

  // Focus should return to the open button
  await expect(page.locator(OPEN_BUTTON)).toBeFocused();
});

test("axe accessibility audit", async ({ page }) => {
  await page.locator(OPEN_BUTTON).click();
  await expect(page.locator(DIALOG)).toBeVisible();

  const results = await new AxeBuilder({ page })
    .include(MODAL_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});
