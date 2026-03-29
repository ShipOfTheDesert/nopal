import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const SECTION = '[data-testid="focus-keyboard-section"]';
const FOCUS_BUTTON = '[data-testid="focus-button"]';
const DEMO_INPUT = '[data-testid="demo-input"]';
const TRAP_TOGGLE = '[data-testid="trap-toggle"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    FOCUS_BUTTON,
    { timeout: 10000 }
  );
});

test("focuses input when button is clicked", async ({ page }) => {
  await page.click(FOCUS_BUTTON);
  // Wait for the focus command to be processed by the rAF loop
  await page.waitForFunction(
    (sel) => document.activeElement === document.querySelector(sel),
    "#demo-input",
    { timeout: 5000 }
  );
  const activeId = await page.evaluate(() => document.activeElement?.id);
  expect(activeId).toBe("demo-input");
});

test("prevents Tab from moving focus", async ({ page }) => {
  // Enable key trapping by clicking the checkbox
  await page.click(TRAP_TOGGLE);
  // Focus the input first
  await page.click(FOCUS_BUTTON);
  await page.waitForFunction(
    (sel) => document.activeElement === document.querySelector(sel),
    "#demo-input",
    { timeout: 5000 }
  );
  // Press Tab — should be prevented
  await page.keyboard.press("Tab");
  // Focus should stay on the input
  const activeId = await page.evaluate(() => document.activeElement?.id);
  expect(activeId).toBe("demo-input");
  // Verify the "Last key: Tab" text appeared
  await expect(page.locator(SECTION)).toContainText("Last key: Tab");
});

test("allows Escape through", async ({ page }) => {
  // Enable key trapping
  await page.click(TRAP_TOGGLE);
  // Focus the input
  await page.click(FOCUS_BUTTON);
  await page.waitForFunction(
    (sel) => document.activeElement === document.querySelector(sel),
    "#demo-input",
    { timeout: 5000 }
  );
  // Press Escape — should NOT be prevented (callback returns None for non-Tab)
  await page.keyboard.press("Escape");
  // The text should still say "No key trapped yet" since Escape returns None
  await expect(page.locator(SECTION)).toContainText("No key trapped yet");
});

test("passes axe-core accessibility audit", async ({ page }) => {
  const results = await new AxeBuilder({ page }).include(SECTION).analyze();
  expect(results.violations).toEqual([]);
});
