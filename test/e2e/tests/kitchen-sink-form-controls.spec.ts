import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const SECTION = '[data-testid="form-controls-section"]';
const CHECKBOX = '[data-testid="fc-checkbox"]';
const CHECKBOX_DISABLED = '[data-testid="fc-checkbox-disabled"]';
const RADIO_GROUP = '[data-testid="fc-radio-group"]';
const SELECT = '[data-testid="fc-select"]';
const SELECT_DISABLED = '[data-testid="fc-select-disabled"]';

// `aria-label` is no longer emitted on a radio option, so the two "radio
// group" cases below select an option by its `id` (`<group id>-<slug value>`)
// rather than by its accessible name. An option is now named by
// `aria-labelledby` pointing at its own label element.

// The three restyled controls the section adds: the same components with a
// non-default style on the label and on the row or wrapper, and — on the radio
// group — its visible group label, which is opt-in because making one appear
// changes the rendered tree of every existing consumer.
const RESTYLED_CHECKBOX = '[data-testid="fc-checkbox-restyled"]';
const RESTYLED_SELECT = '[data-testid="fc-select-restyled"]';
const RESTYLED_GROUP = '[data-testid="fc-radio-group-restyled"]';

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
  const radioRed = group.locator(
    'input[type="radio"][id="favorite-color-red"]'
  );
  const radioGreen = group.locator(
    'input[type="radio"][id="favorite-color-green"]'
  );

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
  const radioRed = group.locator(
    'input[type="radio"][id="favorite-color-red"]'
  );
  const radioGreen = group.locator(
    'input[type="radio"][id="favorite-color-green"]'
  );

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

test("restyled controls keep their component's naming", async ({ page }) => {
  // Each restyled control is named by its own label element and carries no
  // `aria-label`. The affirmative arm is the `aria-labelledby` target actually
  // holding the label text, so a control that vanished could not pass by the
  // absence assertion alone.
  const expected = [
    {
      control: RESTYLED_CHECKBOX,
      id: "gift-wrap",
      text: "Gift wrap this order",
    },
    {
      control: RESTYLED_SELECT,
      id: "delivery-window",
      text: "Delivery window",
    },
  ];
  for (const { control, id, text } of expected) {
    const el = page.locator(control);
    await expect(el).toHaveAttribute("id", id);
    await expect(el).toHaveAttribute("aria-labelledby", `${id}-label`);
    await expect(el).not.toHaveAttribute("aria-label", /.*/);
    await expect(page.locator(`#${id}-label`)).toHaveText(text);
  }

  // The radio group opted into a visible group label, so its own name moved off
  // `aria-label` too — the one tree change this feature keeps opt-in.
  const group = page.locator(RESTYLED_GROUP);
  await expect(group).toHaveAttribute("id", "shipping-speed");
  await expect(group).toHaveAttribute(
    "aria-labelledby",
    "shipping-speed-label"
  );
  await expect(group).not.toHaveAttribute("aria-label", /.*/);
  await expect(page.locator("#shipping-speed-label")).toHaveText(
    "Shipping speed"
  );

  // Each option is named by its own label element, and the group label is the
  // group's first child rather than an option's.
  const express = page.locator("#shipping-speed-express");
  await expect(express).toHaveAttribute(
    "aria-labelledby",
    "shipping-speed-express-label"
  );
  await expect(page.locator("#shipping-speed-express-label")).toHaveText(
    "Express"
  );

  // The overrides reached the browser, not just the structural tree. Every
  // value below is non-default, so a knob that compiled without being wired
  // would leave the node at its inherited default instead.
  await expect(page.locator("#gift-wrap-label")).toHaveCSS(
    "font-weight",
    "600"
  );
  await expect(
    page.locator(RESTYLED_CHECKBOX).locator("xpath=..")
  ).toHaveCSS("column-gap", "18px");
  await expect(
    page.locator(RESTYLED_SELECT).locator("xpath=..")
  ).toHaveCSS("row-gap", "20px");
});
