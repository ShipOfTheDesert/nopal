import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const CHECKBOX = '[data-testid="form-checkbox"]';
const CHECKBOX_DISABLED = '[data-testid="form-checkbox-disabled"]';
const RADIO_A = '[data-testid="form-radio-a"]';
const RADIO_B = '[data-testid="form-radio-b"]';
const RADIO_C = '[data-testid="form-radio-c"]';
const SELECT = '[data-testid="form-select"]';
const SELECT_DISABLED = '[data-testid="form-select-disabled"]';
const FORM_SECTION = '[data-testid="form-section"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    CHECKBOX,
    { timeout: 10000 }
  );
});

test("checkbox toggles on click", async ({ page }) => {
  const cb = page.locator(CHECKBOX);
  // Starts unchecked
  expect(await cb.isChecked()).toBe(false);

  await cb.click();
  expect(await cb.isChecked()).toBe(true);

  await cb.click();
  expect(await cb.isChecked()).toBe(false);

  // axe-core on form section
  const results = await new AxeBuilder({ page })
    .include(FORM_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});

test("checkbox disabled does not toggle", async ({ page }) => {
  const cb = page.locator(CHECKBOX_DISABLED);
  expect(await cb.isChecked()).toBe(true);
  expect(await cb.isDisabled()).toBe(true);

  // Force-click bypasses disabled guard at browser level
  await cb.click({ force: true });
  // Should remain checked — disabled prevents the change event
  expect(await cb.isChecked()).toBe(true);
});

test("radio group switches selection", async ({ page }) => {
  const radioA = page.locator(RADIO_A);
  const radioB = page.locator(RADIO_B);

  // A starts checked
  expect(await radioA.isChecked()).toBe(true);
  expect(await radioB.isChecked()).toBe(false);

  // Click B — selection switches
  await radioB.click();
  expect(await radioA.isChecked()).toBe(false);
  expect(await radioB.isChecked()).toBe(true);

  // Click A — switches back
  await radioA.click();
  expect(await radioA.isChecked()).toBe(true);
  expect(await radioB.isChecked()).toBe(false);

  // axe-core
  const results = await new AxeBuilder({ page })
    .include(FORM_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});

test("radio disabled does not select", async ({ page }) => {
  const radioC = page.locator(RADIO_C);
  expect(await radioC.isChecked()).toBe(false);
  expect(await radioC.isDisabled()).toBe(true);

  await radioC.click({ force: true });
  // Should remain unchecked
  expect(await radioC.isChecked()).toBe(false);
});

test("select changes value", async ({ page }) => {
  const sel = page.locator(SELECT);
  // Starts with val-1
  await expect(sel).toHaveValue("val-1");

  await sel.selectOption("val-2");
  await expect(sel).toHaveValue("val-2");

  // axe-core
  const results = await new AxeBuilder({ page })
    .include(FORM_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});

test("select disabled does not change", async ({ page }) => {
  const sel = page.locator(SELECT_DISABLED);
  expect(await sel.isDisabled()).toBe(true);
  await expect(sel).toHaveValue("val-1");

  // Interact with the enabled select to trigger a reconciliation pass
  // without touching the disabled select
  await page.locator(SELECT).selectOption("val-2");

  // After reconciliation, disabled select should still show val-1
  expect(await sel.isDisabled()).toBe(true);
  await expect(sel).toHaveValue("val-1");
});
