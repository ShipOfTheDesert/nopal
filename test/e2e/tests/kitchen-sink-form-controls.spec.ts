import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const SECTION = '[data-testid="form-controls-section"]';
const CHECKBOX = '[data-testid="fc-checkbox"]';
const CHECKBOX_DISABLED = '[data-testid="fc-checkbox-disabled"]';
const RADIO_GROUP = '[data-testid="fc-radio-group"]';
const SELECT = '[data-testid="fc-select"]';
const SELECT_DISABLED = '[data-testid="fc-select-disabled"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    CHECKBOX,
    { timeout: 10000 }
  );
});

test("renders checkbox and toggles on click", async ({ page }) => {
  const cb = page.locator(CHECKBOX);
  expect(await cb.isChecked()).toBe(false);

  await cb.click();
  expect(await cb.isChecked()).toBe(true);

  await cb.click();
  expect(await cb.isChecked()).toBe(false);
});

test("checkbox toggles on Space key", async ({ page }) => {
  const cb = page.locator(CHECKBOX);
  expect(await cb.isChecked()).toBe(false);

  await cb.focus();
  await page.keyboard.press("Space");
  expect(await cb.isChecked()).toBe(true);

  await page.keyboard.press("Space");
  expect(await cb.isChecked()).toBe(false);
});

test("radio group selects on click", async ({ page }) => {
  const group = page.locator(RADIO_GROUP);
  const radioRed = group.locator('input[type="radio"][aria-label="Red"]');
  const radioGreen = group.locator('input[type="radio"][aria-label="Green"]');

  // Red starts selected
  expect(await radioRed.isChecked()).toBe(true);
  expect(await radioGreen.isChecked()).toBe(false);

  await radioGreen.click();
  expect(await radioGreen.isChecked()).toBe(true);
  expect(await radioRed.isChecked()).toBe(false);

  await radioRed.click();
  expect(await radioRed.isChecked()).toBe(true);
  expect(await radioGreen.isChecked()).toBe(false);
});

test("select changes on selection", async ({ page }) => {
  const sel = page.locator(SELECT);
  await expect(sel).toHaveValue("medium");

  await sel.selectOption("large");
  await expect(sel).toHaveValue("large");

  await sel.selectOption("small");
  await expect(sel).toHaveValue("small");
});

test("disabled checkbox does not toggle", async ({ page }) => {
  const cb = page.locator(CHECKBOX_DISABLED);
  expect(await cb.isChecked()).toBe(true);
  expect(await cb.isDisabled()).toBe(true);

  await cb.click({ force: true });
  expect(await cb.isChecked()).toBe(true);
});

test("radio group navigates with arrow keys", async ({ page }) => {
  const group = page.locator(RADIO_GROUP);
  const radioRed = group.locator('input[type="radio"][aria-label="Red"]');
  const radioGreen = group.locator('input[type="radio"][aria-label="Green"]');

  // Red starts selected
  expect(await radioRed.isChecked()).toBe(true);

  // Focus the selected radio and press ArrowDown to move to Green
  await radioRed.focus();
  await page.keyboard.press("ArrowDown");
  expect(await radioGreen.isChecked()).toBe(true);
  expect(await radioRed.isChecked()).toBe(false);

  // ArrowUp back to Red
  await page.keyboard.press("ArrowUp");
  expect(await radioRed.isChecked()).toBe(true);
  expect(await radioGreen.isChecked()).toBe(false);
});

test("disabled select cannot be changed", async ({ page }) => {
  const sel = page.locator(SELECT_DISABLED);
  expect(await sel.isDisabled()).toBe(true);
  await expect(sel).toHaveValue("medium");
});

test("disabled radio group does not select on click", async ({ page }) => {
  const group = page.locator('[data-testid="fc-radio-group-disabled"]');
  const radios = group.locator('input[type="radio"]');

  // All radios should be disabled
  const count = await radios.count();
  for (let i = 0; i < count; i++) {
    expect(await radios.nth(i).isDisabled()).toBe(true);
  }
});

test("axe-core zero violations", async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .include(SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});
