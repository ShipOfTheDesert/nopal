import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const TOAST_SECTION = '[data-testid="toast-section"]';
const TRIGGER_INFO = '[data-testid="toast-trigger-info"]';
const TRIGGER_SUCCESS = '[data-testid="toast-trigger-success"]';
const TRIGGER_WARNING = '[data-testid="toast-trigger-warning"]';
const TRIGGER_ERROR = '[data-testid="toast-trigger-error"]';
test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    TRIGGER_INFO,
    { timeout: 10000 }
  );
});

test("toast appears on trigger", async ({ page }) => {
  await page.locator(TRIGGER_INFO).click();
  await expect(
    page.locator(`${TOAST_SECTION} [data-variant="info"]`)
  ).toContainText("This is an info notification");
});

test("toast auto-dismisses after duration", async ({ page }) => {
  await page.clock.install();
  await page.locator(TRIGGER_INFO).click();
  const toast = page.locator(`${TOAST_SECTION} [data-variant="info"]`);
  await expect(toast).toBeVisible();
  await page.clock.fastForward(3000);
  await expect(toast).toBeHidden({ timeout: 2000 });
});

test("click to dismiss", async ({ page }) => {
  await page.locator(TRIGGER_INFO).click();
  const toast = page.locator(`${TOAST_SECTION} [data-variant="info"]`);
  await expect(toast).toBeVisible();
  await toast.click();
  await expect(toast).toBeHidden({ timeout: 2000 });
});

test("aria-live on toast elements", async ({ page }) => {
  await page.locator(TRIGGER_INFO).click();
  await page.locator(TRIGGER_ERROR).click();

  await expect(
    page.locator(`${TOAST_SECTION} [data-variant="info"]`)
  ).toHaveAttribute("aria-live", "polite");
  await expect(
    page.locator(`${TOAST_SECTION} [data-variant="error"]`)
  ).toHaveAttribute("aria-live", "assertive");
});

test("all four variants render", async ({ page }) => {
  await page.locator(TRIGGER_INFO).click();
  await page.locator(TRIGGER_SUCCESS).click();
  await page.locator(TRIGGER_WARNING).click();
  await page.locator(TRIGGER_ERROR).click();

  for (const variant of ["info", "success", "warning", "error"]) {
    await expect(
      page.locator(`${TOAST_SECTION} [data-variant="${variant}"]`)
    ).toBeVisible();
  }
});

test("axe accessibility audit", async ({ page }) => {
  // Trigger a toast so there's content to audit
  await page.locator(TRIGGER_INFO).click();
  await expect(
    page.locator(`${TOAST_SECTION} [data-variant="info"]`)
  ).toBeVisible();

  const results = await new AxeBuilder({ page })
    .include(TOAST_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});
