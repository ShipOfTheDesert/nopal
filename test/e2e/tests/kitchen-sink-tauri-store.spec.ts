import { test, expect } from "@playwright/test";

// Render-correctness DOM checks (ADR 0108): plain-browser markup assertions;
// Tauri `invoke` is absent here. Selectors migrated to the data-action/data-field
// anchors (REQ-F2); the real IPC behaviour is in test/e2e/tauri/store.e2e.ts.
const SECTION = '[data-section="tauri-store"]';
const KEY_INPUT = '[data-field="tauri-store-key"]';
const VALUE_INPUT = '[data-field="tauri-store-value"]';
const SET_BTN = '[data-action="tauri-store-set"]';
const GET_BTN = '[data-action="tauri-store-get"]';
const DELETE_BTN = '[data-action="tauri-store-delete"]';
const CLEAR_BTN = '[data-action="tauri-store-clear"]';
const SAVE_BTN = '[data-action="tauri-store-save"]';
const RESULT = '[data-field="tauri-store-result"]';

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
