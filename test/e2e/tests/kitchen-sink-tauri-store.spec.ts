import { test, expect } from "@playwright/test";

const SECTION = '[data-section="tauri-store"]';
const KEY_INPUT = '[data-testid="tauri-store-key-input"]';
const VALUE_INPUT = '[data-testid="tauri-store-value-input"]';
const SET_BTN = '[data-testid="tauri-store-set-btn"]';
const GET_BTN = '[data-testid="tauri-store-get-btn"]';
const DELETE_BTN = '[data-testid="tauri-store-delete-btn"]';
const CLEAR_BTN = '[data-testid="tauri-store-clear-btn"]';
const SAVE_BTN = '[data-testid="tauri-store-save-btn"]';
const RESULT = '[data-testid="tauri-store-result"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("store section renders with heading", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(
    section.getByText("Store (Tauri)", { exact: true })
  ).toBeVisible();
});

test("store key and value inputs render with placeholders", async ({
  page,
}) => {
  const keyInput = page.locator(KEY_INPUT);
  await expect(keyInput).toBeVisible();
  await expect(keyInput).toHaveAttribute("placeholder", "Key");

  const valueInput = page.locator(VALUE_INPUT);
  await expect(valueInput).toBeVisible();
  await expect(valueInput).toHaveAttribute("placeholder", "Value");
});

test("store buttons render", async ({ page }) => {
  await expect(page.locator(SET_BTN)).toBeVisible();
  await expect(page.locator(GET_BTN)).toBeVisible();
  await expect(page.locator(DELETE_BTN)).toBeVisible();
  await expect(page.locator(CLEAR_BTN)).toBeVisible();
  await expect(page.locator(SAVE_BTN)).toBeVisible();
});

test("store result display shows initial state", async ({ page }) => {
  const result = page.locator(RESULT);
  await expect(result).toBeVisible();
  await expect(result).toContainText("No operation yet");
});

test("store persistence instructions render", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(
    section.getByText("Values persist across app relaunch after Save")
  ).toBeVisible();
});
