import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const FEEDBACK = '[data-testid="ui-feedback"]';
const BTN_PRIMARY = '[data-testid="btn-primary"]';
const BTN_PRIMARY_DISABLED = '[data-testid="btn-primary-disabled"]';
const BTN_PRIMARY_LOADING = '[data-testid="btn-primary-loading"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    BTN_PRIMARY,
    { timeout: 10000 }
  );
});

test("button click triggers feedback", async ({ page }) => {
  await page.locator(BTN_PRIMARY).click();
  await expect(page.locator(FEEDBACK)).toContainText("Last clicked: primary");
});

test("disabled button is no-op", async ({ page }) => {
  const feedbackBefore = await page.locator(FEEDBACK).textContent();
  await page.locator(BTN_PRIMARY_DISABLED).click({ force: true });
  const feedbackAfter = await page.locator(FEEDBACK).textContent();
  expect(feedbackAfter).toBe(feedbackBefore);
});

test("loading button is no-op", async ({ page }) => {
  const feedbackBefore = await page.locator(FEEDBACK).textContent();
  await page.locator(BTN_PRIMARY_LOADING).click({ force: true });
  const feedbackAfter = await page.locator(FEEDBACK).textContent();
  expect(feedbackAfter).toBe(feedbackBefore);
});

test("all variants render", async ({ page }) => {
  for (const variant of [
    "primary",
    "secondary",
    "destructive",
    "ghost",
    "icon",
  ]) {
    await expect(page.locator(`[data-testid="btn-${variant}"]`)).toBeVisible();
  }
});

test("aria-disabled present on disabled buttons", async ({ page }) => {
  for (const variant of [
    "primary",
    "secondary",
    "destructive",
    "ghost",
    "icon",
  ]) {
    const btn = page.locator(`[data-testid="btn-${variant}-disabled"]`);
    await expect(btn).toHaveAttribute("aria-disabled", "true");
  }
});

test("aria-busy present on loading buttons", async ({ page }) => {
  for (const variant of [
    "primary",
    "secondary",
    "destructive",
    "ghost",
    "icon",
  ]) {
    const btn = page.locator(`[data-testid="btn-${variant}-loading"]`);
    await expect(btn).toHaveAttribute("aria-busy", "true");
  }
});

test("axe-core zero violations on UI section", async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .include('[data-testid="ui-section"]')
    .analyze();
  expect(results.violations).toEqual([]);
});
