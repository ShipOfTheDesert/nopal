import { test, expect } from "@playwright/test";

const HOVER_BUTTON = '[data-testid="hover-button"]';
const PRESSED_BUTTON = '[data-testid="pressed-button"]';
const FOCUS_INPUT = '[data-testid="focus-input"]';
const HOVER_CARD = '[data-testid="hover-card"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    HOVER_BUTTON,
    { timeout: 10000 }
  );
});

test("hover changes background color", async ({ page }) => {
  const button = page.locator(HOVER_BUTTON);
  const bgBefore = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await button.hover();

  const bgAfter = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(bgBefore).not.toBe(bgAfter);
  // Hover color is #5ba0e9 = rgb(91, 160, 233)
  expect(bgAfter).toBe("rgb(91, 160, 233)");
});

test("pressed changes background color", async ({ page }) => {
  const button = page.locator(PRESSED_BUTTON);

  // Hover first to get hover state
  await button.hover();
  const bgHover = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  // Mouse down to trigger :active (pressed) state
  await page.mouse.down();

  const bgPressed = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await page.mouse.up();

  expect(bgHover).not.toBe(bgPressed);
  // Pressed color is #2a6ab8 = rgb(42, 106, 184)
  expect(bgPressed).toBe("rgb(42, 106, 184)");
});

test("focus-visible shows focus ring", async ({ page }) => {
  const input = page.locator(FOCUS_INPUT);

  const borderBefore = await input.evaluate(
    (el) => getComputedStyle(el).borderWidth
  );

  // Programmatic .focus() on <input> reliably triggers :focus-visible because
  // inputs always match :focus-visible in Chromium. This would NOT work for
  // <button> elements — only keyboard-initiated focus triggers :focus-visible
  // there. If we add button focus tests, use Tab-based navigation instead.
  await input.focus();

  const borderAfter = await input.evaluate(
    (el) => getComputedStyle(el).borderWidth
  );

  // Focus ring has border-width 2px vs base 1px
  expect(borderBefore).toBe("1px");
  expect(borderAfter).toBe("2px");
});

test("clickable box hover highlight", async ({ page }) => {
  const card = page.locator(HOVER_CARD);
  const bgBefore = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await card.hover();

  const bgAfter = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(bgBefore).not.toBe(bgAfter);
  // Hover color is #d0e4f7 = rgb(208, 228, 247)
  expect(bgAfter).toBe("rgb(208, 228, 247)");
});

test("interaction reconciliation updates hover behavior", async ({ page }) => {
  const toggleBtn = page.locator('[data-testid="toggle-interaction-btn"]');
  const card = page.locator('[data-testid="toggle-card"]');

  // Card starts without interaction — hover should not change background
  const bgBeforeHover = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await card.hover();
  const bgAfterHoverOff = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgBeforeHover).toBe(bgAfterHoverOff);

  // Move mouse away before clicking toggle
  await page.mouse.move(0, 0);

  // Enable interaction via toggle
  await toggleBtn.click();

  // Now hover should change background
  const bgBeforeHover2 = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await card.hover();
  const bgAfterHoverOn = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgBeforeHover2).not.toBe(bgAfterHoverOn);
  // Hover color is #d0e4f7 = rgb(208, 228, 247)
  expect(bgAfterHoverOn).toBe("rgb(208, 228, 247)");

  // Move mouse away before clicking toggle again
  await page.mouse.move(0, 0);

  // Disable interaction via toggle
  await toggleBtn.click();

  // Hover should no longer change background
  const bgBeforeHover3 = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await card.hover();
  const bgAfterHoverOff2 = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgBeforeHover3).toBe(bgAfterHoverOff2);
});

test("no style change on non-interactive element", async ({ page }) => {
  // Target a plain text label near the interaction section
  const label = page.getByText("Button with hover highlight:");
  const bgBefore = await label.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await label.hover();

  const bgAfter = await label.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(bgBefore).toBe(bgAfter);
});
