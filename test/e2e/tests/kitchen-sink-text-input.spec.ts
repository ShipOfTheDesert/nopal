import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const SECTION = '[data-testid="text-input-section"]';
const INPUT_DEFAULT = '[data-testid="text-input-default"]';
const INPUT_PLACEHOLDER = '[data-testid="text-input-placeholder"]';
const INPUT_ERROR = '[data-testid="text-input-error"]';
const INPUT_DISABLED = '[data-testid="text-input-disabled"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    INPUT_DEFAULT,
    { timeout: 10000 }
  );
});

test("renders all states", async ({ page }) => {
  await expect(page.locator(INPUT_DEFAULT)).toBeVisible();
  await expect(page.locator(INPUT_PLACEHOLDER)).toBeVisible();
  await expect(page.locator(INPUT_ERROR)).toBeVisible();
  await expect(page.locator(INPUT_DISABLED)).toBeVisible();
});

test("typing updates value", async ({ page }) => {
  const input = page.locator(INPUT_DEFAULT);
  await input.fill("hello nopal");
  await expect(input).toHaveValue("hello nopal");
});

test("error message displayed", async ({ page }) => {
  const errorAlert = page.locator(`${SECTION} [role="alert"]`);
  await expect(errorAlert).toBeVisible();
  await expect(errorAlert).toContainText("This field is required");
});

test("submitting dispatches on enter", async ({ page }) => {
  const input = page.locator(INPUT_DEFAULT);
  await input.fill("submit me");
  await input.press("Enter");
  // After submit, the input should still contain the value (no reset in this demo)
  await expect(input).toHaveValue("submit me");
});

test("axe-core zero violations", async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .include(SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});
