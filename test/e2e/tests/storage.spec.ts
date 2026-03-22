import { test, expect } from "@playwright/test";

const SECTION = '[data-section="storage"]';
const KEY_INPUT = '[data-testid="storage-key-input"]';
const VALUE_INPUT = '[data-testid="storage-value-input"]';
const SET_BTN = '[data-testid="storage-set-btn"]';
const GET_BTN = '[data-testid="storage-get-btn"]';
const REMOVE_BTN = '[data-testid="storage-remove-btn"]';
const CLEAR_BTN = '[data-testid="storage-clear-btn"]';
const RESULT = '[data-testid="storage-result"]';

test.beforeEach(async ({ page }) => {
  // Clear localStorage before each test to avoid cross-test contamination
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
  // Clear any existing storage state
  await page.evaluate(() => localStorage.clear());
});

test("set value, reload, get shows persisted value", async ({ page }) => {
  const keyInput = page.locator(KEY_INPUT);
  const valueInput = page.locator(VALUE_INPUT);

  await keyInput.fill("test-key");
  await valueInput.fill("test-value");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored");

  // Reload the page to verify persistence
  await page.reload();
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );

  await page.locator(KEY_INPUT).fill("test-key");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("test-value");
});

test("get missing key shows not found", async ({ page }) => {
  const keyInput = page.locator(KEY_INPUT);

  await keyInput.fill("nonexistent-key");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Not found");
});

test("remove deletes key", async ({ page }) => {
  const keyInput = page.locator(KEY_INPUT);
  const valueInput = page.locator(VALUE_INPUT);

  // Set a value first
  await keyInput.fill("remove-me");
  await valueInput.fill("some-value");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored");

  // Remove it
  await keyInput.fill("remove-me");
  await page.locator(REMOVE_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Removed");

  // Verify it's gone
  await keyInput.fill("remove-me");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Not found");
});

test("clear removes all keys", async ({ page }) => {
  const keyInput = page.locator(KEY_INPUT);
  const valueInput = page.locator(VALUE_INPUT);

  // Set multiple values
  await keyInput.fill("key-a");
  await valueInput.fill("val-a");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored");

  await keyInput.fill("key-b");
  await valueInput.fill("val-b");
  await page.locator(SET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Stored");

  // Clear all
  await page.locator(CLEAR_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Cleared");

  // Verify both are gone
  await keyInput.fill("key-a");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Not found");

  await keyInput.fill("key-b");
  await page.locator(GET_BTN).click();
  await expect(page.locator(RESULT)).toContainText("Not found");
});
